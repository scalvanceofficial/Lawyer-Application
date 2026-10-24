import 'package:cloud_firestore/cloud_firestore.dart';

enum ConsultationRequestStatus { pending, accepted, rejected, completed }

class ConsultationRequest {
  const ConsultationRequest({
    required this.id,
    required this.caseId,
    required this.clientId,
    required this.lawyerId,
    required this.clientName,
    required this.lawyerName,
    required this.caseTitle,
    required this.category,
    required this.description,
    required this.clientPhone,
    required this.lawyerPhone,
    required this.status,
    required this.requestedAt,
    this.respondedAt,
  });

  final String id;
  final String caseId;
  final String clientId;
  final String lawyerId;
  final String clientName;
  final String lawyerName;
  final String caseTitle;
  final String category;
  final String description;
  final String clientPhone;
  final String lawyerPhone;
  final ConsultationRequestStatus status;
  final DateTime requestedAt;
  final DateTime? respondedAt;

  factory ConsultationRequest.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final statusName = (data['status'] ?? '').toString().toLowerCase();
    return ConsultationRequest(
      id: document.id,
      caseId: (data['caseId'] ?? '').toString(),
      clientId: (data['clientId'] ?? '').toString(),
      lawyerId: (data['lawyerId'] ?? '').toString(),
      clientName: (data['clientName'] ?? 'User').toString(),
      lawyerName: (data['lawyerName'] ?? 'Advocate').toString(),
      caseTitle: (data['caseTitle'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      clientPhone: (data['clientPhone'] ?? '').toString(),
      lawyerPhone: (data['lawyerPhone'] ?? '').toString(),
      status:
          ConsultationRequestStatus.values
              .where((value) => value.name == statusName)
              .firstOrNull ??
          ConsultationRequestStatus.pending,
      requestedAt: _date(data['requestedAt']),
      respondedAt: data['respondedAt'] is Timestamp
          ? (data['respondedAt'] as Timestamp).toDate()
          : null,
    );
  }

  static DateTime _date(dynamic value) => value is Timestamp
      ? value.toDate()
      : DateTime.fromMillisecondsSinceEpoch(0);
}
