import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';

import '../models/user_role.dart';
import '../models/user_profile.dart';
import 'app_preferences.dart';

class AuthService {
  AuthService._();

  static final FirebaseAuth _auth = FirebaseAuth.instance;
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseStorage _storage = FirebaseStorage.instance;

  static User? get currentUser => _auth.currentUser;

  static Future<UserRole?> currentUserRole() async {
    final user = currentUser;
    if (user == null) return null;

    try {
      final deletion = await _firestore
          .collection('accountDeletionJobs')
          .doc(user.uid)
          .get();
      if (deletion.exists) return null;
      UserRole? role;
      final userDocument = await _findProfileDocument(UserRole.client);
      if (userDocument != null) {
        final roleName = userDocument.data()?['role'] as String?;
        role = UserRole.values
            .where((value) => value.name == roleName)
            .firstOrNull;
        role ??= UserRole.client;
      } else if (await _findProfileDocument(UserRole.lawyer) != null) {
        role = UserRole.lawyer;
      }
      if (role != null) await AppPreferences.saveUserRole(user.uid, role);
      return role;
    } catch (_) {
      return AppPreferences.userRole(user.uid);
    }
  }

  static Future<UserProfile> currentUserProfile(UserRole role) async {
    final user = currentUser;
    if (user == null) {
      throw const AuthAccountException('You are not logged in.');
    }
    final document = await _findProfileDocument(role);
    if (document == null) {
      throw const AuthAccountException('Your account profile is missing.');
    }
    return UserProfile.fromMap(
      id: document.id,
      role: role,
      data: document.data()!,
    );
  }

  static Stream<UserProfile> watchCurrentUserProfile(UserRole role) {
    final user = currentUser;
    if (user == null) {
      return Stream.error(const AuthAccountException('You are not logged in.'));
    }
    final collection = role == UserRole.lawyer ? 'lawyers' : 'users';
    return _firestore.collection(collection).doc(user.uid).snapshots().map((
      doc,
    ) {
      final data = doc.data();
      if (!doc.exists || data == null) {
        throw const AuthAccountException('Your account profile is missing.');
      }
      return UserProfile.fromMap(id: doc.id, role: role, data: data);
    });
  }

  static Future<void> updateClientProfile({
    required Map<String, dynamic> values,
    Uint8List? imageBytes,
  }) async {
    final user = currentUser;
    if (user == null) {
      throw const AuthAccountException('You are not logged in.');
    }
    const allowed = {'name', 'address', 'dob', 'gender', 'bio'};
    final update = <String, dynamic>{};
    for (final entry in values.entries) {
      if (allowed.contains(entry.key)) update[entry.key] = entry.value;
    }
    if (imageBytes != null) {
      if (imageBytes.isEmpty || imageBytes.length > 10 * 1024 * 1024) {
        throw const AuthAccountException('Choose an image smaller than 10 MB.');
      }
      final reference = _storage.ref('profile_pictures/${user.uid}.jpg');
      await reference.putData(
        imageBytes,
        SettableMetadata(contentType: 'image/jpeg'),
      );
      final url = await reference.getDownloadURL();
      update['img'] = url;
      update['imageUrl'] = url;
    }
    if (update.isEmpty) throw const AuthAccountException('No changes to save.');
    update['updatedAt'] = FieldValue.serverTimestamp();
    await _firestore.collection('users').doc(user.uid).update(update);
  }

  static Future<QueryDocumentSnapshot<Map<String, dynamic>>?>
  _queryProfileByEmail(String collection) async {
    final email = currentUser?.email?.trim().toLowerCase();
    if (email == null || email.isEmpty) return null;
    final result = await _firestore
        .collection(collection)
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    return result.docs.firstOrNull;
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>?> _findProfileDocument(
    UserRole role,
  ) async {
    final user = currentUser;
    if (user == null) return null;
    final collection = role == UserRole.lawyer ? 'lawyers' : 'users';
    final byUid = await _firestore.collection(collection).doc(user.uid).get();
    if (byUid.exists) return byUid;
    return _queryProfileByEmail(collection);
  }

  static Future<UserRole> signIn({
    required String email,
    required String password,
    required UserRole selectedRole,
  }) async {
    await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );

    try {
      final selectedProfile = await _findProfileDocument(selectedRole);
      if (selectedProfile != null) {
        try {
          final token = await FirebaseMessaging.instance.getToken();
          if (token != null && token.isNotEmpty) {
            await selectedProfile.reference.update({'token': token});
          }
        } catch (_) {
          // Notification setup must not block a valid login.
        }
        await AppPreferences.saveUserRole(currentUser!.uid, selectedRole);
        return selectedRole;
      }

      final otherRole = selectedRole == UserRole.client
          ? UserRole.lawyer
          : UserRole.client;
      final otherProfile = await _findProfileDocument(otherRole);
      if (otherProfile == null) {
        throw const AuthAccountException(
          'Your account profile is missing. Please contact support.',
        );
      }
      throw AuthAccountException(
        'This account is registered as a ${otherRole.label}.',
      );
    } catch (_) {
      await _auth.signOut();
      rethrow;
    }
  }

  static Future<void> register({
    required String email,
    required String password,
    required UserRole role,
    required Map<String, dynamic> profile,
    required Uint8List profileImageBytes,
  }) async {
    final phoneUser = currentUser;
    if (phoneUser == null || phoneUser.phoneNumber == null) {
      throw const AuthAccountException(
        'Please verify your phone number before registering.',
      );
    }

    final normalizedEmail = email.trim().toLowerCase();
    User user = phoneUser;
    if (phoneUser.email?.toLowerCase() != normalizedEmail) {
      final credential = await phoneUser.linkWithCredential(
        EmailAuthProvider.credential(
          email: normalizedEmail,
          password: password,
        ),
      );
      user = credential.user!;
    }

    await user.updateDisplayName(profile['name'] as String?);
    if (profileImageBytes.isEmpty ||
        profileImageBytes.length > 5 * 1024 * 1024) {
      throw const AuthAccountException(
        'Please choose a profile photo smaller than 5 MB.',
      );
    }
    final imageReference = _storage.ref('profile_pictures/${user.uid}.jpg');
    await imageReference.putData(
      profileImageBytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final imageUrl = await imageReference.getDownloadURL();

    String token = '';
    try {
      token = await FirebaseMessaging.instance.getToken() ?? '';
    } catch (_) {
      // Notifications can be configured later without blocking registration.
    }

    try {
      final collection = role == UserRole.lawyer ? 'lawyers' : 'users';
      await _firestore.collection(collection).doc(user.uid).set({
        ...profile,
        'img': imageUrl,
        'imageUrl': imageUrl,
        'email': normalizedEmail,
        'role': role.name,
        'uid': user.uid,
        'token': token,
        'date': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await AppPreferences.saveUserRole(user.uid, role);
    } catch (_) {
      // Keep the authenticated user and uploaded image so retrying account
      // creation remains idempotent.
      rethrow;
    }
  }

  static Future<void> sendPasswordResetEmail(String email) {
    return _auth.sendPasswordResetEmail(email: email.trim());
  }

  static Future<void> signOut() => _auth.signOut();
}

class AuthAccountException implements Exception {
  const AuthAccountException(this.message);
  final String message;
}
