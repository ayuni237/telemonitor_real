import 'dart:math' as math;

/// One day's readings for a patient — mirrors the CSV columns the model
/// was trained on: (day, sbp, dbp, glucose, hr).
///
/// If you already have a Measurement/Reading model elsewhere in the app,
/// don't rename it — just map to this shape at the call site before
/// calling [SlidingWindowFeatures.compute].
class DailyReading {
  final double sbp;
  final double dbp;
  final double glucose; // mmol/L — same unit as the training notebook
  final double hr;

  const DailyReading({
    required this.sbp,
    required this.dbp,
    required this.glucose,
    required this.hr,
  });
}

/// Reproduces, feature-for-feature, the `make_windows()` function from
/// TeleMonitor_model.ipynb.
///
/// This MUST stay in exact lockstep with the Python training code. The
/// model has no idea what "sbp_mean" means — it only knows "the value at
/// position 0 was around 143 during training." If this code computes that
/// position differently than pandas did, the model silently sees garbage
/// and produces confident, wrong predictions. There's no error message for
/// this class of bug, which is why the verification test in
/// test/risk_pipeline_verification_test.dart checks this against a known
/// Python-computed example before trusting it.
class SlidingWindowFeatures {
  /// Window size used during training (see notebook: `make_windows(df, k=7)`).
  /// Do not change without retraining the model.
  static const int windowSize = 7;

  /// Feature order the model expects. f0..f15 in the ONNX model correspond
  /// 1:1, in this exact order, to this list.
  static const List<String> featureOrder = [
    'sbp_mean', 'sbp_std', 'sbp_trend', 'sbp_last',
    'dbp_mean', 'dbp_std', 'dbp_trend', 'dbp_last',
    'glucose_mean', 'glucose_std', 'glucose_trend', 'glucose_last',
    'hr_mean', 'hr_std', 'hr_trend', 'hr_last',
  ];

  /// [last7Days] must be exactly 7 readings, **oldest first, most recent
  /// last** — the same chronological order pandas used (`sort_values("day")`).
  static List<double> compute(List<DailyReading> last7Days) {
    if (last7Days.length != windowSize) {
      throw ArgumentError(
        'Expected exactly $windowSize daily readings, got '
        '${last7Days.length}. The model was trained on 7-day windows — '
        'padding or truncating changes the input distribution the model '
        'was never shown.',
      );
    }

    final sbp = last7Days.map((r) => r.sbp).toList();
    final dbp = last7Days.map((r) => r.dbp).toList();
    final glucose = last7Days.map((r) => r.glucose).toList();
    final hr = last7Days.map((r) => r.hr).toList();

    return [
      ..._statsFor(sbp),
      ..._statsFor(dbp),
      ..._statsFor(glucose),
      ..._statsFor(hr),
    ];
  }

  /// Returns [mean, std, trend, last] for one column — mirrors the Python:
  /// ```
  /// row[f"{col}_mean"]  = x.mean()
  /// row[f"{col}_std"]   = x.std()                              # ddof=0
  /// row[f"{col}_trend"] = np.polyfit(np.arange(k), x, 1)[0]    # slope
  /// row[f"{col}_last"]  = x[-1]
  /// ```
  static List<double> _statsFor(List<double> x) {
    final k = x.length;
    final mean = x.reduce((a, b) => a + b) / k;

    // Population std — numpy's default is ddof=0 (divide by k, not k-1).
    // Using Dart's usual "sample std / (k-1)" here would silently diverge
    // from what the model was trained on.
    final variance =
        x.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / k;
    final std = math.sqrt(variance);

    // Least-squares slope of x against t = 0..k-1 — same value
    // np.polyfit(np.arange(k), x, 1)[0] returns for a degree-1 fit.
    final t = List<double>.generate(k, (i) => i.toDouble());
    final tMean = t.reduce((a, b) => a + b) / k;
    double num = 0, den = 0;
    for (var i = 0; i < k; i++) {
      num += (t[i] - tMean) * (x[i] - mean);
      den += (t[i] - tMean) * (t[i] - tMean);
    }
    final trend = den == 0 ? 0.0 : num / den;

    final last = x[k - 1];

    return [mean, std, trend, last];
  }
}
