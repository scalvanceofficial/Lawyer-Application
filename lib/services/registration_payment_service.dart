import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

class RegistrationPaymentService {
  static const int amountInPaise = 100;
  static const int amountInRupees = 1;

  Future<RegistrationPaymentResult> pay({
    required String name,
    required String email,
    required String phone,
    required String userId,
    required String userType,
    int amount = amountInRupees,
    String purpose = 'lawyer_registration',
    String? referenceId,
  }) async {
    final keyId = await _loadKeyId();
    if (!keyId.startsWith('rzp_test_') && !keyId.startsWith('rzp_live_')) {
      throw const RegistrationPaymentException(
        'The Razorpay Key ID in Firestore is invalid.',
      );
    }

    final completer = Completer<RegistrationPaymentResult>();
    final razorpay = Razorpay();
    final payments = FirebaseFirestore.instance.collection('payments');

    Future<void> finish(RegistrationPaymentResult result) async {
      try {
        final logEntry = <String, dynamic>{
          'userId': userId,
          'paymentId': result.paymentId,
          'orderId': result.orderId,
          'signature': result.signature,
          'amount': amount,
          'amountPaise': amount * 100,
          'currency': 'INR',
          'status': result.success ? 'success' : 'failed',
          'platform': _platformName,
          'error': result.error,
          'errorCode': result.errorCode,
          'createdAt': FieldValue.serverTimestamp(),
          'userType': userType,
          'purpose': purpose,
        };
        if (referenceId != null) {
          logEntry[purpose == 'subscription' ? 'planDocumentId' : 'caseId'] =
              referenceId;
        }
        await payments.add(logEntry);
      } catch (_) {
        // A logging outage must not turn a completed Razorpay payment into a
        // failure or make the customer pay again.
      }
      if (!completer.isCompleted) completer.complete(result);
      razorpay.clear();
    }

    razorpay.on(Razorpay.EVENT_PAYMENT_SUCCESS, (
      PaymentSuccessResponse response,
    ) {
      unawaited(
        finish(
          RegistrationPaymentResult.success(
            paymentId: response.paymentId ?? '',
            orderId: response.orderId,
            signature: response.signature,
          ),
        ),
      );
    });
    razorpay.on(Razorpay.EVENT_PAYMENT_ERROR, (
      PaymentFailureResponse response,
    ) {
      unawaited(
        finish(
          RegistrationPaymentResult.failure(
            error: response.message ?? 'Payment failed. Please try again.',
            errorCode: response.code.toString(),
          ),
        ),
      );
    });
    razorpay.on(Razorpay.EVENT_EXTERNAL_WALLET, (
      ExternalWalletResponse response,
    ) {
      unawaited(
        finish(
          RegistrationPaymentResult.failure(
            error: 'External wallet checkout was not completed.',
          ),
        ),
      );
    });

    final notes = <String, dynamic>{'purpose': purpose, 'user_id': userId};
    if (referenceId != null) notes['reference_id'] = referenceId;
    razorpay.open({
      'key': keyId,
      'amount': amount * 100,
      'currency': 'INR',
      'name': 'Aapke Lawyer',
      'description': switch (purpose) {
        'subscription' => 'Aapke Lawyer Subscription',
        'case_activation' => 'Activate Legal Case',
        _ => 'Aapke Lawyer Payment',
      },
      'image': 'https://i.imgur.com/3g7nmJC.jpg',
      'prefill': {'name': name, 'email': email, 'contact': phone},
      // UPI opens first. Other methods enabled for this Razorpay account
      // (cards, netbanking, wallets, EMI and pay-later) remain available.
      'method': 'upi',
      'theme': {'color': '#965D29'},
      'retry': {'enabled': true, 'max_count': 4},
      'notes': notes,
      'config': {
        'display': {
          'language': 'en',
          'blocks': {
            'preferred': {
              'name': 'Pay using UPI',
              'instruments': [
                {'method': 'upi'},
              ],
            },
          },
          'sequence': ['block.preferred'],
          'preferences': {
            // Keep cards, netbanking, wallets, EMI and pay-later visible too.
            'show_default_blocks': true,
          },
        },
      },
    });

    return completer.future;
  }

  static Future<String> _loadKeyId() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('usefulkey')
          .get();
      for (final document in snapshot.docs) {
        final keyId = (document.data()['razorpay'] ?? '').toString().trim();
        if (keyId.isNotEmpty) return keyId;
      }
      throw const RegistrationPaymentException(
        'Razorpay Key ID is missing. Add a razorpay field to the usefulkey '
        'collection.',
      );
    } on RegistrationPaymentException {
      rethrow;
    } on FirebaseException catch (error) {
      throw RegistrationPaymentException(
        error.code == 'permission-denied'
            ? 'Firestore denied access to the Razorpay configuration.'
            : 'Could not read the Razorpay configuration: '
                  '${error.message ?? error.code}',
      );
    }
  }

  static String get _platformName {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'macos',
      TargetPlatform.windows => 'windows',
      TargetPlatform.linux => 'linux',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }
}

class RegistrationPaymentResult {
  const RegistrationPaymentResult._({
    required this.success,
    this.paymentId,
    this.orderId,
    this.signature,
    this.error,
    this.errorCode,
  });

  factory RegistrationPaymentResult.success({
    required String paymentId,
    String? orderId,
    String? signature,
  }) => RegistrationPaymentResult._(
    success: paymentId.isNotEmpty,
    paymentId: paymentId,
    orderId: orderId,
    signature: signature,
  );

  factory RegistrationPaymentResult.failure({
    required String error,
    String? errorCode,
  }) => RegistrationPaymentResult._(
    success: false,
    error: error,
    errorCode: errorCode,
  );

  final bool success;
  final String? paymentId;
  final String? orderId;
  final String? signature;
  final String? error;
  final String? errorCode;

  Map<String, dynamic> toMap() => {
    'amount': RegistrationPaymentService.amountInRupees,
    'amountPaise': RegistrationPaymentService.amountInPaise,
    'currency': 'INR',
    'purpose': 'lawyer_registration',
    'paymentId': paymentId,
    'orderId': orderId,
    'signature': signature,
    'status': 'paid',
    'paidAt': DateTime.now().toUtc().toIso8601String(),
  };
}

class RegistrationPaymentException implements Exception {
  const RegistrationPaymentException(this.message);
  final String message;
}
