import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemonitor/models/clinical_event.dart';
import 'package:telemonitor/models/reading.dart';
import 'package:telemonitor/models/risk_assessment.dart';
import 'package:telemonitor/services/events_service.dart';

/// Keys listed in a `hasOnly([...])` or a `return [...]` of firestore.rules
/// after [marker], so the app's writes and the rules cannot drift apart.
Set<String> rulesKeys(String marker) {
  final rules = File('firestore.rules').readAsStringSync();
  final from = rules.indexOf(marker);
  expect(from, isNonNegative, reason: '$marker not found in firestore.rules');
  final list = RegExp(r'\[([^\]]*)\]').firstMatch(rules.substring(from))!.group(1)!;
  return RegExp(r"'([^']+)'").allMatches(list).map((m) => m.group(1)!).toSet();
}

Reading r(String id, {int? sbp, int? dbp, double? glucose, String? supersedes}) => Reading(
      id: id,
      timestamp: DateTime(2026, 10, 1, 8),
      sbp: sbp,
      dbp: dbp,
      glucose: glucose,
      supersedes: supersedes,
    );

void main() {
  group('append-only record', () {
    test('a correction hides the reading it supersedes, and only that one', () {
      final all = [r('c', sbp: 150, dbp: 90, supersedes: 'a'), r('a', sbp: 105, dbp: 90), r('b', glucose: 6)];
      expect(Reading.effective(all).map((x) => x.id), ['c', 'b']);
    });

    test('a chain of corrections leaves the last one', () {
      final all = [r('c', sbp: 1, dbp: 1, supersedes: 'b'), r('b', sbp: 1, dbp: 1, supersedes: 'a'), r('a')];
      expect(Reading.effective(all).map((x) => x.id), ['c']);
    });

    test('written fields are the ones the readings rule accepts', () {
      final pair = Reading(
        timestamp: DateTime(2026, 10, 1, 8),
        sbp: 150,
        dbp: 92,
        hr: 70,
        readingCount: 2,
        firstSbp: 156,
        firstDbp: 95,
        firstHr: 72,
        supersedes: 'a',
      ).toFirestore();
      expect(pair.keys.toSet().difference(rulesKeys('function isValidReading')), isEmpty);
      expect(pair['recordedAt'], isA<FieldValue>());
      expect(pair['entryMode'], 'manual');
      final single = Reading(timestamp: DateTime(2026, 10, 1), glucose: 5.5).toFirestore();
      expect(single.containsKey('firstSbp'), isFalse);
      expect(single.containsKey('supersedes'), isFalse);
    });

    test('a reading entered more than 15 minutes after it was taken is marked', () {
      final t = DateTime(2026, 10, 1, 8);
      expect(Reading(timestamp: t, recordedAt: t.add(const Duration(minutes: 10))).isBackdated, isFalse);
      expect(Reading(timestamp: t, recordedAt: t.add(const Duration(hours: 3))).isBackdated, isTrue);
      expect(Reading(timestamp: t).isBackdated, isFalse);
    });
  });

  group('events', () {
    test('a rule event is raised at yellow or red only, keyed by the reading', () {
      ({String id, Map<String, dynamic> data})? ev(Reading x) =>
          EventsService.ruleEvent(patientId: 'p', clinicianId: 'c', readingId: 'r1', r: x);
      expect(ev(r('x', sbp: 128, dbp: 80)), isNull); // within the home target: green
      final yellow = ev(r('x', sbp: 150, dbp: 90))!;
      expect(yellow.id, 'rule_r1');
      expect(yellow.data['tier'], 'yellow');
      expect(yellow.data['triggerSource'], 'rule');
      expect(yellow.data['status'], 'open');
      expect(ev(r('x', glucose: 2.5))!.data['tier'], 'red'); // < 4 mmol/L
      expect(yellow.data['thresholdVersion'], 'home-2026-10-22');
    });

    test('event fields are the ones the events rules accept', () {
      final data = ClinicalEvent.newData(
        patientId: 'p',
        clinicianId: 'c',
        source: TriggerSource.model,
        tier: RiskTier.red,
        trigger: const {},
        thresholdVersion: 'v',
        score: 0.4,
        readingId: 'r',
        modelVersion: 'm',
      );
      expect(data.keys.toSet(), rulesKeys('function eventKeys'));
      final verdict = ClinicalEvent.verdictData(
          clinicianId: 'c', verdict: Verdict.notSignificant, action: ClinicalAction.treatmentChange);
      expect(verdict.keys.toSet(), rulesKeys('function isVerdict'));
      expect(verdict['verdict'], 'not_significant');
      expect(verdict['action'], 'treatment_change');
    });

    test('queue order: red before yellow, then the oldest first', () {
      ClinicalEvent e(String id, RiskTier t, int day) => ClinicalEvent(
            id: id,
            patientId: 'p',
            clinicianId: 'c',
            triggeredAt: DateTime(2026, 10, day),
            source: TriggerSource.rule,
            tier: t,
            trigger: const {},
            thresholdVersion: 'v',
          );
      final q = [e('y-old', RiskTier.yellow, 1), e('r-new', RiskTier.red, 5), e('r-old', RiskTier.red, 2),
        e('y-new', RiskTier.yellow, 4)]
        ..sort(compareQueue);
      expect(q.map((x) => x.id), ['r-old', 'r-new', 'y-old', 'y-new']);
    });
  });
}
