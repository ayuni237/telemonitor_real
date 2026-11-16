import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'app_messenger.dart';

/// What a notification opens when tapped: the conversation about a patient
/// (data sent by the worker with a message notification, worker.py).
class PushTarget {
  final String patientId;
  const PushTarget.messages(this.patientId);

  static PushTarget? fromData(Map<String, dynamic> data) {
    final id = data['patientId'];
    return data['open'] == 'messages' && id is String && id.isNotEmpty ? PushTarget.messages(id) : null;
  }
}

/// Push notifications sent by the worker (thesis ch.4, Table "Notification
/// by level"): the device token is stored on the user's profile
/// (users/{uid}.fcmTokens) while signed in, and removed at sign-out so a
/// shared phone stops receiving the previous user's alerts.
///
/// A tap on a message notification sets [opened]; the home screen of the
/// patient or the clinician opens the conversation and sets it back to null.
///
/// Android and iOS only; elsewhere the app works without notifications.
class PushService {
  PushService._internal();
  static final PushService instance = PushService._internal();

  String? _uid;
  String? _token;
  StreamSubscription<String>? _refresh;
  StreamSubscription<RemoteMessage>? _foreground;
  StreamSubscription<RemoteMessage>? _tapped;

  /// The conversation a notification asks to open, until the home screen does.
  final ValueNotifier<PushTarget?> opened = ValueNotifier(null);

  static bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  DocumentReference<Map<String, dynamic>> _user(String uid) =>
      FirebaseFirestore.instance.collection('users').doc(uid);

  Future<void> start(String uid) async {
    if (!supported || _uid == uid) return;
    _uid = uid;
    await _register();
  }

  /// Whether this phone lets the app show notifications; null when it
  /// cannot tell (no Firebase, web, desktop).
  Future<bool?> notificationsAllowed() async {
    if (!supported || Firebase.apps.isEmpty) return null;
    try {
      final s = await FirebaseMessaging.instance.getNotificationSettings();
      return s.authorizationStatus == AuthorizationStatus.authorized ||
          s.authorizationStatus == AuthorizationStatus.provisional;
    } catch (_) {
      return null;
    }
  }

  /// Asks again (profile screen) after the permission was refused; Android
  /// shows the question again unless the person blocked it for good, in
  /// which case only the phone's settings can allow it.
  Future<bool?> enable() async {
    if (_uid == null) return null;
    await _register();
    return notificationsAllowed();
  }

  Future<void> _register() async {
    try {
      final m = FirebaseMessaging.instance;
      final settings = await m.requestPermission();
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;
      await _refresh?.cancel();
      await _foreground?.cancel();
      await _tapped?.cancel();
      _refresh = m.onTokenRefresh.listen(_save);
      _foreground = FirebaseMessaging.onMessage.listen((msg) {
        final n = msg.notification;
        if (n == null) return;
        // the system shows a notification only when the app is in the background
        final target = PushTarget.fromData(msg.data);
        AppMessenger.show(
          [n.title, n.body].whereType<String>().join(' — '),
          action: target == null ? null : (label: 'Open', onPressed: () => opened.value = target),
        );
      });
      // a tap on a notification while the app was in the background, or one that launched it
      _tapped = FirebaseMessaging.onMessageOpenedApp.listen(_open);
      final initial = await m.getInitialMessage();
      if (initial != null) _open(initial);
      // last: offline, the token write waits for the connection
      await _save(await m.getToken());
    } catch (e) {
      // no Google Play services, or offline: the app works without push
      debugPrint('Push notifications unavailable: $e');
    }
  }

  void _open(RemoteMessage msg) {
    final target = PushTarget.fromData(msg.data);
    if (target != null) opened.value = target;
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
    opened.value = null;
    await _refresh?.cancel();
    await _foreground?.cancel();
    await _tapped?.cancel();
    if (uid == null || token == null) return;
    try {
      await _user(uid).update({'fcmTokens': FieldValue.arrayRemove([token])});
    } catch (e) {
      debugPrint('Could not remove the push token: $e');
    }
  }
}
