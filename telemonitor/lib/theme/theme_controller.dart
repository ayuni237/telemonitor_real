import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the user's theme choice and persists it across restarts.
///
/// Stored on the device rather than in Firestore: a theme preference is
/// a property of how this person uses this handset, not clinical data,
/// and keeping it local means it applies instantly at launch without
/// waiting for a network read.
class ThemeController extends ChangeNotifier {
  ThemeController._internal();
  static final ThemeController instance = ThemeController._internal();

  static const _prefsKey = 'theme_mode';

  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Loads the saved choice. Call once from main() before runApp, so the
  /// first frame is already in the right theme rather than flashing the
  /// wrong one.
  Future<void> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_prefsKey);
      _mode = _parse(saved);
    } catch (_) {
      // Storage unavailable — fall back to following the system.
      _mode = ThemeMode.system;
    }
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsKey, mode.name);
    } catch (_) {
      // The choice still applies for this session even if it cannot be
      // written; failing to persist is not worth interrupting the user.
    }
  }

  static ThemeMode _parse(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// Human-readable label for the current setting.
  String get label {
    switch (_mode) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'Match device';
    }
  }
}
