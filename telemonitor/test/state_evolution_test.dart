import 'package:flutter_test/flutter_test.dart';
import 'package:telemonitor/models/reading.dart';
import 'package:telemonitor/services/state_evolution.dart';

/// Same case as test_evolution_of_one_patient_for_the_service in
/// telemonitor-research/tests/test_state.py: the two implementations cut the
/// same windows.
void main() {
  final t0 = DateTime(2026, 7, 1, 8);
  final sbp = [130, 132, 128, 131, 129, 150, 154];
  final readings = [
    for (var i = 0; i < sbp.length; i++)
      Reading(id: 'r$i', timestamp: t0.add(Duration(hours: 12 * i)), sbp: sbp[i], dbp: sbp[i] - 50),
  ];

  test('current 24 h against the three days before, per channel', () {
    final ch = {for (final c in StateEvolution.of(readings)) c.channel: c};
    expect(ch.keys, unorderedEquals(['sbp', 'dbp']));
    expect(ch['sbp']!.current, 152);
    expect(ch['sbp']!.baseline, 130);
    expect(ch['dbp']!.change, 22);
  });

  test('a channel missing from either window is left out', () {
    final withGlucose = [...readings, Reading(timestamp: t0.add(const Duration(hours: 72)), glucose: 7.0)];
    expect(StateEvolution.of(withGlucose).map((c) => c.channel), isNot(contains('glucose')));
    expect(StateEvolution.of([readings.last]), isEmpty);
  });

  test('a correction replaces the reading it supersedes', () {
    final fixed = [...readings, Reading(id: 'fix', timestamp: readings.last.timestamp, sbp: 146, dbp: 96, supersedes: 'r6')];
    final ch = {for (final c in StateEvolution.of(fixed)) c.channel: c};
    expect(ch['sbp']!.current, 148);
  });
}
