import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../models/user_profile.dart';
import '../models/user_role.dart';
import '../screens/subscription_screen.dart';
import '../services/subscription_service.dart';
import '../services/apple_purchase_service.dart';
import '../theme/app_colors.dart';

class SubscriptionGate extends StatefulWidget {
  const SubscriptionGate({
    super.key,
    required this.role,
    required this.profile,
    required this.child,
  });

  final UserRole role;
  final UserProfile profile;
  final Widget child;

  @override
  State<SubscriptionGate> createState() => _SubscriptionGateState();
}

class _SubscriptionGateState extends State<SubscriptionGate> {
  late Future<SubscriptionAccess> _access;
  StreamSubscription<dynamic>? _appleUpdates;
  Timer? _expiry;

  @override
  void initState() {
    super.initState();
    _refresh();
    ApplePurchaseService.instance.changes.addListener(_changed);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _appleUpdates = FirebaseFirestore.instance
          .collection('appleSubscriptions')
          .doc(uid)
          .snapshots()
          .listen((_) => _changed(), onError: (Object _) {});
    }
  }

  void _changed() {
    if (mounted) setState(_refresh);
  }

  @override
  void dispose() {
    _expiry?.cancel();
    _appleUpdates?.cancel();
    ApplePurchaseService.instance.changes.removeListener(_changed);
    super.dispose();
  }

  void _refresh() {
    _expiry?.cancel();
    _access = SubscriptionService.access(widget.role);
    final current = _access;
    unawaited(
      current
          .then((access) {
            if (!mounted || current != _access || !access.isActive) return;
            final remaining = access.endDate!.difference(DateTime.now());
            _expiry = Timer(
              remaining.isNegative ? Duration.zero : remaining,
              _changed,
            );
          })
          .catchError((Object _) {}),
    );
  }

  Future<void> _openPlans() async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            SubscriptionScreen(role: widget.role, profile: widget.profile),
      ),
    );
    if (mounted) setState(_refresh);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SubscriptionAccess>(
    future: _access,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError) {
        return _BlockedAccess(
          message: 'We could not verify your subscription. Please try again.',
          actionLabel: 'Retry',
          onAction: () => setState(_refresh),
        );
      }
      final access = snapshot.data!;
      if (access.isActive) return widget.child;
      return _BlockedAccess(
        message:
            access.message ??
            'Your subscription is inactive or expired. Please renew.',
        actionLabel: 'View plans',
        onAction: _openPlans,
      );
    },
  );
}

class _BlockedAccess extends StatelessWidget {
  const _BlockedAccess({
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_outline, size: 58, color: kBrown),
              const SizedBox(height: 16),
              const Text(
                'Subscription required',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 9),
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.workspace_premium_outlined),
                label: Text(actionLabel),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
