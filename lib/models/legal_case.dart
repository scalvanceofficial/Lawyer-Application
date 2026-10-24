import 'package:cloud_firestore/cloud_firestore.dart';

enum CasePaymentStatus { pending, paid }

enum LegalCaseStatus { draft, active, completed }

class LegalCase {
  const LegalCase({
    required this.id,
    required this.clientId,
    required this.title,
    required this.category,
    required this.description,
    required this.documentIds,
    required this.paymentStatus,
    required this.status,
    required this.isActive,
    required this.createdAt,
    this.activatedAt,
  });

  final String id;
  final String clientId;
  final String title;
  final String category;
  final String description;
  final List<String> documentIds;
  final CasePaymentStatus paymentStatus;
  final LegalCaseStatus status;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? activatedAt;

  bool get isPaidAndActive =>
      paymentStatus == CasePaymentStatus.paid && isActive;

  factory LegalCase.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    return LegalCase(
      id: document.id,
      clientId: (data['clientId'] ?? '').toString(),
      title: (data['title'] ?? '').toString(),
      category: (data['category'] ?? '').toString(),
      description: (data['description'] ?? '').toString(),
      documentIds: (data['documents'] as List? ?? const [])
          .map(
            (value) => value is Map
                ? (value['documentId'] ?? '').toString()
                : value.toString(),
          )
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      paymentStatus: _enumValue(
        CasePaymentStatus.values,
        data['paymentStatus'],
        CasePaymentStatus.pending,
      ),
      status: _enumValue(
        LegalCaseStatus.values,
        data['status'],
        LegalCaseStatus.draft,
      ),
      isActive: data['isActive'] == true,
      createdAt:
          _date(data['createdAt']) ?? DateTime.fromMillisecondsSinceEpoch(0),
      activatedAt: _date(data['activatedAt']),
    );
  }
}

T _enumValue<T extends Enum>(List<T> values, dynamic raw, T fallback) {
  final name = raw?.toString().toLowerCase();
  return values.where((value) => value.name == name).firstOrNull ?? fallback;
}

DateTime? _date(dynamic value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  if (value is String) return DateTime.tryParse(value);
  return null;
}
