import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/case_document.dart';
import '../models/case_timeline_event.dart';
import '../models/legal_case.dart';

class CaseRepository {
  CaseRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw const CaseException('Please log in to continue.');
    return uid;
  }

  Stream<List<LegalCase>> watchClientCases() {
    return _firestore
        .collection('cases')
        .where('clientId', isEqualTo: _uid)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs.map(LegalCase.fromDocument).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return items;
        });
  }

  Future<List<LegalCase>> openCases() async {
    final snapshot = await _firestore
        .collection('cases')
        .where('clientId', isEqualTo: _uid)
        .get();
    return snapshot.docs
        .map(LegalCase.fromDocument)
        .where((item) => item.status != LegalCaseStatus.completed)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  Future<LegalCase> getCase(String caseId) async {
    final document = await _firestore.collection('cases').doc(caseId).get();
    if (!document.exists) throw const CaseException('Case no longer exists.');
    return LegalCase.fromDocument(document);
  }

  Stream<LegalCase> watchCase(String caseId) {
    return _firestore.collection('cases').doc(caseId).snapshots().map((
      document,
    ) {
      if (!document.exists) throw const CaseException('Case no longer exists.');
      return LegalCase.fromDocument(document);
    });
  }

  Future<void> submitLawyerReview({
    required String caseId,
    required String requestId,
    required String lawyerId,
    required String lawyerName,
    required int rating,
    required String review,
  }) async {
    if (rating < 1 || rating > 5) {
      throw const CaseException('Please choose a rating from 1 to 5 stars.');
    }
    if (review.trim().length < 3) {
      throw const CaseException(
        'Please write a short review for the advocate.',
      );
    }
    final caseReference = _firestore.collection('cases').doc(caseId);
    final requestReference = _firestore
        .collection('consultationRequests')
        .doc(requestId);
    final reviewReference = _firestore
        .collection('lawyerReviews')
        .doc(requestId);
    final timelineReference = _firestore.collection('caseTimeline').doc();
    final notificationReference = _firestore.collection('notifications').doc();
    await _firestore.runTransaction((transaction) async {
      final caseSnapshot = await transaction.get(caseReference);
      final requestSnapshot = await transaction.get(requestReference);
      final reviewSnapshot = await transaction.get(reviewReference);
      if (!caseSnapshot.exists ||
          caseSnapshot.data()?['clientId'] != _uid ||
          caseSnapshot.data()?['isActive'] != true ||
          caseSnapshot.data()?['paymentStatus'] != 'paid') {
        throw const CaseException(
          'You can review an advocate only after the case fee is paid.',
        );
      }
      if (!requestSnapshot.exists ||
          requestSnapshot.data()?['caseId'] != caseId ||
          requestSnapshot.data()?['clientId'] != _uid ||
          requestSnapshot.data()?['lawyerId'] != lawyerId ||
          requestSnapshot.data()?['status'] != 'accepted') {
        throw const CaseException(
          'Only an accepted advocate can be rated and reviewed.',
        );
      }
      if (reviewSnapshot.exists) {
        throw const CaseException(
          'You have already reviewed this consultation.',
        );
      }
      transaction.set(reviewReference, {
        'reviewId': requestId,
        'requestId': requestId,
        'caseId': caseId,
        'clientId': _uid,
        'clientName': (requestSnapshot.data()?['clientName'] ?? 'User')
            .toString(),
        'lawyerId': lawyerId,
        'lawyerName': lawyerName,
        'rating': rating,
        'review': review.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(timelineReference, {
        'caseId': caseId,
        'clientId': _uid,
        'actorId': _uid,
        'type': 'lawyer_reviewed',
        'message': '$lawyerName rated $rating stars',
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.set(notificationReference, {
        'recipientId': lawyerId,
        'senderId': _uid,
        'caseId': caseId,
        'requestId': requestId,
        'title': 'New user review',
        'body':
            '${requestSnapshot.data()?['clientName'] ?? 'A user'} left a $rating-star review.',
        'type': 'lawyer_reviewed',
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> markCaseCompleted(String caseId) async {
    final caseReference = _firestore.collection('cases').doc(caseId);
    final timelineReference = _firestore.collection('caseTimeline').doc();
    await _firestore.runTransaction((transaction) async {
      final caseSnapshot = await transaction.get(caseReference);
      if (!caseSnapshot.exists ||
          caseSnapshot.data()?['clientId'] != _uid ||
          caseSnapshot.data()?['paymentStatus'] != 'paid') {
        throw const CaseException('Only a paid case can be marked completed.');
      }
      transaction.update(caseReference, {
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(timelineReference, {
        'caseId': caseId,
        'clientId': _uid,
        'actorId': _uid,
        'type': 'case_completed',
        'message': 'Case marked completed',
        'createdAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<String> createCase({
    required String title,
    required String category,
    required String description,
  }) async {
    final caseReference = _firestore.collection('cases').doc();
    final timelineReference = _firestore.collection('caseTimeline').doc();
    final batch = _firestore.batch();
    batch.set(caseReference, {
      'caseId': caseReference.id,
      'clientId': _uid,
      'title': title.trim(),
      'category': category.trim(),
      'description': description.trim(),
      'documents': <String>[],
      'documentPaths': <String>[],
      'paymentStatus': 'pending',
      'status': 'draft',
      'isActive': false,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.set(timelineReference, {
      'caseId': caseReference.id,
      'clientId': _uid,
      'actorId': _uid,
      'type': 'case_created',
      'message': 'Case created',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
    return caseReference.id;
  }

  Future<CaseDocument> uploadDocument({
    required String caseId,
    required String name,
    required Uint8List bytes,
    String? contentType,
  }) async {
    if (bytes.length > 10 * 1024 * 1024) {
      throw const CaseException('Each document must be smaller than 10 MB.');
    }
    final documentReference = _firestore.collection('caseDocuments').doc();
    final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath =
        'case_documents/$caseId/${documentReference.id}_$safeName';
    final storageReference = _storage.ref(storagePath);
    try {
      await storageReference.putData(
        bytes,
        SettableMetadata(
          contentType: contentType ?? 'application/octet-stream',
        ),
      );
      final url = await storageReference.getDownloadURL();
      final caseReference = _firestore.collection('cases').doc(caseId);
      final timelineReference = _firestore.collection('caseTimeline').doc();
      await _firestore.runTransaction((transaction) async {
        final caseSnapshot = await transaction.get(caseReference);
        if (!caseSnapshot.exists || caseSnapshot.data()?['clientId'] != _uid) {
          throw const CaseException('You cannot upload to this case.');
        }
        transaction.set(documentReference, {
          'caseId': caseId,
          'clientId': _uid,
          'name': name,
          'downloadUrl': url,
          'storagePath': storagePath,
          'uploadedBy': _uid,
          'uploadedAt': FieldValue.serverTimestamp(),
          'size': bytes.length,
          'contentType': contentType ?? 'application/octet-stream',
        });
        transaction.update(caseReference, {
          'documents': FieldValue.arrayUnion([
            {
              'documentId': documentReference.id,
              'name': name,
              'downloadUrl': url,
              'storagePath': storagePath,
              'uploadedBy': _uid,
              'size': bytes.length,
            },
          ]),
          'documentPaths': FieldValue.arrayUnion([storagePath]),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(timelineReference, {
          'caseId': caseId,
          'clientId': _uid,
          'actorId': _uid,
          'type': 'document_uploaded',
          'message': 'Document uploaded: $name',
          'createdAt': FieldValue.serverTimestamp(),
        });
      });
      return CaseDocument(
        id: documentReference.id,
        caseId: caseId,
        name: name,
        downloadUrl: url,
        storagePath: storagePath,
        uploadedBy: _uid,
        uploadedAt: DateTime.now(),
        size: bytes.length,
      );
    } catch (_) {
      try {
        await storageReference.delete();
      } catch (_) {
        // The upload may not have reached Storage.
      }
      rethrow;
    }
  }

  Stream<List<CaseDocument>> watchDocuments(String caseId) {
    return _firestore
        .collection('caseDocuments')
        .where('caseId', isEqualTo: caseId)
        .snapshots()
        .map((snapshot) {
          final documents = snapshot.docs
              .map(CaseDocument.fromDocument)
              .toList();
          documents.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));
          return documents;
        });
  }

  Stream<List<CaseTimelineEvent>> watchTimeline(String caseId) {
    return _firestore
        .collection('caseTimeline')
        .where('caseId', isEqualTo: caseId)
        .snapshots()
        .map((snapshot) {
          final events = snapshot.docs
              .map(CaseTimelineEvent.fromDocument)
              .toList();
          events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return events;
        });
  }
}

class CaseException implements Exception {
  const CaseException(this.message);
  final String message;
  @override
  String toString() => message;
}
