import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';

import 'apple_purchase_service.dart';

import '../models/subscription_plan.dart';
import '../models/user_role.dart';
import 'registration_payment_service.dart';

class SubscriptionService {
  SubscriptionService._();

  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  static Stream<List<SubscriptionPlan>> plans() {
    return _firestore.collection('plans').snapshots().map((snapshot) {
      final plans =
          snapshot.docs
              .map(SubscriptionPlan.fromDocument)
              .where((plan) => plan.active && plan.price > 0)
              .toList()
            ..sort((a, b) => a.id.compareTo(b.id));
      return plans;
    });
  }

  static Future<SubscriptionAccess> access(UserRole role) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const SubscriptionAccess.inactive('Please log in to continue.');
    }

    final apple = await _firestore
        .collection('appleSubscriptions')
        .doc(user.uid)
        .get();
    final appleEnd = _date(apple.data()?['endDate']);
    if (apple.data()?['status'] == 'active' &&
        appleEnd != null &&
        appleEnd.isAfter(DateTime.now())) {
      return SubscriptionAccess.active(
        endDate: appleEnd,
        source: SubscriptionAccessSource.subscription,
      );
    }

    final subscription = await _firestore
        .collection('subscriptions')
        .doc(user.uid)
        .get();
    if (subscription.exists) {
      final data = subscription.data()!;
      final endDate = _date(data['endDate']);
      if (data['status'] == 'active' &&
          endDate != null &&
          endDate.isAfter(DateTime.now())) {
        return SubscriptionAccess.active(
          endDate: endDate,
          source: SubscriptionAccessSource.subscription,
        );
      }
    }

    if (role == UserRole.lawyer) {
      final profile = await _firestore
          .collection('lawyers')
          .doc(user.uid)
          .get();
      if (profile.exists) {
        final registrationDate = _date(
          profile.data()?['date'] ?? profile.data()?['createdAt'],
        );
        if (registrationDate != null) {
          final trialEnd = addMonths(registrationDate, 1);
          if (trialEnd.isAfter(DateTime.now())) {
            return SubscriptionAccess.active(
              endDate: trialEnd,
              source: SubscriptionAccessSource.lawyerTrial,
            );
          }
        }
      }
    }

    return const SubscriptionAccess.inactive(
      'Your subscription is inactive or expired. Please renew.',
    );
  }

  static Future<SubscriptionAccess> subscribe({
    required SubscriptionPlan plan,
    required UserRole role,
    required String name,
    required String email,
    required String phone,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const SubscriptionException('Please log in to subscribe.');
    }

    if (ApplePurchaseService.supported) {
      if (plan.appleProductId.isEmpty) {
        throw const SubscriptionException(
          'This plan is not available from Apple yet.',
        );
      }
      final current = await access(role);
      if (current.isActive &&
          current.source == SubscriptionAccessSource.subscription) {
        throw const SubscriptionException(
          'You already have an active subscription. Manage your current plan before purchasing again.',
        );
      }
      try {
        await ApplePurchaseService.instance.buy(plan.appleProductId);
        return await access(role);
      } on ApplePurchaseException catch (error) {
        throw SubscriptionException(error.message);
      } on FirebaseFunctionsException catch (error) {
        throw SubscriptionException(
          error.message ?? 'Apple purchases are unavailable. Please try again.',
        );
      }
    }
    RegistrationPaymentResult payment;
    try {
      payment = await RegistrationPaymentService().pay(
        name: name,
        email: email,
        phone: phone,
        userId: user.uid,
        userType: role.name,
        amount: plan.price,
        purpose: 'subscription',
        referenceId: plan.documentId,
      );
    } catch (_) {
      throw const SubscriptionException(
        'The Razorpay payment screen could not open. No payment was taken. '
        'Please check your connection and try again.',
      );
    }
    if (!payment.success) {
      throw SubscriptionException(
        payment.error == null
            ? 'Payment was not completed. No subscription was created.'
            : 'Payment was not completed: ${payment.error}',
      );
    }

    try {
      return await activateRazorpayPayment(
        paymentId: payment.paymentId!,
        plan: plan,
        role: role,
      );
    } on FirebaseException catch (error) {
      final reason = switch (error.code) {
        'permission-denied' => 'payment verification could not be authorized',
        'unavailable' =>
          'Firebase is temporarily unavailable or the internet connection was lost',
        _ => 'Firebase returned "${error.message ?? error.code}"',
      };
      throw SubscriptionActivationException(
        'Your payment succeeded, but the plan could not be activated because '
        '$reason. Do not pay again. Contact support with the payment ID below.',
        paymentId: payment.paymentId ?? 'Unavailable',
      );
    } catch (error) {
      throw SubscriptionActivationException(
        'Your payment succeeded, but the app could not save the subscription. '
        'Do not pay again. Contact support with the payment ID below.',
        paymentId: payment.paymentId ?? 'Unavailable',
      );
    }
  }

  static Future<SubscriptionAccess> activateRazorpayPayment({
    required String paymentId,
    required SubscriptionPlan plan,
    required UserRole role,
  }) async {
    final result = await FirebaseFunctions.instanceFor(region: 'asia-south1')
        .httpsCallable('verifyRazorpaySubscription')
        .call({
          'paymentId': paymentId,
          'planDocumentId': plan.documentId,
          'role': role.name,
        });
    final endDate = DateTime.fromMillisecondsSinceEpoch(
      (result.data['endDate'] as num).toInt(),
      isUtc: true,
    );
    if (!endDate.isAfter(DateTime.now())) {
      return const SubscriptionAccess.inactive(
        'This payment has already been used. No active access remains.',
      );
    }
    return SubscriptionAccess.active(
      endDate: endDate,
      source: SubscriptionAccessSource.subscription,
    );
  }

  static DateTime addMonths(DateTime date, int months) {
    final targetMonth = date.month - 1 + months;
    final year = date.year + targetMonth ~/ 12;
    final month = targetMonth % 12 + 1;
    final lastDay = DateTime.utc(year, month + 1, 0).day;
    final day = date.day > lastDay ? lastDay : date.day;
    return DateTime.utc(
      year,
      month,
      day,
      date.hour,
      date.minute,
      date.second,
      date.millisecond,
      date.microsecond,
    );
  }

  static DateTime? _date(dynamic value) {
    if (value is Timestamp) return value.toDate().toUtc();
    if (value is DateTime) return value.toUtc();
    if (value is String) return DateTime.tryParse(value)?.toUtc();
    return null;
  }
}

enum SubscriptionAccessSource { subscription, lawyerTrial }

class SubscriptionAccess {
  const SubscriptionAccess._({
    required this.isActive,
    this.endDate,
    this.source,
    this.message,
  });

  const SubscriptionAccess.active({
    required DateTime endDate,
    required SubscriptionAccessSource source,
  }) : this._(isActive: true, endDate: endDate, source: source);

  const SubscriptionAccess.inactive(String message)
    : this._(isActive: false, message: message);

  final bool isActive;
  final DateTime? endDate;
  final SubscriptionAccessSource? source;
  final String? message;
}

class SubscriptionException implements Exception {
  const SubscriptionException(this.message);
  final String message;
}

class SubscriptionActivationException extends SubscriptionException {
  const SubscriptionActivationException(
    super.message, {
    required this.paymentId,
  });

  final String paymentId;
}
