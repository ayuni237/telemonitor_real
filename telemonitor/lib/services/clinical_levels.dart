/// Severity of a single reading — thesis ch.3 §Labelling, Table
/// "tab:label-thresholds".
///
/// This is a mirror of telemonitor-research/configs/thresholds.yaml and of
/// labels.py. It MUST stay identical: test/clinical_levels_parity_test.dart
/// checks it against levels computed by the Python reference.
///
/// Levels: 0 stable, 1 moderate, 2 high, 3 critical. Within a condition the
/// worst channel governs; the overall level is the worst condition level
/// available. A channel that was not measured has no level — never "stable".
class ClinicalLevels {
  ClinicalLevels._();

  /// Version of the threshold table (configs/thresholds.yaml).
  static const String version = '2026-10-19';

  static const List<String> names = ['Stable', 'Moderate', 'High', 'Critical'];

  /// Level at or above which a reading is an alert (high or critical).
  static const int alertLevel = 2;

  /// Glucose molar mass 180.156 g/mol: 1 mmol/L = 18.0156 mg/dL. The rounded
  /// 18.0 would move 1.80 g/L (180 mg/dL) below the treatment threshold.
  static const double mgdlPerMmol = 18.0156;

  /// Systolic: ESH 2023 grades; NEWS2 red score at or below 90 mmHg.
  static int? sbp(num? v) {
    if (v == null) return null;
    var level = 0;
    if (v >= 140) level = 1;
    if (v >= 160) level = 2;
    if (v >= 180) level = 3;
    if (v <= 90) level = 3;
    return level;
  }

  /// Diastolic: ESH 2023 grades; no official lower threshold.
  static int? dbp(num? v) {
    if (v == null) return null;
    if (v >= 110) return 3;
    if (v >= 100) return 2;
    if (v >= 90) return 1;
    return 0;
  }

  /// Pulse: NEWS2 red score only (<= 40 or >= 131 beats per minute).
  static int? pulse(num? v) {
    if (v == null) return null;
    return (v <= 40 || v >= 131) ? 3 : 0;
  }

  /// Capillary glucose in mmol/L, compared in mg/dL (the unit of the sources):
  /// IHSG hypoglycaemia levels 1 and 2 (< 70, < 54 mg/dL); ADA in-hospital
  /// hyperglycaemia (> 140) and treatment threshold (>= 180); CMS severe
  /// hyperglycaemia (> 300).
  static int? glucose(num? mmol) {
    if (mmol == null) return null;
    // resolved to 1e-6 mg/dL so floating-point error cannot cross a boundary
    final mg = (mmol * mgdlPerMmol * 1e6).roundToDouble() / 1e6;
    var level = 0;
    if (mg > 140) level = 1;
    if (mg >= 180) level = 2;
    if (mg < 70) level = 2;
    if (mg > 300) level = 3;
    if (mg < 54) level = 3;
    return level;
  }

  static int? _worst(Iterable<int?> levels) {
    int? out;
    for (final l in levels) {
      if (l != null && (out == null || l > out)) out = l;
    }
    return out;
  }

  /// Haemodynamic condition: worst of systolic, diastolic and pulse.
  static int? haemodynamic({num? sbp, num? dbp, num? hr}) =>
      _worst([ClinicalLevels.sbp(sbp), ClinicalLevels.dbp(dbp), pulse(hr)]);

  /// Glycaemic condition: defined only where glucose was measured.
  static int? glycaemic(num? glucoseMmol) => glucose(glucoseMmol);

  /// Overall level: worst of the condition levels that exist.
  static int? overall({num? sbp, num? dbp, num? hr, num? glucoseMmol}) =>
      _worst([haemodynamic(sbp: sbp, dbp: dbp, hr: hr), glycaemic(glucoseMmol)]);

  static String name(int? level) => level == null ? 'Not measured' : names[level];
}
