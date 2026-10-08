import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

/// Lightweight online presence, built on a heartbeat.
///
/// While active, the signed-in user's profile gets a `lastSeenAt`
/// timestamp refreshed every [_interval]. Another user is considered
/// online if their `lastSeenAt` is younger than [_onlineWindow].
///
/// KNOWN LIMITATION: if a user force-closes the app, no "going offline"
/// signal is sent, so they continue to show online until their last
/// heartbeat ages past the window — up to about ninety seconds. True
/// presence requires the Firebase Realtime Database `onDisconnect`
/// mechanism, which is a second database; the heartbeat is the simpler
/// approach and accurate enough for a chat indicator.
class PresenceService {
  PresenceService._internal();
  static final PresenceService instance = PresenceService._internal();

  static const Duration _interval = Duration(seconds: 60);
  static const Duration _onlineWindow = Duration(seconds: 90);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Timer? _timer;

  /// Reference count, so that two screens both calling start() do not
  /// cause the first stop() to cut the heartbeat for the other.
  int _holders = 0;

  void start() {
    _holders++;
    if (_timer != null) return;
    _beat();
    _timer = Timer.periodic(_interval, (_) => _beat());
  }

  void stop() {
    if (_holders > 0) _holders--;
    if (_holders > 0) return;
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _beat() async {
    final uid = AuthService.instance.currentFirebaseUser?.uid;
    if (uid == null) return;
    try {
      // lastSeenAt is not one of the protected profile fields, so the
      // existing self-update rule already permits this write.
      await _db.collection('users').doc(uid).update({
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // A missed heartbeat only means briefly appearing offline.
    }
  }

  /// Live last-seen time for another user. Null if never seen.
  Stream<DateTime?> watchLastSeen(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((doc) {
      final v = doc.data()?['lastSeenAt'];
      return v is Timestamp ? v.toDate() : null;
    });
  }

  static bool isOnline(DateTime? lastSeen) {
    if (lastSeen == null) return false;
    return DateTime.now().difference(lastSeen) < _onlineWindow;
  }

  /// Human-readable status line.
  static String describe(DateTime? lastSeen) {
    if (lastSeen == null) return 'Offline';
    if (isOnline(lastSeen)) return 'Online';
    final d = DateTime.now().difference(lastSeen);
    if (d.inMinutes < 60) return 'Last seen ${d.inMinutes} min ago';
    if (d.inHours < 24) return 'Last seen ${d.inHours} h ago';
    if (d.inDays == 1) return 'Last seen yesterday';
    return 'Last seen ${d.inDays} days ago';
  }
}
