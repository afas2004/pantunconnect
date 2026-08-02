import 'package:shared_preferences/shared_preferences.dart';

/// Mirrors data/repository/PreferenceRepository.kt (backed by DataStore in the Kotlin app;
/// SharedPreferences here, which also works on Flutter Web via localStorage).
class PreferenceService {
  static const _darkModeKey = 'is_dark_mode';
  static const _onboardingKey = 'has_completed_onboarding';

  Future<bool> isDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey) ?? false;
  }

  Future<void> setDarkMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_darkModeKey, value);
  }

  Future<bool> hasCompletedOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  Future<void> setOnboardingCompleted(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, value);
  }
}
