import '../models/reading.dart';

/// Home triage — thesis ch.4 §The self-measurement protocol and three-level
/// triage, Table "tab:thresholds" (protocol of Mihevc et al. 2025).
///
/// The research labels (ClinicalLevels) use in-hospital thresholds, the
/// setting of the data. This application is a home deployment, which
/// substitutes the out-of-office thresholds of the protocol (thesis ch.3
/// §Labelling). Mirror of telemonitor-research/configs/home_protocol.yaml:
/// test/home_protocol_parity_test.dart checks it against the Python reference.
///
/// Levels: 0 green, 1 yellow, 2 red. Within a reading the worst channel
/// governs. A channel that was not measured has no level.
class HomeProtocol {
  HomeProtocol._();

  static const String version = 'home-2026-10-22';

  static const int green = 0, yellow = 1, red = 2;
  static const List<String> names = ['Green', 'Yellow', 'Red'];

  /// Contexts in which a glucose reading is held to the before-meal targets;
  /// any other context (meal status unknown) uses the after-meal targets.
  static const Set<String> beforeMeal = {'Fasting', 'Before meal'};

  static int? _resolve(num? v, int Function(double) f) =>
      v == null ? null : f((v.toDouble() * 1e6).roundToDouble() / 1e6);

  /// Systolic: red at or above 175 or below 110; yellow from 135.
  static int? sbp(num? v) => _resolve(v, (x) => (x >= 175 || x < 110) ? red : (x >= 135 ? yellow : green));

  /// Diastolic: red at or above 105 or below 60; yellow from 85.
  static int? dbp(num? v) => _resolve(v, (x) => (x >= 105 || x < 60) ? red : (x >= 85 ? yellow : green));

  /// Pulse: the protocol has none; the NEWS2 red score of the label is kept.
  static int? pulse(num? v) => _resolve(v, (x) => (x <= 40 || x >= 131) ? red : green);

  /// Glucose in mmol/L, before a meal: red below 4 or above 10; yellow above 7.
  static int? glucoseBeforeMeal(num? v) => _resolve(v, (x) => (x < 4.0 || x > 10.0) ? red : (x > 7.0 ? yellow : green));

  /// Glucose in mmol/L, 90 minutes after a meal: red below 4 or above 14; yellow above 10.
  static int? glucoseAfterMeal(num? v) => _resolve(v, (x) => (x < 4.0 || x > 14.0) ? red : (x > 10.0 ? yellow : green));

  static int? glucose(num? v, String context) =>
      beforeMeal.contains(context) ? glucoseBeforeMeal(v) : glucoseAfterMeal(v);

  static int? _worst(Iterable<int?> levels) {
    int? out;
    for (final l in levels) {
      if (l != null && (out == null || l > out)) out = l;
    }
    return out;
  }

  static int? haemodynamic({num? sbp, num? dbp, num? hr}) =>
      _worst([HomeProtocol.sbp(sbp), HomeProtocol.dbp(dbp), pulse(hr)]);

  static int? level({num? sbp, num? dbp, num? hr, num? glucoseMmol, String context = ''}) =>
      _worst([haemodynamic(sbp: sbp, dbp: dbp, hr: hr), glucose(glucoseMmol, context)]);

  static int? ofReading(Reading r) =>
      level(sbp: r.sbp, dbp: r.dbp, hr: r.hr, glucoseMmol: r.glucose, context: r.context);

  static String name(int? level) => level == null ? 'Not measured' : names[level];
}

/// One verification profile (Table "tab:thresholds", yellow level), started
/// by a yellow reading: seven days of blood pressure, or a one-day six-point
/// glucose profile; its mean is then compared with the home target.
enum ProfileKind { bloodPressure, glucose }

enum ProfileStatus { inProgress, complete, incomplete }

class ProfileResult {
  final ProfileKind kind;
  final DateTime start;
  final DateTime end;
  final ProfileStatus status;
  final int readings;
  final int expected;
  final int days;
  final int beforeMeal;
  final int afterMeal;
  final double? meanSbp;
  final double? meanDbp;
  final double? meanBeforeMeal;
  final double? meanAfterMeal;

  /// Null until the profile is complete.
  final bool? offTarget;

  const ProfileResult({
    required this.kind,
    required this.start,
    required this.end,
    required this.status,
    required this.readings,
    required this.expected,
    this.days = 0,
    this.beforeMeal = 0,
    this.afterMeal = 0,
    this.meanSbp,
    this.meanDbp,
    this.meanBeforeMeal,
    this.meanAfterMeal,
    this.offTarget,
  });
}

class VerificationProfile {
  VerificationProfile._();

  // Mirror of configs/home_protocol.yaml, section `profiles`.
  static const Duration bpWindow = Duration(hours: 192);
  static const int bpExpected = 14, bpMinRetained = 6, bpMinDays = 3;
  static const Duration glucoseWindow = Duration(hours: 48);
  static const int glucoseExpected = 6, glucoseMinBefore = 3, glucoseMinAfter = 3;

  static double _round(double x, int d) {
    final f = d == 1 ? 10.0 : 100.0;
    return (x * f).roundToDouble() / f;
  }

  static double? _mean(List<double> xs) => xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;

  /// Seven-day blood-pressure profile started at [start] (the triggering
  /// reading is not part of it).
  static ProfileResult bloodPressure(DateTime start, List<Reading> readings, DateTime now) {
    final end = start.add(bpWindow);
    final rs = [
      for (final r in Reading.effective(readings))
        if (r.timestamp.isAfter(start) && r.timestamp.isBefore(end) && !r.timestamp.isAfter(now) && r.hasBP) r
    ];
    final days = {for (final r in rs) DateTime(r.timestamp.year, r.timestamp.month, r.timestamp.day)}.length;
    final s = _mean([for (final r in rs) r.sbp!.toDouble()]);
    final d = _mean([for (final r in rs) r.dbp!.toDouble()]);
    final meanSbp = s == null ? null : _round(s, 1), meanDbp = d == null ? null : _round(d, 1);
    ProfileResult result(ProfileStatus st, bool? off) => ProfileResult(
          kind: ProfileKind.bloodPressure, start: start, end: end, status: st, readings: rs.length,
          expected: bpExpected, days: days, meanSbp: meanSbp, meanDbp: meanDbp, offTarget: off);
    if (now.isBefore(end) && rs.length < bpExpected) return result(ProfileStatus.inProgress, null);
    if (rs.length < bpMinRetained || days < bpMinDays) return result(ProfileStatus.incomplete, null);
    final off = meanSbp! >= 135 || meanDbp! >= 85 || meanSbp < 110 || meanDbp < 60;
    return result(ProfileStatus.complete, off);
  }

  /// One-day six-point glucose profile started at [start].
  static ProfileResult glucose(DateTime start, List<Reading> readings, DateTime now) {
    final end = start.add(glucoseWindow);
    final rs = [
      for (final r in Reading.effective(readings))
        if (r.timestamp.isAfter(start) && r.timestamp.isBefore(end) && !r.timestamp.isAfter(now) && r.hasGlucose) r
    ];
    final before = [for (final r in rs) if (HomeProtocol.beforeMeal.contains(r.context)) r.glucose!];
    final after = [for (final r in rs) if (!HomeProtocol.beforeMeal.contains(r.context)) r.glucose!];
    final mb = _mean(before), ma = _mean(after);
    final meanBefore = mb == null ? null : _round(mb, 2), meanAfter = ma == null ? null : _round(ma, 2);
    ProfileResult result(ProfileStatus st, bool? off) => ProfileResult(
          kind: ProfileKind.glucose, start: start, end: end, status: st, readings: rs.length,
          expected: glucoseExpected, beforeMeal: before.length, afterMeal: after.length,
          meanBeforeMeal: meanBefore, meanAfterMeal: meanAfter, offTarget: off);
    final enough = before.length >= glucoseMinBefore && after.length >= glucoseMinAfter;
    if (now.isBefore(end) && !enough) return result(ProfileStatus.inProgress, null);
    if (!enough) return result(ProfileStatus.incomplete, null);
    final off = (meanBefore != null && meanBefore > 7.0) || (meanAfter != null && meanAfter > 10.0);
    return result(ProfileStatus.complete, off);
  }

  /// The profiles a patient owes now: those started by the most recent yellow
  /// readings within their windows, latest first. A profile is started by the
  /// first yellow reading not already inside a running profile of its kind.
  static List<ProfileResult> active(List<Reading> readings, DateTime now) {
    final rs = [...Reading.effective(readings)]..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final out = <ProfileResult>[];
    for (final kind in ProfileKind.values) {
      DateTime? start;
      for (final r in rs) {
        final yellow = kind == ProfileKind.bloodPressure
            ? HomeProtocol.haemodynamic(sbp: r.sbp, dbp: r.dbp, hr: r.hr) == HomeProtocol.yellow
            : HomeProtocol.glucose(r.glucose, r.context) == HomeProtocol.yellow;
        final window = kind == ProfileKind.bloodPressure ? bpWindow : glucoseWindow;
        if (yellow && (start == null || !r.timestamp.isBefore(start.add(window)))) start = r.timestamp;
      }
      if (start == null) continue;
      final p = kind == ProfileKind.bloodPressure ? bloodPressure(start, rs, now) : glucose(start, rs, now);
      // a finished profile stays visible for a week, then the next yellow reading starts another
      if (p.status == ProfileStatus.inProgress || now.difference(p.end) < const Duration(days: 7)) out.add(p);
    }
    out.sort((a, b) => b.start.compareTo(a.start));
    return out;
  }
}
