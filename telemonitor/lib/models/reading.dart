import 'package:cloud_firestore/cloud_firestore.dart';

/// A single patient measurement entry — the shared record type used by
/// LogReadingScreen, PatientDashboard, HistoryScreen, and (now) the
/// clinician's patient detail view.
///
/// Fields are nullable because a single entry can be BP-only or
/// glucose-only (see the "Measurement type" selector in
/// LogReadingScreen) — not every reading has all four values.
class Reading {
  /// Firestore document id. Null for a reading not yet written.
  final String? id;

  final DateTime timestamp;
  final int? sbp;
  final int? dbp;
  final double? glucose; // mmol/L
  final int? hr;
  final String context; // e.g. "Fasting", "After meal"...
  final String notes;

  const Reading({
    this.id,
    required this.timestamp,
    this.sbp,
    this.dbp,
    this.glucose,
    this.hr,
    this.context = '',
    this.notes = '',
  });

  bool get hasBP => sbp != null && dbp != null;
  bool get hasGlucose => glucose != null;

  /// Clinical BP status bucket. Null if no BP on this reading.
  String? get bpStatus {
    if (!hasBP) return null;
    if (sbp! > 180 || dbp! > 120) return 'critical';
    if (sbp! >= 140 || dbp! >= 90) return 'stage2';
    if (sbp! >= 130 || dbp! >= 80) return 'stage1';
    if (sbp! >= 120 && dbp! < 80) return 'elevated';
    return 'normal';
  }

  /// Glucose status bucket. Null if no glucose on this reading.
  String? get glucoseStatus {
    if (!hasGlucose) return null;
    if (glucose! > 11.1) return 'critical';
    if (glucose! > 7.0) return 'high';
    if (glucose! < 3.9) return 'low';
    return 'normal';
  }

  // ---------------------------------------------------------------
  // Firestore serialization
  // ---------------------------------------------------------------

  factory Reading.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final ts = data['timestamp'];

    return Reading(
      id: doc.id,
      // A document written locally while offline briefly has a null
      // server timestamp before it syncs — fall back to "now" so the
      // UI can render it immediately rather than crashing.
      timestamp: ts is Timestamp ? ts.toDate() : DateTime.now(),
      sbp: (data['sbp'] as num?)?.toInt(),
      dbp: (data['dbp'] as num?)?.toInt(),
      glucose: (data['glucose'] as num?)?.toDouble(),
      hr: (data['hr'] as num?)?.toInt(),
      context: data['context'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toFirestore() => {
        'timestamp': Timestamp.fromDate(timestamp),
        'sbp': sbp,
        'dbp': dbp,
        'glucose': glucose,
        'hr': hr,
        'context': context,
        'notes': notes,
      };
}
