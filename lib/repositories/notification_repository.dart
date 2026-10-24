import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/app_notification.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String get _uid {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Please log in to view notifications.');
    return uid;
  }

  Stream<List<AppNotification>> watchCurrentUserNotifications() {
    return _firestore
        .collection('notifications')
        .where('recipientId', isEqualTo: _uid)
        .snapshots()
        .map((snapshot) {
          final notifications = snapshot.docs
              .map(AppNotification.fromDocument)
              .toList();
          notifications.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return notifications;
        });
  }

  Future<void> markRead(String notificationId) {
    return _firestore.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  Future<void> markAllRead(Iterable<AppNotification> notifications) async {
    final unread = notifications.where((item) => !item.isRead).toList();
    if (unread.isEmpty) return;
    final batch = _firestore.batch();
    for (final item in unread) {
      batch.update(_firestore.collection('notifications').doc(item.id), {
        'isRead': true,
      });
    }
    await batch.commit();
  }
}
