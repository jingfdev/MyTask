import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeViewModel extends ChangeNotifier {
  static const String _darkModeKey = 'dark_mode_enabled';

  bool _isDarkMode = false;
  SharedPreferences? _prefs;
  bool _isInitialized = false;

  bool get isDarkMode => _isDarkMode;
  bool get isInitialized => _isInitialized;

  /// Initialize theme from shared preferences
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _isDarkMode = _prefs?.getBool(_darkModeKey) ?? false;
      _isInitialized = true;
      debugPrint('✅ Theme initialized. Dark mode: $_isDarkMode');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error initializing ThemeViewModel: $e');
      _isInitialized = true;
      notifyListeners();
    }
  }

  /// Toggle dark mode and persist preference
  Future<void> toggleDarkMode({bool? value}) async {
    try {
      final newValue = value ?? !_isDarkMode;
      if (_isDarkMode == newValue) {
        debugPrint('⚠️ Dark mode already set to: $newValue, skipping');
        return;
      }

      _isDarkMode = newValue;
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setBool(_darkModeKey, newValue);

      debugPrint('✅ Dark mode toggled to: $newValue');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error toggling dark mode: $e');
    }
  }

  /// Get current theme data based on dark mode setting
  ThemeData getThemeData() {
    if (_isDarkMode) {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
      );
    } else {
      return ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      );
    }
  }
}

