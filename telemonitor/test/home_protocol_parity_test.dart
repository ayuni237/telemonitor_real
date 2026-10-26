import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:telemonitor/models/reading.dart';
import 'package:telemonitor/services/home_protocol.dart';

/// The home triage and the verification profile against the Python reference
/// (telemonitor-research/src/telemonitor/home_protocol.py). Fixture written by
/// scripts/07_app_parity_fixture.py.
void main() {
  final fx = jsonDecode(File('test/fixtures/home_parity.json').readAsStringSync()) as Map<String, dynamic>;

  test('same version as the Python table', () => expect(HomeProtocol.version, fx['version']));

  void channel(String name, int? Function(num?) f) {
    test('every $name boundary', () {
      final values = (fx[name]['values'] as List).cast<num>();
      final levels = fx[name]['levels'] as List;
      for (var i = 0; i < values.length; i++) {
        expect(f(values[i]), levels[i], reason: '$name ${values[i]}');
      }
    });
  }

  channel('sbp', HomeProtocol.sbp);
  channel('dbp', HomeProtocol.dbp);
  channel('pulse', HomeProtocol.pulse);
  channel('glucose_before_meal', HomeProtocol.glucoseBeforeMeal);
  channel('glucose_after_meal', HomeProtocol.glucoseAfterMeal);

  test('readings with every context', () {
    for (final c in (fx['readings'] as List).cast<Map<String, dynamic>>()) {
      final args = (sbp: c['sbp'] as num?, dbp: c['dbp'] as num?, hr: c['hr'] as num?, glu: c['glucose'] as num?);
      expect(HomeProtocol.haemodynamic(sbp: args.sbp, dbp: args.dbp, hr: args.hr), c['haemodynamic'], reason: '$c');
      expect(HomeProtocol.glucose(args.glu, c['context'] as String), c['glycaemic'], reason: '$c');
      expect(
          HomeProtocol.level(
              sbp: args.sbp, dbp: args.dbp, hr: args.hr, glucoseMmol: args.glu, context: c['context'] as String),
          c['level'],
          reason: '$c');
    }
  });

  test('verification profiles', () {
    final t0 = DateTime(2026, 10, 1, 8);
    const status = {'in_progress': ProfileStatus.inProgress, 'complete': ProfileStatus.complete,
      'incomplete': ProfileStatus.incomplete};
    var i = 0;
    for (final p in (fx['profiles'] as List).cast<Map<String, dynamic>>()) {
      final readings = [
        for (final r in (p['input'] as List).cast<Map<String, dynamic>>())
          Reading(
            id: 'r${i++}',
            timestamp: t0.add(Duration(hours: r['hours'] as int)),
            sbp: r['sbp'] as int?,
            dbp: r['dbp'] as int?,
            glucose: (r['glucose'] as num?)?.toDouble(),
            context: r['context'] as String? ?? '',
          ),
      ];
      final now = t0.add(Duration(hours: p['now_hours'] as int));
      final res = p['kind'] == 'bp'
          ? VerificationProfile.bloodPressure(t0, readings, now)
          : VerificationProfile.glucose(t0, readings, now);
      expect(res.status, status[p['status']], reason: '$p');
      expect(res.offTarget, p['off_target'], reason: '$p');
      expect(res.readings, p['readings'], reason: '$p');
      if (p['kind'] == 'bp') {
        expect(res.meanSbp, p['mean_sbp'], reason: '$p');
        expect(res.days, p['days'], reason: '$p');
      } else {
        expect(res.meanAfterMeal, p['mean_after_meal'], reason: '$p');
      }
    }
  });

  test('the latest yellow reading starts a profile; readings inside it do not restart it', () {
    final t0 = DateTime(2026, 10, 1, 8);
    final rs = [
      Reading(id: 'a', timestamp: t0, sbp: 128, dbp: 80),
      Reading(id: 'y1', timestamp: t0.add(const Duration(hours: 12)), sbp: 150, dbp: 92),   // yellow: starts
      Reading(id: 'y2', timestamp: t0.add(const Duration(hours: 24)), sbp: 152, dbp: 94),   // inside: no restart
    ];
    final active = VerificationProfile.active(rs, t0.add(const Duration(hours: 30)));
    expect(active, hasLength(1));
    expect(active.single.kind, ProfileKind.bloodPressure);
    expect(active.single.start, t0.add(const Duration(hours: 12)));
    expect(active.single.status, ProfileStatus.inProgress);
    expect(active.single.readings, 1);
  });
}
