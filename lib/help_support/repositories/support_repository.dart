import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/support_models.dart';

class SupportRepository {
  SupportRepository({
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
    FirebaseStorage? storage,
  }) : _db = firestore ?? FirebaseFirestore.instance,
       _auth = auth ?? FirebaseAuth.instance,
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseStorage _storage;

  String get userId {
    final id = _auth.currentUser?.uid;
    if (id == null) throw StateError('Please sign in to contact support.');
    return id;
  }

  Stream<List<HelpArticle>> watchArticles() => _db
      .collection('help_articles')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map(
        (event) => event.docs
            .map((doc) => HelpArticle.fromJson(doc.id, doc.data()))
            .toList(),
      );

  Stream<List<SupportFaq>> watchFaqs() => _db
      .collection('faqs')
      .where('isActive', isEqualTo: true)
      .snapshots()
      .map((event) {
        final items = event.docs
            .map((doc) => SupportFaq.fromJson(doc.id, doc.data()))
            .toList();
        items.sort((a, b) => a.order.compareTo(b.order));
        return items;
      });

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAnnouncements() => _db
      .collection('announcements')
      .where('isActive', isEqualTo: true)
      .limit(5)
      .snapshots();

  Stream<QuerySnapshot<Map<String, dynamic>>> watchSystemStatus() =>
      _db.collection('system_status').limit(1).snapshots();

  Stream<List<SupportTicket>> watchTickets() => _db
      .collection('support_tickets')
      .where('userId', isEqualTo: userId)
      .snapshots()
      .map((event) {
        final items = event.docs
            .map((doc) => SupportTicket.fromJson(doc.id, doc.data()))
            .toList();
        items.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
        return items;
      });

  Future<String> createTicket({
    required String title,
    required String description,
    required String category,
    required SupportPriority priority,
    List<({String name, Uint8List bytes})> files = const [],
  }) async {
    final reference = _db.collection('support_tickets').doc();
    final attachments = <String>[];
    for (final file in files) {
      attachments.add(await _upload(reference.id, file.name, file.bytes));
    }
    await reference.set({
      'ticketId': reference.id,
      'userId': userId,
      'title': title.trim(),
      'description': description.trim(),
      'category': category,
      'priority': priority.name,
      'status': SupportTicketStatus.open.name,
      'attachments': attachments,
      'assignedTo': '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'closedAt': null,
      'deviceInfo': 'Flutter application',
      'appVersion': '1.0.0+1',
      'osVersion': '',
      'rating': null,
    });
    return reference.id;
  }

  Future<void> updateTicket(SupportTicket ticket) =>
      _db.collection('support_tickets').doc(ticket.id).update({
        'title': ticket.title.trim(),
        'description': ticket.description.trim(),
        'category': ticket.category,
        'priority': ticket.priority.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  Future<void> setTicketStatus(String id, SupportTicketStatus status) =>
      _db.collection('support_tickets').doc(id).update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
        'closedAt': status == SupportTicketStatus.closed
            ? FieldValue.serverTimestamp()
            : null,
      });

  Stream<List<SupportMessage>> watchMessages(String ticketId) => _db
      .collection('support_ticket_messages')
      .where('ticketId', isEqualTo: ticketId)
      .snapshots()
      .map((event) {
        final items = event.docs
            .map((doc) => SupportMessage.fromJson(doc.id, doc.data()))
            .toList();
        items.sort((a, b) => a.createdAt.compareTo(b.createdAt));
        return items;
      });

  Future<void> sendMessage(String ticketId, String message) async {
    final ref = _db.collection('support_ticket_messages').doc();
    await ref.set({
      'messageId': ref.id,
      'ticketId': ticketId,
      'senderId': userId,
      'senderType': 'user',
      'message': message.trim(),
      'attachment': '',
      'messageType': 'text',
      'createdAt': FieldValue.serverTimestamp(),
      'isSeen': false,
    });
    await _db.collection('support_tickets').doc(ticketId).update({
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> submitBug({
    required String description,
    required String category,
    required String severity,
  }) => _db.collection('bug_reports').add({
    'userId': userId,
    'description': description.trim(),
    'category': category,
    'severity': severity,
    'deviceModel': 'Flutter device',
    'operatingSystem': '',
    'appVersion': '1.0.0',
    'buildNumber': '1',
    'networkType': 'unknown',
    'screenshot': '',
    'createdAt': FieldValue.serverTimestamp(),
  });

  Stream<QuerySnapshot<Map<String, dynamic>>> watchFeatureRequests() => _db
      .collection('feature_requests')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots();

  Future<void> submitFeature(String title, String description) =>
      _db.collection('feature_requests').add({
        'title': title.trim(),
        'description': description.trim(),
        'votes': <String>[userId],
        'status': 'submitted',
        'createdBy': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<void> voteFeature(String id) =>
      _db.collection('feature_requests').doc(id).update({
        'votes': FieldValue.arrayUnion([userId]),
      });

  Future<void> submitFeedback(int rating, String comment) =>
      _db.collection('feedback').add({
        'rating': rating,
        'comment': comment.trim(),
        'userId': userId,
        'createdAt': FieldValue.serverTimestamp(),
      });

  Future<String> _upload(String ticketId, String name, Uint8List bytes) async {
    final safeName = name.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final ref = _storage.ref('support_attachments/$userId/$ticketId/$safeName');
    await ref.putData(bytes);
    return ref.getDownloadURL();
  }
}
