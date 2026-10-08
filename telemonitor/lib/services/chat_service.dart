import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/message.dart';
import 'auth_service.dart';

/// Reads, writes and marks-as-read the message thread for a patient.
class ChatService {
  ChatService._internal();
  static final ChatService instance = ChatService._internal();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Message ids a read-receipt write has already been issued for.
  /// Prevents the thread view — which rebuilds on every snapshot —
  /// from issuing the same write repeatedly before the first one has
  /// round-tripped.
  final Set<String> _pendingReads = {};

  CollectionReference<Map<String, dynamic>> _thread(String patientId) =>
      _db.collection('users').doc(patientId).collection('messages');

  /// Live message thread, oldest first.
  Stream<List<Message>> watchMessages(String patientId) {
    return _thread(patientId)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map(Message.fromFirestore).toList());
  }

  /// Sends a message as the currently signed-in user. The sender's
  /// identity comes from their authenticated profile, never from a
  /// parameter.
  Future<void> send({
    required String patientId,
    required String text,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final profile = AuthService.instance.currentProfile;
    if (profile == null) {
      throw StateError('No signed-in profile — cannot send a message.');
    }

    await _thread(patientId).add(
      Message(
        senderId: profile.uid,
        senderRole:
            profile.role == UserRole.clinician ? 'clinician' : 'patient',
        senderName: profile.displayName,
        text: trimmed,
        timestamp: DateTime.now(),
      ).toFirestore(),
    );
  }

  /// Marks every message in [messages] that was sent by the OTHER party
  /// and has not yet been read.
  ///
  /// Batched so that opening a thread with twenty unread messages costs
  /// one write round-trip rather than twenty.
  Future<void> markRead(String patientId, List<Message> messages) async {
    final myUid = AuthService.instance.currentProfile?.uid;
    if (myUid == null) return;

    final toMark = messages.where((m) =>
        m.id != null &&
        m.senderId != myUid &&
        !m.isRead &&
        !_pendingReads.contains(m.id));

    if (toMark.isEmpty) return;

    final batch = _db.batch();
    for (final m in toMark) {
      _pendingReads.add(m.id!);
      batch.update(_thread(patientId).doc(m.id), {
        'readAt': FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();
    } catch (_) {
      // Failed receipts are not worth surfacing to the user. Clear the
      // pending marks so the next rebuild retries them.
      for (final m in toMark) {
        _pendingReads.remove(m.id);
      }
    }
  }
}
