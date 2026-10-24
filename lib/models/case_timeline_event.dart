import 'package:cloud_firestore/cloud_firestore.dart';

class CaseTimelineEvent {
  const CaseTimelineEvent({
    required this.id,
    required this.caseId,
    required this.type,
    required this.message,
    required this.actorId,
    required this.createdAt,
  });

  final String id;
  final String caseId;
  final String type;
  final String message;
  final String actorId;
  final DateTime createdAt;

  factory CaseTimelineEvent.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return CaseTimelineEvent(
      id: document.id,
      caseId: (data['caseId'] ?? '').toString(),
      type: (data['type'] ?? '').toString(),
      message: (data['message'] ?? '').toString(),
      actorId: (data['actorId'] ?? '').toString(),
      createdAt: data['createdAt'] is Timestamp
          ? (data['createdAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
