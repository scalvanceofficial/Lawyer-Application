import 'package:cloud_firestore/cloud_firestore.dart';

class CaseDocument {
  const CaseDocument({
    required this.id,
    required this.caseId,
    required this.name,
    required this.downloadUrl,
    required this.storagePath,
    required this.uploadedBy,
    required this.uploadedAt,
    required this.size,
  });

  final String id;
  final String caseId;
  final String name;
  final String downloadUrl;
  final String storagePath;
  final String uploadedBy;
  final DateTime uploadedAt;
  final int size;

  factory CaseDocument.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return CaseDocument(
      id: document.id,
      caseId: (data['caseId'] ?? '').toString(),
      name: (data['name'] ?? 'Document').toString(),
      downloadUrl: (data['downloadUrl'] ?? '').toString(),
      storagePath: (data['storagePath'] ?? '').toString(),
      uploadedBy: (data['uploadedBy'] ?? '').toString(),
      uploadedAt: data['uploadedAt'] is Timestamp
          ? (data['uploadedAt'] as Timestamp).toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
      size: (data['size'] as num?)?.round() ?? 0,
    );
  }
}
