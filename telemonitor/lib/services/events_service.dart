import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_user.dart';
import '../models/clinical_event.dart';
import '../models/reading.dart';
import '../models/risk_assessment.dart';
import 'app_messenger.dart';
import 'auth_service.dart';
import 'clinical_levels.dart';
import 'home_protocol.dart';
import 'risk_assessment_service.dart';

/// The event record (thesis ch.4 §Data structure) and the functions that
/// fill it from the applications; the local worker (telemonitor-research,
/// serve/worker.py) runs the same functions on the server side:
///  * escalation: the patient's phone writes a rule event with the reading
///    that reaches yellow or red under the home triage (ReadingsRepository),
///    a rule event when a verification profile ends off target, and a model
///    event when the online model raises the tier;
///  * non-transmission sweep: the clinician's application raises an event
///    for a patient silent for longer than their checkup period;
///  * verdict: the clinician closes the event.
/// Event ids are derived from what raised them, so a repeated trigger
/// cannot create a second event: the rules refuse to overwrite one.
class EventsService {
  EventsService._internal();
  static final EventsService instance = EventsService._internal();

  // resolved on use, so the service can be built where Firebase is not initialised (screen tests)
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> events(String patientId) =>
      _db.collection('users').doc(patientId).collection('events');

  static Map<String, dynamic> triggerOf(Reading r) => {
        'sbp': r.sbp,
        'dbp': r.dbp,
        'hr': r.hr,
        'glucose': r.glucose,
        'context': r.context,
        'measuredAt': Timestamp.fromDate(r.timestamp),
      };

  /// Rule escalation for a new reading, or null when its level stays below
  /// yellow. Written in the same batch as the reading.
  static ({String id, Map<String, dynamic> data})? ruleEvent(
      {required String patientId, required String? clinicianId, required String readingId, required Reading r}) {
    final tier = RiskAssessmentService.tierOfLevel(r.level);
    if (tier == RiskTier.green) return null;
    return (
      id: 'rule_$readingId',
      data: ClinicalEvent.newData(
        patientId: patientId,
        clinicianId: clinicianId,
        source: TriggerSource.rule,
        tier: tier,
        trigger: triggerOf(r),
        thresholdVersion: HomeProtocol.version,
        readingId: readingId,
      ),
    );
  }

  final Set<String> _profilesRaised = {};

  /// Verification profile ended off target (Table "tab:thresholds":
  /// teleconsultation): a red rule event, once per profile. Called by the
  /// patient's repository at every change of the readings.
  void raiseProfileEvents(List<Reading> readings) {
    final me = AuthService.instance.currentProfile;
    if (me == null) return;
    for (final p in VerificationProfile.active(readings, DateTime.now())) {
      if (p.status != ProfileStatus.complete || p.offTarget != true) continue;
      final kind = p.kind == ProfileKind.bloodPressure ? 'bp_7d' : 'glucose_6pt';
      final id = 'profile_${kind}_${p.start.millisecondsSinceEpoch}';
      if (!_profilesRaised.add(id)) continue;
      final trigger = <String, dynamic>{
        'profile': kind,
        'readings': p.readings,
        'startedAt': Timestamp.fromDate(p.start),
        if (p.kind == ProfileKind.bloodPressure) ...{'meanSbp': p.meanSbp, 'meanDbp': p.meanDbp, 'days': p.days},
        if (p.kind == ProfileKind.glucose) ...{
          'meanBeforeMeal': p.meanBeforeMeal,
          'meanAfterMeal': p.meanAfterMeal,
        },
      };
      // not awaited: offline, the write waits in the local cache; an existing
      // event (raised from another device) cannot be rewritten and is left as is
      events(me.uid)
          .doc(id)
          .set(ClinicalEvent.newData(
            patientId: me.uid,
            clinicianId: me.assignedClinicianId,
            source: TriggerSource.rule,
            tier: RiskTier.red,
            trigger: trigger,
            thresholdVersion: HomeProtocol.version,
          ))
          .catchError((Object _) {});
    }
  }

  /// Model escalation: the online model raised the tier above the rule's,
  /// to yellow or red. One event per assessed latest reading.
  Future<void> raiseModelEvent(Reading latest, RiskAssessment a) async {
    final me = AuthService.instance.currentProfile;
    if (me == null || latest.id == null) return;
    if (a.source != RiskSource.online || a.tier == RiskTier.green || a.tier.index <= a.ruleTier.index) return;
    final raising = a.conditions.values.where((c) => c.tier == a.tier).toList();
    try {
      await events(me.uid).doc('model_${latest.id}').set(ClinicalEvent.newData(
            patientId: me.uid,
            clinicianId: me.assignedClinicianId,
            source: TriggerSource.model,
            tier: a.tier,
            trigger: triggerOf(latest),
            thresholdVersion: ClinicalLevels.version,
            score: raising.isEmpty ? null : raising.map((c) => c.alertProbability).reduce((x, y) => x > y ? x : y),
            readingId: latest.id,
            modelVersion: a.conditions.values.map((c) => c.model).join(', '),
          ));
    } on FirebaseException {
      // already raised for this reading (an existing event cannot be rewritten)
    }
  }

  /// Non-transmission sweep for one patient, run by the clinician's
  /// application: one event per silence, keyed by the last reading.
  Future<void> raiseNonTransmission(AppUser patient, Reading last, int checkupPeriodDays) async {
    final me = AuthService.instance.currentProfile;
    if (me == null || last.id == null) return;
    final ref = events(patient.uid).doc('nontx_${last.id}');
    try {
      if ((await ref.get()).exists) return;
      await ref.set(ClinicalEvent.newData(
        patientId: patient.uid,
        clinicianId: me.uid,
        source: TriggerSource.nonTransmission,
        tier: RiskTier.yellow,
        trigger: {'lastReadingAt': Timestamp.fromDate(last.timestamp), 'checkupPeriodDays': checkupPeriodDays},
        thresholdVersion: HomeProtocol.version,
        readingId: last.id,
      ));
    } on FirebaseException {
      // raised meanwhile, or offline: the next sweep retries
    }
  }

  /// Events of other clinicians' patients escalated to me by the queue-age
  /// sweep (I am their named alternate).
  Stream<List<ClinicalEvent>> watchEscalatedToMe() {
    final me = AuthService.instance.currentProfile;
    if (me == null) return Stream.value(const []);
    return _db
        .collectionGroup('events')
        .where('escalatedTo', isEqualTo: me.uid)
        .snapshots()
        .map((s) => s.docs.map(ClinicalEvent.fromFirestore).toList());
  }

  /// Names a colleague as alternate for the queue-age escalation, from the
  /// enrolment code they give; null removes the alternate. Returns the
  /// colleague's display name.
  Future<String?> setAlternate(String? code) async {
    final me = AuthService.instance.currentProfile;
    if (me == null) throw StateError('No signed-in clinician.');
    final users = _db.collection('users');
    if (code == null) {
      await users.doc(me.uid).update(
          {'alternateClinicianId': FieldValue.delete(), 'alternateClinicianName': FieldValue.delete()});
      await AuthService.instance.fetchCurrentUserProfile();
      return null;
    }
    final found = await AuthService.instance.lookupClinicianCode(code);
    if (found == null) throw const FormatException('No clinician has this code.');
    if (found.clinicianId == me.uid) throw const FormatException('This is your own code.');
    await users.doc(me.uid).update(
        {'alternateClinicianId': found.clinicianId, 'alternateClinicianName': found.clinicianName});
    await AuthService.instance.fetchCurrentUserProfile();
    return found.clinicianName;
  }

  /// Every event of a patient, newest first.
  Stream<List<ClinicalEvent>> watch(String patientId, {int limit = 100}) => events(patientId)
      .orderBy('tsTriggered', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(ClinicalEvent.fromFirestore).toList());

  /// Closes an event with the clinician's verdict. Returns at once: offline,
  /// the verdict waits in the local cache (the event already shows as closed)
  /// and is sent on reconnection; a refusal by the rules is reported then.
  void recordVerdict(ClinicalEvent e,
      {required Verdict verdict, required ClinicalAction action, String comment = ''}) {
    final me = AuthService.instance.currentProfile;
    if (me == null) throw StateError('No signed-in clinician.');
    events(e.patientId)
        .doc(e.id)
        .update(ClinicalEvent.verdictData(clinicianId: me.uid, verdict: verdict, action: action, comment: comment))
        .catchError((Object err) => AppMessenger.show('A verdict was not saved: $err', error: true));
  }

  /// Checkup period of a patient, set by their clinician.
  Future<void> setCheckupPeriod(String patientId, int days) =>
      _db.collection('users').doc(patientId).update({'checkupPeriodDays': days});
}
