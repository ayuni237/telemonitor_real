/// Pure helpers of the clinician queue (thesis ch.4, Table "Content of a
/// queue row"), kept apart from Firestore so they can be tested.
library;

import '../models/reading.dart';

enum TrendDirection { rising, falling, stable, unknown }

/// Fourteen-day window shown to the patient and to the clinician.
const Duration trendWindow = Duration(days: 14);

/// Default checkup period: a patient with no reading for longer raises a
/// non-transmission event. Configurable per patient by the clinician
/// (yazdani2018); the default is provisional, like the tier cut-points.
const int defaultCheckupPeriodDays = 3;

/// Change over the window below which a trend is called stable: 5 mmHg of
/// systolic pressure, 1 mmol/L of glucose. A display aid for the clinician,
/// not a clinical threshold.
const double sbpStableBand = 5;
const double glucoseStableBand = 1;

/// Direction of the least-squares line through the values of the last
/// fourteen days, expressed as the change over the whole window. Unknown
/// with fewer than three values or values spanning less than two days.
TrendDirection trendOf(List<(DateTime, double)> points, double stableBand, {DateTime? now}) {
  final end = now ?? DateTime.now();
  final inWindow = points.where((p) => end.difference(p.$1) <= trendWindow).toList();
  if (inWindow.length < 3) return TrendDirection.unknown;
  final xs = [for (final p in inWindow) p.$1.difference(end).inMinutes / (60 * 24)];
  final span = xs.reduce((a, b) => a > b ? a : b) - xs.reduce((a, b) => a < b ? a : b);
  if (span < 2) return TrendDirection.unknown;
  final ys = [for (final p in inWindow) p.$2];
  final mx = xs.reduce((a, b) => a + b) / xs.length;
  final my = ys.reduce((a, b) => a + b) / ys.length;
  var sxy = 0.0, sxx = 0.0;
  for (var i = 0; i < xs.length; i++) {
    sxy += (xs[i] - mx) * (ys[i] - my);
    sxx += (xs[i] - mx) * (xs[i] - mx);
  }
  final change = sxy / sxx * trendWindow.inDays;
  if (change >= stableBand) return TrendDirection.rising;
  if (change <= -stableBand) return TrendDirection.falling;
  return TrendDirection.stable;
}

TrendDirection systolicTrend(List<Reading> readings, {DateTime? now}) => trendOf(
    [for (final r in readings) if (r.sbp != null) (r.timestamp, r.sbp!.toDouble())], sbpStableBand,
    now: now);

TrendDirection glucoseTrend(List<Reading> readings, {DateTime? now}) => trendOf(
    [for (final r in readings) if (r.glucose != null) (r.timestamp, r.glucose!)], glucoseStableBand,
    now: now);

/// Five-year age band, as in the patient record of ch.4.
String ageBand(int? age) {
  if (age == null) return 'age not recorded';
  final lo = age ~/ 5 * 5;
  return '$lo–${lo + 4} yrs';
}

/// Pseudonym shown on a queue row: identification without identity. Built
/// from the account id, which is random and not derived from identity.
String pseudonymOf(String uid) =>
    'P-${(uid.length >= 6 ? uid.substring(0, 6) : uid).toUpperCase()}';

/// Whether a patient is overdue: no reading for longer than the checkup
/// period. A patient who never sent a reading is not counted: the profile
/// holds no enrolment date to measure the silence from.
bool isOverdue({required DateTime? lastReading, required int checkupPeriodDays, DateTime? now}) {
  if (lastReading == null) return false;
  return (now ?? DateTime.now()).difference(lastReading) > Duration(days: checkupPeriodDays);
}
