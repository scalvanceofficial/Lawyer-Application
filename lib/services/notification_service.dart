import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../firebase_options.dart';

const _channel = AndroidNotificationChannel(
  'important_notifications',
  'Important notifications',
  description: 'Consultation, account, and case updates.',
  importance: Importance.max,
);

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Messages containing a notification block are displayed by FCM itself while
  // the app is in the background. Data-only messages need a local notification.
  if (message.notification == null) {
    await NotificationService.show(message);
  }
}

class NotificationService {
  NotificationService._();

  static Future<void> clearForDeletedAccount() async {
    _pendingTap = null;
    if (_localInitialized) await _localNotifications.cancelAll();
  }

  static final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  static final StreamController<Map<String, dynamic>> _notificationTaps =
      StreamController<Map<String, dynamic>>.broadcast();

  static bool _initialized = false;
  static bool _localInitialized = false;
  static Map<String, dynamic>? _pendingTap;
  static AppLifecycleListener? _lifecycleListener;

  /// Emits the data attached to a notification when the user opens it.
  static Stream<Map<String, dynamic>> get onNotificationTap =>
      _notificationTaps.stream;

  static Map<String, dynamic>? consumePendingTap() {
    final value = _pendingTap;
    _pendingTap = null;
    return value;
  }

  static Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
    await _initializeLocalNotifications();

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );

    FirebaseMessaging.onMessage.listen(show);
    FirebaseMessaging.onMessageOpenedApp.listen(_handleRemoteTap);
    _messaging.onTokenRefresh.listen(_saveToken);
    _lifecycleListener ??= AppLifecycleListener(
      onResume: () => unawaited(syncCurrentUserToken()),
    );
    FirebaseAuth.instance.authStateChanges().listen((user) async {
      if (user == null) return;
      try {
        await _messaging.subscribeToTopic('announcements');
        await syncCurrentUserToken();
      } on FirebaseException {
        // iOS may not have an APNs token until permission has been requested.
      }
    });

    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      Future<void>.delayed(
        Duration.zero,
        () => _handleRemoteTap(initialMessage),
      );
    }
  }

  static Future<NotificationSettings> requestPermission() {
    return _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  static Future<bool> requestPermissionAndSyncToken() async {
    try {
      final settings = await _messaging.getNotificationSettings();
      final resolved =
          settings.authorizationStatus == AuthorizationStatus.notDetermined
          ? await requestPermission()
          : settings;
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) await _saveToken(token);
      return resolved.authorizationStatus == AuthorizationStatus.authorized ||
          resolved.authorizationStatus == AuthorizationStatus.provisional;
    } on FirebaseException {
      // A denied permission or temporarily unavailable APNs token must not
      // interrupt onboarding or dashboard loading.
      return false;
    }
  }

  static Future<void> ensurePermissionOnEntry(BuildContext context) async {
    final allowed = await requestPermissionAndSyncToken();
    if (allowed || !context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.notifications_off_outlined),
        title: const Text('Enable notifications'),
        content: const Text(
          'Notifications are needed for advocate requests, replies, payments, '
          'case updates, and new chat messages. Enable them in your device '
          'settings if permission was previously denied.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () async {
              await requestPermission();
              if (dialogContext.mounted) Navigator.pop(dialogContext);
              await requestPermissionAndSyncToken();
            },
            child: const Text('Allow notifications'),
          ),
        ],
      ),
    );
  }

  static Future<String?> get deviceToken => _messaging.getToken();

  /// Reads the current FCM token and writes it to the authenticated client's
  /// or lawyer's Firestore profile. Safe to call on every launch and resume.
  static Future<bool> syncCurrentUserToken() async {
    if (FirebaseAuth.instance.currentUser == null) return false;
    try {
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) return false;
      return _saveToken(token);
    } on FirebaseException {
      // On iOS the APNs token may not exist until notification permission has
      // been resolved. Dashboard entry and token refresh will retry the sync.
      return false;
    }
  }

  static Future<void> _initializeLocalNotifications() async {
    if (_localInitialized) return;
    _localInitialized = true;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        _emitPayload(response.payload);
      },
    );
    await _localNotifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);
  }

  static Future<void> show(RemoteMessage message) async {
    await _initializeLocalNotifications();
    final notification = message.notification;
    final title =
        notification?.title ??
        message.data['title']?.toString() ??
        'Aapke Lawyer';
    final body = notification?.body ?? message.data['body']?.toString() ?? '';
    if (body.isEmpty && notification == null) return;

    await _localNotifications.show(
      id:
          message.messageId?.hashCode ??
          DateTime.now().millisecondsSinceEpoch.remainder(1 << 31),
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'important_notifications',
          'Important notifications',
          channelDescription: 'Consultation, account, and case updates.',
          importance: Importance.max,
          priority: Priority.high,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(message.data),
    );
  }

  static void _handleRemoteTap(RemoteMessage message) {
    final data = Map<String, dynamic>.from(message.data);
    _pendingTap = data;
    _notificationTaps.add(data);
  }

  static void _emitPayload(String? payload) {
    if (payload == null || payload.isEmpty) return;
    try {
      final decoded = jsonDecode(payload);
      if (decoded is Map<String, dynamic>) {
        _pendingTap = decoded;
        _notificationTaps.add(decoded);
      }
    } on FormatException {
      // Ignore malformed payloads; the notification itself was still shown.
    }
  }

  static Future<bool> _saveToken(String token) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || token.isEmpty) return false;

      final firestore = FirebaseFirestore.instance;
      for (final collection in const ['users', 'lawyers']) {
        final byUid = firestore.collection(collection).doc(user.uid);
        final snapshot = await byUid.get();
        if (snapshot.exists) {
          await byUid.update({
            'token': token,
            'notificationTokenUpdatedAt': FieldValue.serverTimestamp(),
          });
          return true;
        }
      }

      final email = user.email?.trim().toLowerCase();
      if (email == null || email.isEmpty) return false;
      for (final collection in const ['users', 'lawyers']) {
        final result = await firestore
            .collection(collection)
            .where('email', isEqualTo: email)
            .limit(1)
            .get();
        if (result.docs.isNotEmpty) {
          await result.docs.first.reference.update({
            'token': token,
            'notificationTokenUpdatedAt': FieldValue.serverTimestamp(),
          });
          return true;
        }
      }
    } on FirebaseException {
      // Token sync is retried on the next auth event or FCM token refresh.
    }
    return false;
  }
}
