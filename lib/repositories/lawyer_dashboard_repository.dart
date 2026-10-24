import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

class LawyerReview {
  const LawyerReview({
    required this.id,
    required this.clientName,
    required this.rating,
    required this.review,
    required this.createdAt,
  });
  final String id;
  final String clientName;
  final int rating;
  final String review;
  final DateTime createdAt;

  factory LawyerReview.fromDocument(
    DocumentSnapshot<Map<String, dynamic>> document,
  ) {
    final data = document.data() ?? const <String, dynamic>{};
    final createdAt = data['createdAt'];
    return LawyerReview(
      id: document.id,
      clientName: (data['clientName'] ?? 'User').toString(),
      rating: data['rating'] is num ? (data['rating'] as num).round() : 0,
      review: (data['review'] ?? '').toString(),
      createdAt: createdAt is Timestamp
          ? createdAt.toDate()
          : DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class LawyerDashboardRepository {
  LawyerDashboardRepository({
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
    if (uid == null) throw StateError('Please log in to continue.');
    return uid;
  }

  Stream<List<LawyerReview>> watchReviews() => _firestore
      .collection('lawyerReviews')
      .where('lawyerId', isEqualTo: _uid)
      .snapshots()
      .map((snapshot) {
        final reviews = snapshot.docs.map(LawyerReview.fromDocument).toList();
        reviews.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return reviews;
      });

  Future<void> updateAvailability(List<String> availability) async {
    final cleaned = availability
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (cleaned.isEmpty) throw StateError('Select at least one available day.');
    await _firestore.collection('lawyers').doc(_uid).update({
      'availability': cleaned,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProfile(Map<String, dynamic> values) async {
    const allowed = {
      'name',
      'address',
      'location',
      'dob',
      'gender',
      'bio',
      'barid',
      'aoe',
      'court',
      'experience',
      'availability',
      'img',
      'imageUrl',
    };
    final update = <String, dynamic>{};
    for (final entry in values.entries) {
      if (allowed.contains(entry.key)) update[entry.key] = entry.value;
    }
    if (update.isEmpty) throw StateError('No profile changes to save.');
    update['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('lawyers').doc(_uid).update(update);
  }

  Future<void> updateProfileImage(Uint8List bytes) async {
    if (bytes.isEmpty || bytes.length > 10 * 1024 * 1024) {
      throw StateError('Choose an image smaller than 10 MB.');
    }
    final reference = _storage.ref('profile_pictures/$_uid.jpg');
    await reference.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));
    final url = await reference.getDownloadURL();
    await updateProfile({'img': url, 'imageUrl': url});
  }
}
