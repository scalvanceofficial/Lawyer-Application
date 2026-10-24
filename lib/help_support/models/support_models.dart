import 'package:cloud_firestore/cloud_firestore.dart';

DateTime _date(dynamic value) => value is Timestamp
    ? value.toDate()
    : value is DateTime
    ? value
    : DateTime.fromMillisecondsSinceEpoch(0);

enum SupportTicketStatus { open, inProgress, waitingUser, resolved, closed }

enum SupportPriority { low, medium, high, urgent }

class HelpArticle {
  const HelpArticle({
    required this.id,
    required this.title,
    required this.description,
    required this.content,
    required this.category,
    required this.keywords,
  });
  final String id;
  final String title;
  final String description;
  final String content;
  final String category;
  final List<String> keywords;

  factory HelpArticle.fromJson(String id, Map<String, dynamic> json) =>
      HelpArticle(
        id: id,
        title: (json['title'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        content: (json['content'] ?? '').toString(),
        category: (json['category'] ?? 'General').toString(),
        keywords: (json['keywords'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(),
      );
}

class SupportFaq {
  const SupportFaq({
    required this.id,
    required this.question,
    required this.answer,
    required this.category,
    required this.order,
  });
  final String id;
  final String question;
  final String answer;
  final String category;
  final int order;

  factory SupportFaq.fromJson(String id, Map<String, dynamic> json) =>
      SupportFaq(
        id: id,
        question: (json['question'] ?? '').toString(),
        answer: (json['answer'] ?? '').toString(),
        category: (json['category'] ?? 'General').toString(),
        order: (json['order'] as num?)?.toInt() ?? 0,
      );
}

class SupportTicket {
  const SupportTicket({
    required this.id,
    required this.userId,
    required this.title,
    required this.description,
    required this.category,
    required this.priority,
    required this.status,
    required this.attachments,
    required this.createdAt,
    required this.updatedAt,
  });
  final String id;
  final String userId;
  final String title;
  final String description;
  final String category;
  final SupportPriority priority;
  final SupportTicketStatus status;
  final List<String> attachments;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory SupportTicket.fromJson(String id, Map<String, dynamic> json) =>
      SupportTicket(
        id: id,
        userId: (json['userId'] ?? '').toString(),
        title: (json['title'] ?? '').toString(),
        description: (json['description'] ?? '').toString(),
        category: (json['category'] ?? 'General').toString(),
        priority: SupportPriority.values.firstWhere(
          (value) => value.name == json['priority'],
          orElse: () => SupportPriority.medium,
        ),
        status: SupportTicketStatus.values.firstWhere(
          (value) => value.name == json['status'],
          orElse: () => SupportTicketStatus.open,
        ),
        attachments: (json['attachments'] as List? ?? const [])
            .map((item) => item.toString())
            .toList(),
        createdAt: _date(json['createdAt']),
        updatedAt: _date(json['updatedAt']),
      );

  Map<String, dynamic> toJson() => {
    'ticketId': id,
    'userId': userId,
    'title': title,
    'description': description,
    'category': category,
    'priority': priority.name,
    'status': status.name,
    'attachments': attachments,
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}

class SupportMessage {
  const SupportMessage({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.message,
    required this.attachment,
    required this.createdAt,
    required this.isSeen,
  });
  final String id;
  final String ticketId;
  final String senderId;
  final String message;
  final String attachment;
  final DateTime createdAt;
  final bool isSeen;

  factory SupportMessage.fromJson(String id, Map<String, dynamic> json) =>
      SupportMessage(
        id: id,
        ticketId: (json['ticketId'] ?? '').toString(),
        senderId: (json['senderId'] ?? '').toString(),
        message: (json['message'] ?? '').toString(),
        attachment: (json['attachment'] ?? '').toString(),
        createdAt: _date(json['createdAt']),
        isSeen: json['isSeen'] == true,
      );
}
