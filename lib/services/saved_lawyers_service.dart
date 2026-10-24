import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/lawyer_directory_profile.dart';

class SavedLawyersException implements Exception {
  const SavedLawyersException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SavedLawyersService {
  SavedLawyersService._();

  static FirebaseFirestore get _firestore => FirebaseFirestore.instance;

  static String get _clientUid {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw const SavedLawyersException(
        'Your session has expired. Please sign in again.',
      );
    }
    return uid;
  }

  static CollectionReference<Map<String, dynamic>> _lawyers(String clientUid) =>
      _firestore
          .collection('saved_lawyers')
          .doc(clientUid)
          .collection('lawyers');

  static Stream<Set<String>> watchSavedLawyerIds() {
    final uid = _clientUid;
    return _lawyers(uid)
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((document) => document.id).toSet(),
        );
  }

  static Stream<bool> watchIsSaved(String lawyerUid) {
    final uid = _clientUid;
    return _lawyers(
      uid,
    ).doc(lawyerUid).snapshots().map((document) => document.exists);
  }

  static Future<bool> isSaved(String lawyerUid) async {
    try {
      return (await _lawyers(_clientUid).doc(lawyerUid).get()).exists;
    } catch (error) {
      throw _friendly(error);
    }
  }

  /// Returns false when the lawyer was already saved.
  static Future<bool> save(String lawyerUid) async {
    try {
      final reference = _lawyers(_clientUid).doc(lawyerUid);
      return _firestore.runTransaction((transaction) async {
        final existing = await transaction.get(reference);
        if (existing.exists) return false;
        transaction.set(reference, {
          'lawyerId': lawyerUid,
          'savedAt': FieldValue.serverTimestamp(),
        });
        return true;
      });
    } catch (error) {
      throw _friendly(error);
    }
  }

  static Future<void> remove(String lawyerUid) async {
    try {
      await _lawyers(_clientUid).doc(lawyerUid).delete();
    } catch (error) {
      throw _friendly(error);
    }
  }

  static Future<List<LawyerDirectoryProfile>> getProfiles(
    Iterable<String> lawyerUids,
  ) async {
    try {
      final ids = lawyerUids.toList(growable: false);
      if (ids.isEmpty) return const [];
      final documents = await Future.wait(
        ids.map((id) => _firestore.collection('lawyers').doc(id).get()),
      );
      return documents
          .where((document) => document.exists)
          .map(LawyerDirectoryProfile.fromDocument)
          .where((lawyer) => lawyer.name.isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      throw _friendly(error);
    }
  }

  static SavedLawyersException _friendly(Object error) {
    if (error is SavedLawyersException) return error;
    if (error is FirebaseException) {
      return switch (error.code) {
        'permission-denied' => const SavedLawyersException(
          'You do not have permission to change saved advocates. Please sign in again.',
        ),
        'unavailable' => const SavedLawyersException(
          'Saved advocates are unavailable right now. Check your internet connection and try again.',
        ),
        _ => SavedLawyersException(
          error.message ??
              'Could not update saved advocates. Please try again.',
        ),
      };
    }
    return const SavedLawyersException(
      'Something unexpected happened. Please try again.',
    );
  }
}
