import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'app_messenger.dart';

/// Push notifications sent by the worker (thesis ch.4, Table "Notification
/// by level"): the device token is stored on the user's profile
/// (users/{uid}.fcmTokens) while signed in, and removed at sign-out so a
/// shared phone stops receiving the previous user's alerts.
///
/// Android and iOS only; elsewhere the app works without notifications.
class PushService {
  PushService._internal();
  static final PushService instance = PushService._internal();

  String? _uid;
  String? _token;
  StreamSubscription<String>? _refresh;
  StreamSubscription<RemoteMessage>? _foreground;

  static bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  Future<void> start(String uid) async {
    if (!supported || _uid == uid) return;
    _uid = uid;
    try {
      final m = FirebaseMessaging.instance;
      final settings = await m.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      await _save(await m.getToken());
      _refresh = m.onTokenRefresh.listen(_save);
      _foreground = FirebaseMessaging.onMessage.listen((msg) {
        final n = msg.notification;
        if (n == null) return;
        // the system shows a notification only when the app is in the background
        AppMessenger.show([n.title, n.body].whereType<String>().join(' — '));
      });
    } catch (e) {
      // no Google Play services, or offline: the app works without push
      debugPrint('Push notifications unavailable: $e');
    }
  }

  Future<void> _save(String? token) async {
    final uid = _uid;
    if (token == null || uid == null) return;
    _token = token;
    await _user(uid).update({'fcmTokens': FieldValue.arrayUnion([token])});
  }

  /// Call before signing out, while the user can still write their profile.
  Future<void> stop() async {
    final uid = _uid, token = _token;
    _uid = null;
    _token = null;
    await _refresh?.cancel();
    await _foreground?.cancel();
    if (uid == null || token == null) return;
    try {
      await _user(uid).update({'fcmTokens': FieldValue.arrayRemove([token])});
    } catch (e) {
      debugPrint('Could not remove the push token: $e');
    }
  }
}
