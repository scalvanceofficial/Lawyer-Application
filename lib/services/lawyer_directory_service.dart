import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/lawyer_directory_profile.dart';

class LawyerDirectoryService {
  LawyerDirectoryService._();

  static Stream<List<LawyerDirectoryProfile>> watchLawyers() {
    return FirebaseFirestore.instance.collection('lawyers').snapshots().map((
      snapshot,
    ) {
      final lawyers =
          snapshot.docs
              .where((doc) => doc.data()['accountDeleting'] != true)
              .map(LawyerDirectoryProfile.fromDocument)
              .where((lawyer) => lawyer.name.isNotEmpty)
              .toList()
            ..sort((a, b) {
              if (a.verified != b.verified) return a.verified ? -1 : 1;
              return a.name.toLowerCase().compareTo(b.name.toLowerCase());
            });
      return lawyers;
    });
  }

  static Stream<List<LawyerDirectoryReview>> watchReviews(String lawyerId) {
    return FirebaseFirestore.instance
        .collection('lawyerReviews')
        .where('lawyerId', isEqualTo: lawyerId)
        .snapshots()
        .map((snapshot) {
          final reviews = snapshot.docs
              .map(LawyerDirectoryReview.fromDocument)
              .where((review) => review.rating >= 1 && review.review.isNotEmpty)
              .toList();
          reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return reviews;
        });
  }
}
