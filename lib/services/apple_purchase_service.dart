import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';

/// Lives for the app session so transactions survive navigation and relaunch.
class ApplePurchaseService with WidgetsBindingObserver {
  ApplePurchaseService._();
  static final instance = ApplePurchaseService._();
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
  final _functions = FirebaseFunctions.instanceFor(region: 'asia-south1');
  final _store = InAppPurchase.instance;
  final changes = ValueNotifier<int>(0);
  final message = ValueNotifier<String?>(null);
  final Map<String, ProductDetails> products = {};
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  Future<void> _queue = Future.value();
  final Map<String, PurchaseDetails> _retry = {};
  Completer<void>? _purchase;
  String? _buyingProduct;
  String? _buyingUid;
  DateTime? _lastRefresh;

  void initialize() {
    if (!supported || _subscription != null) return;
    WidgetsBinding.instance.addObserver(this);
    _subscription = _store.purchaseStream.listen(
      (purchases) {
        _queue = _queue.then((_) async {
          for (final purchase in purchases) {
            try {
              await _process(purchase);
            } catch (_) {
              message.value =
                  'Purchase processing needs a retry. Restore purchases before paying again.';
              _fail(message.value!);
            }
          }
        });
      },
      onError: (Object error) {
        message.value =
            'Apple purchases are unavailable. Please try restoring purchases.';
        _fail(message.value!);
      },
    );
    FirebaseAuth.instance.authStateChanges().listen((user) {
      _lastRefresh = null;
      if (user == null) return;
      _queue = _queue.then((_) async {
        for (final purchase in _retry.values.toList()) {
          try {
            await _process(purchase);
          } catch (_) {
            message.value =
                'Restore purchases to finish processing your subscription.';
          }
        }
      });
      unawaited(refresh());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  Future<void> refresh() async {
    if (FirebaseAuth.instance.currentUser == null) return;
    if (_lastRefresh != null &&
        DateTime.now().difference(_lastRefresh!) < const Duration(minutes: 5)) {
      return;
    }
    _lastRefresh = DateTime.now();
    try {
      await _functions.httpsCallable('refreshAppleSubscription').call();
      changes.value++;
    } catch (_) {
      _lastRefresh = null;
      // Existing server-verified access remains bounded by its expiry date.
    }
  }

  String billingPeriod(ProductDetails product) {
    if (product is AppStoreProduct2Details) {
      final period = product.sk2Product.subscription?.subscriptionPeriod;
      if (period != null) {
        return 'Every ${period.value} ${period.unit.name}${period.value == 1 ? '' : 's'}';
      }
    }
    return 'Auto-renewing subscription';
  }

  Future<void> loadProducts(Set<String> ids) async {
    initialize();
    if (!await _store.isAvailable()) {
      throw const ApplePurchaseException(
        'The App Store is unavailable on this device.',
      );
    }
    if (ids.isEmpty) return;
    final response = await _store.queryProductDetails(ids);
    if (response.error != null) {
      throw const ApplePurchaseException(
        'Could not load Apple prices. Please try again.',
      );
    }
    products
      ..clear()
      ..addEntries(response.productDetails.map((p) => MapEntry(p.id, p)));
  }

  Future<String> _accountToken() async {
    if (FirebaseAuth.instance.currentUser == null) {
      throw const ApplePurchaseException('Please sign in first.');
    }
    final result = await _functions
        .httpsCallable('prepareApplePurchase')
        .call();
    return result.data['appAccountToken'] as String;
  }

  Future<void> buy(String productId) async {
    initialize();
    if (_purchase != null) {
      throw const ApplePurchaseException('A purchase is already in progress.');
    }
    final product = products[productId];
    if (product == null) {
      throw const ApplePurchaseException(
        'This plan is not available from Apple yet.',
      );
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final token = await _accountToken();
    if (uid == null || uid != FirebaseAuth.instance.currentUser?.uid) {
      throw const ApplePurchaseException(
        'Your account changed. Please try again.',
      );
    }
    final pending = Completer<void>();
    _purchase = pending;
    _buyingProduct = productId;
    _buyingUid = uid;
    // Attach the error handler before native StoreKit can emit a result.
    final result = pending.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () {
        throw const ApplePurchaseException(
          'The purchase is still pending or needs verification. Use Restore Purchases to check; do not pay again.',
        );
      },
    );
    try {
      final opened = await _store.buyNonConsumable(
        purchaseParam: PurchaseParam(
          productDetails: product,
          applicationUserName: token,
        ),
      );
      if (!opened) _fail('Apple could not start this purchase.');
    } catch (_) {
      _fail('Apple could not start this purchase. Please try again.');
    }
    try {
      await result;
    } finally {
      _purchase = null;
      _buyingProduct = null;
      _buyingUid = null;
    }
  }

  void _fail(String text) {
    if (_purchase != null && !_purchase!.isCompleted) {
      _purchase!.completeError(ApplePurchaseException(text));
    }
  }

  Future<void> _process(PurchaseDetails purchase) async {
    if (purchase.status == PurchaseStatus.pending) {
      message.value = 'Waiting for Apple to approve the purchase.';
      return;
    }
    final matches = purchase.productID == _buyingProduct;
    if (purchase.status == PurchaseStatus.error ||
        purchase.status == PurchaseStatus.canceled) {
      final text = purchase.status == PurchaseStatus.canceled
          ? 'Purchase canceled.'
          : 'Apple could not complete the purchase. Please try again.';
      message.value = text;
      if (matches) _fail(text);
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
      return;
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || (matches && _buyingUid != uid)) {
      if (purchase.purchaseID != null) _retry[purchase.purchaseID!] = purchase;
      if (matches) {
        _fail(
          'Sign in to the account that started this purchase and restore purchases.',
        );
      }
      return; // Keep unverified transactions unfinished for a later retry.
    }
    final transactionId = purchase.purchaseID;
    if (transactionId == null) return;
    try {
      await _functions.httpsCallable('verifyApplePurchase').call({
        'transactionId': transactionId,
      });
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      if (purchase.pendingCompletePurchase) {
        await _store.completePurchase(purchase);
      }
      _retry.remove(transactionId);
      changes.value++;
      message.value = 'Apple purchase checked. Your access is up to date.';
      if (matches && _purchase != null && !_purchase!.isCompleted) {
        _purchase!.complete();
      }
    } catch (error) {
      _retry[transactionId] = purchase;
      final text =
          error is FirebaseFunctionsException &&
              error.code == 'permission-denied'
          ? 'This Apple subscription belongs to another Aapke Lawyer account. Sign in to that account to restore it.'
          : 'Purchase verification is incomplete. Use Restore Purchases to retry; do not pay again.';
      message.value = text;
      if (matches) _fail(text);
    }
  }

  Future<void> restore() async {
    initialize();
    message.value = null;
    await _accountToken();
    for (final purchase in _retry.values.toList()) {
      await _process(purchase);
    }
    await _store.restorePurchases();
    await _queue;
    await _functions.httpsCallable('refreshAppleSubscription').call();
    changes.value++;
    message.value ??=
        'Restore requested. Verified purchases will update your access.';
  }
}

class ApplePurchaseException implements Exception {
  const ApplePurchaseException(this.message);
  final String message;
}
