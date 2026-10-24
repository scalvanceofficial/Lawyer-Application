import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/legal_case.dart';
import 'registration_payment_service.dart';

class CasePaymentService {
  CasePaymentService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  static const int platformFee = 149;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  Future<void> activateCase({
    required LegalCase legalCase,
    required String clientName,
    required String email,
    required String phone,
  }) async {
    final user = _auth.currentUser;
    if (user == null || user.uid != legalCase.clientId) {
      throw const CasePaymentException('You cannot activate this case.');
    }

    final freshCase = await _firestore
        .collection('cases')
        .doc(legalCase.id)
        .get();
    if (!freshCase.exists) {
      throw const CasePaymentException('Case no longer exists.');
    }
    if (LegalCase.fromDocument(freshCase).isPaidAndActive) return;

    final acceptedRequests = await _firestore
        .collection('consultationRequests')
        .where('caseId', isEqualTo: legalCase.id)
        .get();
    final hasAccepted = acceptedRequests.docs.any((document) {
      final data = document.data();
      return data['clientId'] == user.uid && data['status'] == 'accepted';
    });
    if (!hasAccepted) {
      throw const CasePaymentException(
        'Payment is available after at least one advocate accepts this case.',
      );
    }

    var payment = await _recoverSuccessfulPayment(user.uid, legalCase.id);
    payment ??= await RegistrationPaymentService().pay(
      name: clientName,
      email: email,
      phone: phone,
      userId: user.uid,
      userType: 'client',
      amount: platformFee,
      purpose: 'case_activation',
      referenceId: legalCase.id,
    );
    final successfulPayment = payment;
    if (!successfulPayment.success || successfulPayment.paymentId == null) {
      throw CasePaymentException(
        successfulPayment.error ??
            'Payment was cancelled. Communication remains locked.',
      );
    }

    final caseReference = _firestore.collection('cases').doc(legalCase.id);
    final paymentReference = _firestore
        .collection('casePayments')
        .doc(successfulPayment.paymentId);
    final timelineReference = _firestore.collection('caseTimeline').doc();
    try {
      await _firestore.runTransaction((transaction) async {
        final caseSnapshot = await transaction.get(caseReference);
        final paymentSnapshot = await transaction.get(paymentReference);
        if (!caseSnapshot.exists ||
            caseSnapshot.data()?['clientId'] != user.uid) {
          throw const CasePaymentException('Case no longer exists.');
        }
        final currentCase = LegalCase.fromDocument(caseSnapshot);
        if (currentCase.isPaidAndActive) return;
        if (paymentSnapshot.exists) {
          throw const CasePaymentException(
            'This payment has already been processed.',
          );
        }
        transaction.set(paymentReference, {
          'paymentId': successfulPayment.paymentId,
          'orderId': successfulPayment.orderId,
          'signature': successfulPayment.signature,
          'caseId': legalCase.id,
          'clientId': user.uid,
          'amount': platformFee,
          'amountPaise': platformFee * 100,
          'currency': 'INR',
          'status': 'success',
          'paidAt': FieldValue.serverTimestamp(),
        });
        transaction.update(caseReference, {
          'paymentStatus': 'paid',
          'status': 'active',
          'isActive': true,
          'casePaymentId': successfulPayment.paymentId,
          'activatedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(timelineReference, {
          'caseId': legalCase.id,
          'clientId': user.uid,
          'actorId': user.uid,
          'type': 'payment_successful',
          'message': '₹$platformFee platform fee paid — case activated',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
    } on CasePaymentException {
      rethrow;
    } catch (_) {
      throw CasePaymentRecoveryException(
        'Payment succeeded, but activation could not be saved. Do not pay '
        'again. Contact support with payment ID ${successfulPayment.paymentId}.',
        paymentId: successfulPayment.paymentId!,
      );
    }
  }

  Future<RegistrationPaymentResult?> _recoverSuccessfulPayment(
    String clientId,
    String caseId,
  ) async {
    final snapshot = await _firestore
        .collection('payments')
        .where('userId', isEqualTo: clientId)
        .get();
    for (final document in snapshot.docs.reversed) {
      final data = document.data();
      if (data['purpose'] == 'case_activation' &&
          data['caseId'] == caseId &&
          data['status'] == 'success' &&
          data['amount'] == platformFee &&
          (data['paymentId'] ?? '').toString().isNotEmpty) {
        return RegistrationPaymentResult.success(
          paymentId: data['paymentId'].toString(),
          orderId: data['orderId']?.toString(),
          signature: data['signature']?.toString(),
        );
      }
    }
    return null;
  }
}

class CasePaymentException implements Exception {
  const CasePaymentException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CasePaymentRecoveryException extends CasePaymentException {
  const CasePaymentRecoveryException(super.message, {required this.paymentId});
  final String paymentId;
}
