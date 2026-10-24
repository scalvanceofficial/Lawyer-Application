import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/consultation_request.dart';
import '../models/legal_case.dart';

class ConsultationRepository {
  ConsultationRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      throw const ConsultationException('Please log in to continue.');
    }
    return uid;
  }

  Stream<List<ConsultationRequest>> watchClientRequests({String? caseId}) {
    return _firestore
        .collection('consultationRequests')
        .where('clientId', isEqualTo: _uid)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map(ConsultationRequest.fromDocument)
              .where((request) => caseId == null || request.caseId == caseId)
              .toList();
          requests.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
          return requests;
        });
  }

  Stream<List<ConsultationRequest>> watchLawyerRequests() {
    return _firestore
        .collection('consultationRequests')
        .where('lawyerId', isEqualTo: _uid)
        .snapshots()
        .map((snapshot) {
          final requests = snapshot.docs
              .map(ConsultationRequest.fromDocument)
              .toList();
          requests.sort((a, b) => b.requestedAt.compareTo(a.requestedAt));
          return requests;
        });
  }

  Future<ConsultationRequest> requestLawyer({
    required LegalCase legalCase,
    required String lawyerId,
    required String lawyerName,
    required String clientName,
    required String clientPhone,
    required String lawyerPhone,
  }) async {
    final requestId = '${legalCase.id}_$lawyerId';
    final requestReference = _firestore
        .collection('consultationRequests')
        .doc(requestId);
    final caseReference = _firestore.collection('cases').doc(legalCase.id);
    final lawyerReference = _firestore.collection('lawyers').doc(lawyerId);
    final timelineReference = _firestore.collection('caseTimeline').doc();
    final notificationReference = _firestore.collection('notifications').doc();

    await _firestore.runTransaction((transaction) async {
      final caseSnapshot = await transaction.get(caseReference);
      final requestSnapshot = await transaction.get(requestReference);
      final lawyerSnapshot = await transaction.get(lawyerReference);
      if (!caseSnapshot.exists || caseSnapshot.data()?['clientId'] != _uid) {
        throw const ConsultationException('Case no longer exists.');
      }
      final currentCase = LegalCase.fromDocument(caseSnapshot);
      if (currentCase.status == LegalCaseStatus.completed) {
        throw const ConsultationException(
          'Completed cases cannot be sent to another advocate.',
        );
      }
      if (!lawyerSnapshot.exists) {
        throw const ConsultationException(
          'This advocate account is no longer available.',
        );
      }
      if (requestSnapshot.exists) {
        throw const ConsultationException(
          'This case has already been sent to this advocate.',
        );
      }
      transaction.set(requestReference, {
        'requestId': requestId,
        'caseId': currentCase.id,
        'clientId': _uid,
        'lawyerId': lawyerId,
        'clientName': clientName,
        'clientPhone': clientPhone,
        'lawyerName': lawyerName,
        'lawyerPhone': lawyerPhone,
        'caseTitle': currentCase.title,
        'category': currentCase.category,
        'description': currentCase.description,
        'status': 'pending',
        'requestedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(timelineReference, {
        'caseId': currentCase.id,
        'clientId': _uid,
        'actorId': _uid,
        'type': 'request_sent',
        'message': 'Request sent to $lawyerName',
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notificationReference, {
        'recipientId': lawyerId,
        'senderId': _uid,
        'caseId': currentCase.id,
        'requestId': requestId,
        'title': 'New case request',
        'body': '$clientName sent ${currentCase.title}',
        'type': 'consultation_request',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
    final snapshot = await requestReference.get();
    return ConsultationRequest.fromDocument(snapshot);
  }

  Future<void> respond({
    required ConsultationRequest request,
    required bool accept,
  }) async {
    final requestReference = _firestore
        .collection('consultationRequests')
        .doc(request.id);
    final timelineReference = _firestore.collection('caseTimeline').doc();
    final notificationReference = _firestore.collection('notifications').doc();
    final nextStatus = accept ? 'accepted' : 'rejected';
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(requestReference);
      if (!snapshot.exists || snapshot.data()?['lawyerId'] != _uid) {
        throw const ConsultationException('Request no longer exists.');
      }
      if (snapshot.data()?['status'] != 'pending') {
        throw const ConsultationException(
          'This request has already been answered.',
        );
      }
      transaction.update(requestReference, {
        'status': nextStatus,
        'respondedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(timelineReference, {
        'caseId': request.caseId,
        'clientId': request.clientId,
        'actorId': _uid,
        'type': 'request_$nextStatus',
        'message':
            '${request.lawyerName} ${accept ? 'accepted' : 'rejected'} the request',
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notificationReference, {
        'recipientId': request.clientId,
        'senderId': _uid,
        'caseId': request.caseId,
        'requestId': request.id,
        'title': accept ? 'Request accepted' : 'Request rejected',
        'body':
            '${request.lawyerName} ${accept ? 'accepted' : 'rejected'} your request for ${request.caseTitle}',
        'type': 'request_$nextStatus',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }
}

class ConsultationException implements Exception {
  const ConsultationException(this.message);
  final String message;
  @override
  String toString() => message;
}
