import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/home_protocol.dart';

/// A single patient measurement entry — the shared record type used by
/// LogReadingScreen, PatientDashboard, HistoryScreen, and the clinician's
/// patient detail view.
///
/// Fields are nullable because a single entry can be BP-only or
/// glucose-only (see the "Measurement type" selector in
/// LogReadingScreen) — not every reading has all four values.
///
/// The record is append-only (thesis ch.4 §Data structure): a reading is
/// never edited or deleted; a correction is a new reading that names the one
/// it [supersedes]. [effective] gives the readings that stand.
class Reading {
  /// Firestore document id. Null for a reading not yet written.
  final String? id;

  /// When the reading was taken (measurement time). May be earlier than
  /// [recordedAt] when the patient enters a reading taken earlier.
  final DateTime timestamp;

  /// When the reading entered the system (server time); null for a reading
  /// not yet written or written before this field existed.
  final DateTime? recordedAt;

  /// Retained values: for a two-reading blood pressure session, the second.
  final int? sbp;
  final int? dbp;
  final double? glucose; // mmol/L
  final int? hr;
  final String context; // e.g. "Fasting", "After meal"...
  final String notes;

  /// Blood pressure readings in the session: 2 for the protocol pair (the
  /// first is kept below for audit, the second is retained), else 1.
  final int readingCount;
  final int? firstSbp;
  final int? firstDbp;
  final int? firstHr;

  /// Id of the reading this one corrects, if any.
  final String? supersedes;

  /// Measurement check of the worker (quality controls of the research
  /// pipeline): ok, out_of_range, unit_suspect, duplicate, carried_forward,
  /// extreme; null until checked.
  final String? qualityFlag;

  const Reading({
    this.id,
    required this.timestamp,
    this.recordedAt,
    this.sbp,
    this.dbp,
    this.glucose,
    this.hr,
    this.context = '',
    this.notes = '',
    this.readingCount = 1,
    this.firstSbp,
    this.firstDbp,
    this.firstHr,
    this.supersedes,
    this.qualityFlag,
  });

  bool get hasBP => sbp != null && dbp != null;
  bool get hasGlucose => glucose != null;
  bool get isCorrection => supersedes != null;

  /// Entered at least 15 minutes after it was taken.
  bool get isBackdated =>
      recordedAt != null && recordedAt!.difference(timestamp) > const Duration(minutes: 15);

  // Level of the home triage (HomeProtocol: 0 green, 1 yellow, 2 red), the
  // thresholds of a home deployment (thesis ch.4 §triage); null when the
  // channels of a condition were not measured on this reading. The glucose
  // threshold depends on the measurement context (before or after a meal).

  /// Haemodynamic level: worst of systolic, diastolic and pulse.
  int? get haemodynamicLevel => HomeProtocol.haemodynamic(sbp: sbp, dbp: dbp, hr: hr);

  /// Glycaemic level; null when glucose was not measured.
  int? get glycaemicLevel => HomeProtocol.glucose(glucose, context);

  /// Level of the reading: the worst of its channels.
  int? get level => HomeProtocol.ofReading(this);

  bool get isHaemodynamicAlert => (haemodynamicLevel ?? 0) >= HomeProtocol.yellow;
  bool get isGlycaemicAlert => (glycaemicLevel ?? 0) >= HomeProtocol.yellow;

  /// Yellow or red: above the home target, or out of range.
  bool get isAlert => (level ?? 0) >= HomeProtocol.yellow;

  /// The readings that stand: those no other reading supersedes. Order is
  /// kept.
  static List<Reading> effective(Iterable<Reading> readings) {
    final superseded = {for (final r in readings) if (r.supersedes != null) r.supersedes};
    return readings.where((r) => !superseded.contains(r.id)).toList();
  }

  // ---------------------------------------------------------------
  // Firestore serialization
  // ---------------------------------------------------------------

  factory Reading.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final ts = data['timestamp'];
    final rec = data['recordedAt'];

    return Reading(
      id: doc.id,
      // A document written locally while offline briefly has a null
      // server timestamp before it syncs — fall back to "now" so the
      // UI can render it immediately rather than crashing.
      timestamp: ts is Timestamp ? ts.toDate() : DateTime.now(),
      recordedAt: rec is Timestamp ? rec.toDate() : null,
      sbp: (data['sbp'] as num?)?.toInt(),
      dbp: (data['dbp'] as num?)?.toInt(),
      glucose: (data['glucose'] as num?)?.toDouble(),
      hr: (data['hr'] as num?)?.toInt(),
      context: data['context'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      readingCount: (data['readingCount'] as num?)?.toInt() ?? 1,
      firstSbp: (data['firstSbp'] as num?)?.toInt(),
      firstDbp: (data['firstDbp'] as num?)?.toInt(),
      firstHr: (data['firstHr'] as num?)?.toInt(),
      supersedes: data['supersedes'] as String?,
      qualityFlag: data['qualityFlag'] as String?,
    );
  }

  /// Fields of a new document. The record time is set by the server, so a
  /// reading queued offline keeps its measurement time and gets its true
  /// arrival time. Must match the readings rule of firestore.rules.
  Map<String, dynamic> toFirestore() => {
        'timestamp': Timestamp.fromDate(timestamp),
        'recordedAt': FieldValue.serverTimestamp(),
        'entryMode': 'manual',
        'sbp': sbp,
        'dbp': dbp,
        'glucose': glucose,
        'hr': hr,
        'context': context,
        'notes': notes,
        'readingCount': readingCount,
        if (readingCount == 2) ...{
          'firstSbp': firstSbp,
          'firstDbp': firstDbp,
          'firstHr': firstHr,
        },
        if (supersedes != null) 'supersedes': supersedes,
      };
}
