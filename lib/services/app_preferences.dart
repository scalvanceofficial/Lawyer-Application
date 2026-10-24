import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_role.dart';

class AppPreferences {
  static const _onboardingCompleteKey = 'onboarding_complete';
  static const _currentUserIdKey = 'current_user_id';
  static const _userTypeKey = 'userType';

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
