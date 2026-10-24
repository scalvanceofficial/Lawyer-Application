import 'package:firebase_core/firebase_core.dart';

/// Converts expected infrastructure failures into messages that are safe and
/// useful to display. Domain exceptions keep their deliberately written text.
String appErrorMessage(Object error) {
  if (error is FirebaseException) {
    final detail = error.message?.trim();
    return switch (error.code) {
      'permission-denied' =>
        'Permission denied. Your account is not allowed to perform this action.',
      'unavailable' =>
        'The service is temporarily unavailable. Check your connection and try again.',
      'network-request-failed' =>
        'The request could not reach the server. Check your internet connection.',
      'not-found' => 'The requested record no longer exists.',
      'already-exists' => 'This action has already been completed.',
      'deadline-exceeded' => 'The request timed out. Please try again.',
      _ when detail != null && detail.isNotEmpty => detail,
      _ => 'Firebase error (${error.code}). Please try again.',
    };
  }

  final message = error.toString().trim();
  return message
      .replaceFirst(RegExp(r'^(Exception|StateError|Error):\s*'), '')
      .trim();
}
