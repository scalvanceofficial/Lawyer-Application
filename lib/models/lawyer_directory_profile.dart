import 'package:cloud_firestore/cloud_firestore.dart';

class LawyerDirectoryProfile {
  const LawyerDirectoryProfile({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.expertise,
    required this.location,
    required this.experienceYears,
    required this.court,
    required this.fee,
    required this.bio,
    required this.availability,
    required this.verified,
    required this.rating,
    required this.reviewCount,
    required this.online,
    required this.phone,
  });

  final String id;
  final String name;
  final String imageUrl;
  final String expertise;
  final String location;
  final int experienceYears;
  final String court;
  final int fee;
  final String bio;
  final List<String> availability;
  final bool verified;
  final double? rating;
  final int reviewCount;
  final bool? online;
  final String phone;

  factory LawyerDirectoryProfile.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    String text(String primary, [String? alternate]) {
      final value =
          data[primary] ?? (alternate == null ? null : data[alternate]) ?? '';
      if (value is Iterable) {
        return value
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .join(', ');
      }
      return value.toString().trim();
    }

    int number(String primary, [String? alternate]) {
      final value =
          data[primary] ?? (alternate == null ? null : data[alternate]);
      if (value is num) return value.round();
      return int.tryParse(value?.toString() ?? '') ?? 0;
    }

    final availabilityValue = data['availability'];
    return LawyerDirectoryProfile(
      id: document.id,
      name: text('name'),
      imageUrl: text('img', 'imageUrl'),
      expertise: text('aoe', 'expertise'),
      location: text('location', 'officeAddress'),
      experienceYears: number('experience', 'experienceYears'),
      court: text('court', 'courtType'),
      fee: number('fee', 'consultationFee'),
      bio: text('bio'),
      availability: availabilityValue is Iterable
          ? availabilityValue
                .map((day) => day.toString().trim())
                .where((day) => day.isNotEmpty)
                .toList(growable: false)
          : const [],
      verified: data['verified'] == true,
      rating: data['rating'] is num
          ? (data['rating'] as num).toDouble()
          : double.tryParse(data['rating']?.toString() ?? ''),
      reviewCount: number('reviewCount'),
      online: data['online'] is bool
          ? data['online'] as bool
          : data['isOnline'] is bool
          ? data['isOnline'] as bool
          : null,
      phone: text('phone'),
    );
  }

  bool matchesSearch(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return [
      name,
      expertise,
      location,
      court,
      bio,
      ...availability,
    ].any((value) => value.toLowerCase().contains(normalized));
  }
}

class LawyerDirectoryReview {
  const LawyerDirectoryReview({
    required this.clientName,
    required this.rating,
    required this.review,
    required this.createdAt,
  });

  final String clientName;
  final int rating;
  final String review;
  final DateTime createdAt;

  factory LawyerDirectoryReview.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final timestamp = data['createdAt'];
    return LawyerDirectoryReview(
      clientName: (data['clientName'] ?? 'User').toString(),
      rating: data['rating'] is num ? (data['rating'] as num).round() : 0,
      review: (data['review'] ?? '').toString().trim(),
      createdAt: timestamp is Timestamp
          ? timestamp.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
