import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import 'app_preferences.dart';
import 'notification_service.dart';

class AccountDeletionService {
  static Stream<DocumentSnapshot<Map<String, dynamic>>> watch(String uid) =>
      FirebaseFirestore.instance
          .collection('accountDeletionJobs')
          .doc(uid)
          .snapshots();

  static Future<void> request({required String password}) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) throw StateError('Please sign in again.');
    if (user.providerData.any(
      (provider) => provider.providerId == 'password',
    )) {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: password),
      );
      await user.getIdToken(true);
    }
    if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
      throw StateError('Your signed-in account changed. Please try again.');
    }
    await FirebaseFunctions.instanceFor(
      region: 'asia-south1',
    ).httpsCallable('requestAccountDeletion').call({'confirmation': 'DELETE'});
  }

  static Future<void> leaveAccount(String uid) async {
    // A failed notification cleanup must never prevent sign-out.
    try {
      await FirebaseMessaging.instance
          .unsubscribeFromTopic('announcements')
          .timeout(const Duration(seconds: 5));
      await FirebaseMessaging.instance.deleteToken().timeout(
        const Duration(seconds: 5),
      );
      await NotificationService.clearForDeletedAccount();
    } catch (_) {
      /* The server removes the stored push token with the profile. */
    }
    try {
      await AppPreferences.forgetUser(uid);
    } finally {
      await FirebaseAuth.instance.signOut();
    }
  }
}
