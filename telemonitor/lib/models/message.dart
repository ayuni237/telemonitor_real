import 'package:cloud_firestore/cloud_firestore.dart';

/// One chat message between a patient and their care team.
///
/// Stored at users/{patientId}/messages/{messageId} — under the patient
/// the conversation is about.
class Message {
  final String? id;
  final String senderId;

  /// 'patient' or 'clinician'.
  final String senderRole;

  /// Display name captured at send time, so an old message still shows
  /// who wrote it even if that person's profile later changes.
  final String senderName;

  final String text;
  final DateTime timestamp;

  /// When the RECIPIENT opened the thread and saw this message. Null
  /// until then. Drives the single-tick / double-tick indicator.
  ///
  /// This is the only field on a message that may ever change after it
  /// is sent, and only once — see the security rules.
  final DateTime? readAt;

  const Message({
    this.id,
    required this.senderId,
    required this.senderRole,
    required this.senderName,
    required this.text,
    required this.timestamp,
    this.readAt,
  });

  bool get isFromClinician => senderRole == 'clinician';
  bool get isRead => readAt != null;

  factory Message.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final ts = data['timestamp'];
    final read = data['readAt'];
    return Message(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      senderRole: data['senderRole'] as String? ?? 'patient',
      senderName: data['senderName'] as String? ?? '',
      text: data['text'] as String? ?? '',
      // A message sent offline has no server timestamp until it syncs.
      timestamp: ts is Timestamp ? ts.toDate() : DateTime.now(),
      readAt: read is Timestamp ? read.toDate() : null,
    );
  }

  /// `readAt` is deliberately NOT written at creation. The rules reject a
  /// new message that already carries it, so a sender cannot pre-mark
  /// their own message as read.
  Map<String, dynamic> toFirestore() => {
        'senderId': senderId,
        'senderRole': senderRole,
        'senderName': senderName,
        'text': text,
        'timestamp': Timestamp.fromDate(timestamp),
      };
}
