import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'services/apple_purchase_service.dart';
import 'services/app_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  if (await AppPreferences.needsCachePurge()) {
    await FirebaseFirestore.instance.clearPersistence();
    await AppPreferences.cachePurged();
  }
  ApplePurchaseService.instance.initialize();
  runApp(const AapkeLawyerApp());
  unawaited(_initializeBackgroundServices());
}

Future<void> _initializeFirebase() async {
  if (Firebase.apps.isNotEmpty) return;
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (error) {
    // Android may have already created [DEFAULT] from google-services.json.
    // Reuse it instead of preventing Flutter from rendering its first frame.
    if (error.code != 'duplicate-app') rethrow;
    Firebase.app();
  }
}

Future<void> _initializeBackgroundServices() async {
  const requestedDebugAppCheck = bool.fromEnvironment('USE_APP_CHECK_DEBUG');
  final useDebugAppCheck = kDebugMode || requestedDebugAppCheck;
  try {
    await FirebaseAppCheck.instance
        .activate(
          providerAndroid: useDebugAppCheck
              ? const AndroidDebugProvider()
              : const AndroidPlayIntegrityProvider(),
          providerApple: useDebugAppCheck
              ? const AppleDebugProvider()
              : const AppleAppAttestProvider(),
        )
        .timeout(const Duration(seconds: 8));
  } on Object catch (error) {
    debugPrint('App Check initialization did not complete: $error');
  }

  try {
    await NotificationService.initialize().timeout(const Duration(seconds: 8));
  } on Object catch (error) {
    debugPrint('Notification initialization did not complete: $error');
  }
}
