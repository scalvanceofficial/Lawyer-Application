import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_role.dart';

class AppPreferences {
  static const _onboardingCompleteKey = 'onboarding_complete';
  static const _currentUserIdKey = 'current_user_id';
  static const _userTypeKey = 'userType';
  static const _purgeCacheKey = 'purge_firestore_after_deletion';

  static Future<void> markDeletionRequested(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('deletion_requested_$uid', true);
  }

  static Future<bool> deletionRequested(String uid) async =>
      (await SharedPreferences.getInstance()).getBool(
        'deletion_requested_$uid',
      ) ??
      false;

  static Future<void> forgetUser(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_purgeCacheKey, true);
    await preferences.remove('user_role_$uid');
    await preferences.remove('deletion_requested_$uid');
    if (preferences.getString(_currentUserIdKey) == uid) {
      await preferences.remove(_currentUserIdKey);
      await preferences.remove(_userTypeKey);
    }
  }

  static Future<bool> needsCachePurge() async =>
      (await SharedPreferences.getInstance()).getBool(_purgeCacheKey) ?? false;

  static Future<void> cachePurged() async =>
      (await SharedPreferences.getInstance()).remove(_purgeCacheKey);

  static Future<bool> isOnboardingComplete() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(_onboardingCompleteKey) ?? false;
  }

  static Future<void> completeOnboarding() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_onboardingCompleteKey, true);
  }

  static Future<UserRole?> userRole(String uid) async {
    final preferences = await SharedPreferences.getInstance();
    final savedRole = preferences.getString('user_role_$uid');
    return UserRole.values.where((role) => role.name == savedRole).firstOrNull;
  }

  static Future<void> saveUserRole(String uid, UserRole role) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('user_role_$uid', role.name);
    await preferences.setString(_currentUserIdKey, uid);
    await preferences.setString(_userTypeKey, role.name);
  }
}
