import 'dart:ui' show PlatformDispatcher;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The language of the app, English or French, chosen by the user.
///
/// Kept on the phone, so the login screen is in it before any account, and
/// on the account (users/{uid}.language), so the worker writes notifications
/// and emails in it. Until the user chooses, the phone's language when it is
/// French, English otherwise.
class LocaleController extends ChangeNotifier {
  LocaleController._internal();
  static final LocaleController instance = LocaleController._internal();

  static const supported = ['en', 'fr'];
  static const _prefsKey = 'language';

  String? _chosen;

  /// 'en' or 'fr'.
  String get code => _chosen ?? _phone();

  @override
  void notifyListeners() {
    Intl.defaultLocale = code; // dates (DateFormat) in the same language
    super.notifyListeners();
  }

  Locale get locale => Locale(code);

  static String _phone() {
    final language = PlatformDispatcher.instance.locale.languageCode;
    return supported.contains(language) ? language : 'en';
  }

  /// Loads the saved choice; called from main() before runApp, so the first
  /// frame is already in the right language.
  Future<void> load() async {
    try {
      final saved = (await SharedPreferences.getInstance()).getString(_prefsKey);
      _chosen = supported.contains(saved) ? saved : null;
    } catch (_) {
      _chosen = null; // storage unavailable: the phone's language
    }
    notifyListeners();
  }

  /// The user's choice: applies at once, then is saved on the phone and, when
  /// signed in, on the account.
  Future<void> choose(String code, {String? uid}) async {
    if (!supported.contains(code)) return;
    final changed = code != this.code;
    _chosen = code;
    if (changed) notifyListeners();
    try {
      await (await SharedPreferences.getInstance()).setString(_prefsKey, code);
    } catch (_) {
      // applies for this session even when it cannot be saved
    }
    if (uid != null) await _saveOnAccount(uid, code);
  }

  /// At sign-in: a phone where the user never chose takes the account's
  /// language; otherwise the account takes the phone's, for the worker.
  Future<void> syncWithAccount(String uid, String? accountLanguage) async {
    if (_chosen == null && supported.contains(accountLanguage)) {
      await choose(accountLanguage!);
    } else if (accountLanguage != code) {
      await _saveOnAccount(uid, code);
    }
  }

  Future<void> _saveOnAccount(String uid, String code) async {
    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'language': code});
    } catch (e) {
      debugPrint('Language not saved on the account: $e');
    }
  }
}
