import 'package:cloud_firestore/cloud_firestore.dart';

import 'risk_assessment.dart';

/// What raised an event (thesis ch.4, Table "Content of a queue row"): a
/// guideline threshold crossing, the risk model, or a patient who stopped
/// sending readings. Shown on every row, because they are not equally strong
/// evidence.
enum TriggerSource { rule, model, nonTransmission }

/// The clinician's verdict, the clinically adjudicated label (ch.4 §Data
/// structure).
enum Verdict { confirmed, notSignificant, uncertain }

/// The action taken on an event.
enum ClinicalAction { none, advice, treatmentChange, consultation, referral }

const _sourceCodes = {
  TriggerSource.rule: 'rule',
  TriggerSource.model: 'model',
  TriggerSource.nonTransmission: 'non_transmission',
};
const _verdictCodes = {
  Verdict.confirmed: 'confirmed',
  Verdict.notSignificant: 'not_significant',
  Verdict.uncertain: 'uncertain',
};
const _actionCodes = {
  ClinicalAction.none: 'none',
  ClinicalAction.advice: 'advice',
  ClinicalAction.treatmentChange: 'treatment_change',
  ClinicalAction.consultation: 'consultation',
  ClinicalAction.referral: 'referral',
};

T? _decode<T>(Map<T, String> codes, Object? code) {
  for (final e in codes.entries) {
    if (e.value == code) return e.key;
  }
  return null;
}

extension TriggerSourceCode on TriggerSource {
  String get code => _sourceCodes[this]!;
  String get label => switch (this) {
        TriggerSource.rule => 'Guideline rule',
        TriggerSource.model => 'Risk model',
        TriggerSource.nonTransmission => 'No readings received',
      };
}

extension VerdictCode on Verdict {
  String get code => _verdictCodes[this]!;
  String get label => switch (this) {
        Verdict.confirmed => 'True alert',
        Verdict.notSignificant => 'False alert',
        Verdict.uncertain => 'Uncertain',
      };
}

extension ClinicalActionCode on ClinicalAction {
  String get code => _actionCodes[this]!;
  String get label => switch (this) {
        ClinicalAction.none => 'No action',
        ClinicalAction.advice => 'Advice',
        ClinicalAction.treatmentChange => 'Dose or drug change',
        ClinicalAction.consultation => 'Consultation',
        ClinicalAction.referral => 'Referral',
      };
}

/// One record of the event table (ch.4, Figure "three-table data model"):
/// an alert and, once reviewed, the clinician's response. Stored at
/// users/{patientId}/events/{eventId}; never deleted, closed once.
class ClinicalEvent {
  final String id;
  final String patientId;
  final String? clinicianId;
  final DateTime triggeredAt;
  final TriggerSource source;
  final RiskTier tier;

  /// Calibrated alert probability, for a model trigger only.
  final double? score;

  /// The reading that raised the event (rule and model triggers).
  final String? readingId;

  /// Snapshot of the triggering values: sbp, dbp, hr, glucose, context; for
  /// a non-transmission event, the time of the last reading.
  final Map<String, dynamic> trigger;
  final String thresholdVersion;
  final String? modelVersion;

  final bool isOpen;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final Verdict? verdict;
  final ClinicalAction? action;
  final String comment;

  const ClinicalEvent({
    required this.id,
    required this.patientId,
    required this.clinicianId,
    required this.triggeredAt,
    required this.source,
    required this.tier,
    required this.trigger,
    required this.thresholdVersion,
    this.score,
    this.readingId,
    this.modelVersion,
    this.isOpen = true,
    this.reviewedAt,
    this.reviewedBy,
    this.verdict,
    this.action,
    this.comment = '',
  });

  factory ClinicalEvent.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>? ?? {};
    final ts = d['tsTriggered'];
    final rv = d['tsReviewed'];
    return ClinicalEvent(
      id: doc.id,
      patientId: d['patientId'] as String? ?? '',
      clinicianId: d['clinicianId'] as String?,
      // null while a write made offline waits for its server timestamp
      triggeredAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      source: _decode(_sourceCodes, d['triggerSource']) ?? TriggerSource.rule,
      tier: (d['tier'] as String? ?? 'yellow').toRiskTier(),
      score: (d['score'] as num?)?.toDouble(),
      readingId: d['readingId'] as String?,
      trigger: Map<String, dynamic>.from(d['trigger'] as Map? ?? const {}),
      thresholdVersion: d['thresholdVersion'] as String? ?? '',
      modelVersion: d['modelVersion'] as String?,
      isOpen: d['status'] != 'closed',
      reviewedAt: rv is Timestamp ? rv.toDate() : null,
      reviewedBy: d['reviewedBy'] as String?,
      verdict: _decode(_verdictCodes, d['verdict']),
      action: _decode(_actionCodes, d['action']),
      comment: d['comment'] as String? ?? '',
    );
  }

  /// Fields of a new, open event. Must match the events rule of
  /// firestore.rules.
  static Map<String, dynamic> newData({
    required String patientId,
    required String? clinicianId,
    required TriggerSource source,
    required RiskTier tier,
    required Map<String, dynamic> trigger,
    required String thresholdVersion,
    double? score,
    String? readingId,
    String? modelVersion,
  }) =>
      {
        'patientId': patientId,
        'clinicianId': clinicianId,
        'tsTriggered': FieldValue.serverTimestamp(),
        'triggerSource': source.code,
        'tier': tier.name,
        'score': score,
        'readingId': readingId,
        'trigger': trigger,
        'thresholdVersion': thresholdVersion,
        'modelVersion': modelVersion,
        'status': 'open',
      };

  /// Fields written by the verdict, which closes the event.
  static Map<String, dynamic> verdictData({
    required String clinicianId,
    required Verdict verdict,
    required ClinicalAction action,
    String comment = '',
  }) =>
      {
        'status': 'closed',
        'tsReviewed': FieldValue.serverTimestamp(),
        'reviewedBy': clinicianId,
        'verdict': verdict.code,
        'action': action.code,
        'comment': comment.trim(),
      };
}

/// Queue order (ch.4 §Clinician dashboard): priority first, red before
/// yellow, then age, the oldest unreviewed event first.
int compareQueue(ClinicalEvent a, ClinicalEvent b) {
  final byTier = b.tier.index.compareTo(a.tier.index);
  return byTier != 0 ? byTier : a.triggeredAt.compareTo(b.triggeredAt);
}
