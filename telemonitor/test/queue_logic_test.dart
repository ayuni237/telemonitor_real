import 'package:flutter_test/flutter_test.dart';
import 'package:telemonitor/models/reading.dart';
import 'package:telemonitor/services/queue_logic.dart';

final now = DateTime(2026, 10, 20, 12);

List<Reading> sbpSeries(List<(int, int)> daysAgoAndSbp) => [
      for (final (d, v) in daysAgoAndSbp)
        Reading(timestamp: now.subtract(Duration(days: d)), sbp: v, dbp: 80),
    ];

void main() {
  test('trend direction from the least-squares change over fourteen days', () {
    expect(systolicTrend(sbpSeries([(12, 130), (6, 140), (1, 150)]), now: now), TrendDirection.rising);
    expect(systolicTrend(sbpSeries([(12, 150), (6, 140), (1, 130)]), now: now), TrendDirection.falling);
    expect(systolicTrend(sbpSeries([(12, 140), (6, 141), (1, 139)]), now: now), TrendDirection.stable);
  });

  test('trend is unknown with too few readings or too short a span', () {
    expect(systolicTrend(sbpSeries([(3, 130), (1, 160)]), now: now), TrendDirection.unknown);
    expect(systolicTrend(sbpSeries([(1, 130), (1, 150), (0, 170)]), now: now), TrendDirection.unknown);
    // readings older than the window are left out
    expect(systolicTrend(sbpSeries([(30, 100), (20, 110), (1, 150)]), now: now), TrendDirection.unknown);
  });

  test('glucose trend uses its own stable band', () {
    final g = [
      for (final (d, v) in [(10, 6.0), (5, 6.3), (1, 6.4)])
        Reading(timestamp: now.subtract(Duration(days: d)), glucose: v),
    ];
    expect(glucoseTrend(g, now: now), TrendDirection.stable);
  });

  test('five-year age bands and pseudonyms', () {
    expect(ageBand(58), '55–59 yrs');
    expect(ageBand(60), '60–64 yrs');
    expect(ageBand(null), 'age not recorded');
    expect(pseudonymOf('abc123xyz'), 'P-ABC123');
  });

  test('a patient is overdue after the checkup period without readings', () {
    expect(isOverdue(lastReading: now.subtract(const Duration(days: 4)), checkupPeriodDays: 3, now: now), isTrue);
    expect(isOverdue(lastReading: now.subtract(const Duration(days: 2)), checkupPeriodDays: 3, now: now), isFalse);
    expect(isOverdue(lastReading: null, checkupPeriodDays: 3, now: now), isFalse);
  });
}
