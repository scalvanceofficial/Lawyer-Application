import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CaseChatMessage {
  const CaseChatMessage({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.message,
    required this.timestamp,
    required this.isRead,
  });

  final String id;
  final String senderId;
  final String receiverId;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  factory CaseChatMessage.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return CaseChatMessage(
      id: document.id,
      senderId: (data['senderId'] ?? '').toString(),
      receiverId: (data['receiverId'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      timestamp: data['timestamp'] is Timestamp
          ? (data['timestamp'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      isRead: data['isRead'] == true,
    );
  }
}

class CaseChatRepository {
  CaseChatRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid => _auth.currentUser?.uid ?? '';

  Stream<List<CaseChatMessage>> watchMessages(String requestId) {
    return _firestore
        .collection('caseChats')
        .doc(requestId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map(CaseChatMessage.fromDocument).toList(),
        );
  }

  Future<void> send({
    required String requestId,
    required String caseId,
    required String clientId,
    required String lawyerId,
    required String receiverId,
    required String message,
  }) async {
    final text = message.trim();
    if (text.isEmpty) return;
    final requestReference = _firestore
        .collection('consultationRequests')
        .doc(requestId);
    final caseReference = _firestore.collection('cases').doc(caseId);
    final chatReference = _firestore.collection('caseChats').doc(requestId);
    final messageReference = chatReference.collection('messages').doc();
    await _firestore.runTransaction((transaction) async {
      final request = await transaction.get(requestReference);
      final legalCase = await transaction.get(caseReference);
      if (!request.exists ||
          request.data()?['status'] != 'accepted' ||
          !legalCase.exists ||
          legalCase.data()?['paymentStatus'] != 'paid' ||
          legalCase.data()?['isActive'] != true ||
          ![_uid, receiverId].every((id) => id == clientId || id == lawyerId)) {
        throw StateError(
          'Chat is enabled only after the advocate accepts and the case fee is paid.',
        );
      }
      transaction.set(chatReference, {
        'caseId': caseId,
        'requestId': requestId,
        'clientId': clientId,
        'lawyerId': lawyerId,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      transaction.set(messageReference, {
        'senderId': _uid,
        'receiverId': receiverId,
        'message': text,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });
    });
  }
}
