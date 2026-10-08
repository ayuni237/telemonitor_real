import '../models/reading.dart';
import '../models/risk_assessment.dart';
import 'risk_features.dart';
import 'risk_model_service.dart';

/// Turns a patient's stored readings into a risk assessment.
///
/// This is the layer that reconciles two things that don't naturally
/// line up: the model was trained on tidy daily records with all four
/// channels present, while real patients log irregularly and often
/// record blood pressure without glucose, or the reverse.
///
/// The reconciliation is deliberately conservative. Missing values are
/// carried forward (last-observation-carried-forward, standard practice
/// for clinical time series), but only up to a point — past that the
/// service refuses to produce a score rather than emit a confident
/// number built out of repetition.
class RiskAssessmentService {
  RiskAssessmentService._internal();
  static final RiskAssessmentService instance =
      RiskAssessmentService._internal();

  final RiskModelService _model = RiskModelService();
  bool _initialised = false;

  /// Window length the model expects.
  static const int kWindow = SlidingWindowFeatures.windowSize; // 7

  /// Minimum number of REAL (non-imputed) values a channel must have in
  /// the window. Below this, standard deviation and trend collapse
  /// toward zero — the model would read a barely-measured channel as
  /// "perfectly stable", which is exactly the wrong signal when the
  /// truth is "we don't know".
  static const int kMinRealPerChannel = 3;

  /// Used only when heart rate is entirely absent. HR is an optional
  /// field in the log screen and was not among the model's leading
  /// features, so a neutral constant is preferable to refusing a score
  /// outright — but it is counted as fully imputed in [completeness].
  static const double kNeutralHeartRate = 75.0;

  Future<void> _ensureInit() async {
    if (_initialised) return;
    await _model.init();
    _initialised = true;
  }

  /// [readings] should be the patient's readings, most recent first —
  /// exactly what ReadingsRepository.readings returns.
  ///
  /// Note the window is the last 7 *readings*, not the last 7 calendar
  /// days. The model was trained on daily records, so this carries an
  /// assumption that logging is roughly daily; a patient logging three
  /// times a day would compress the trend's time axis. Recorded as a
  /// known limitation rather than silently absorbed.
  Future<RiskAssessment> assess(List<Reading> readings) async {
    if (readings.length < kWindow) {
      return RiskAssessment.unavailable(
        RiskUnavailableReason.notEnoughReadings,
        readingsStillNeeded: kWindow - readings.length,
      );
    }

    // Oldest first — the order SlidingWindowFeatures expects.
    final window = readings.take(kWindow).toList().reversed.toList();

    final sbp = window.map((r) => r.sbp?.toDouble()).toList();
    final dbp = window.map((r) => r.dbp?.toDouble()).toList();
    final glu = window.map((r) => r.glucose).toList();
    final hr = window.map((r) => r.hr?.toDouble()).toList();

    final realCounts = {
      'sbp': sbp.whereType<double>().length,
      'dbp': dbp.whereType<double>().length,
      'glucose': glu.whereType<double>().length,
      'hr': hr.whereType<double>().length,
    };

    // Blood pressure and glucose are the channels the model actually
    // leans on, so they carry a hard requirement. Heart rate does not.
    for (final key in ['sbp', 'dbp', 'glucose']) {
      if (realCounts[key]! < kMinRealPerChannel) {
        return RiskAssessment.unavailable(RiskUnavailableReason.tooSparse);
      }
    }

    final filledSbp = _impute(sbp);
    final filledDbp = _impute(dbp);
    final filledGlu = _impute(glu);
    final filledHr = realCounts['hr']! == 0
        ? List<double>.filled(kWindow, kNeutralHeartRate)
        : _impute(hr);

    if (filledSbp == null || filledDbp == null || filledGlu == null) {
      return RiskAssessment.unavailable(RiskUnavailableReason.tooSparse);
    }

    final totalReal = realCounts.values.reduce((a, b) => a + b);
    final completeness = totalReal / (4 * kWindow);

    final imputed = <String>[];
    realCounts.forEach((channel, count) {
      if (count < kWindow) imputed.add(channel);
    });

    final daily = List.generate(
      kWindow,
      (i) => DailyReading(
        sbp: filledSbp[i],
        dbp: filledDbp[i],
        glucose: filledGlu[i],
        hr: filledHr![i],
      ),
    );

    try {
      await _ensureInit();
      final prediction = await _model.predict(daily);
      return RiskAssessment.available(
        prediction: prediction,
        completeness: completeness,
        imputedChannels: imputed,
      );
    } catch (_) {
      return RiskAssessment.unavailable(RiskUnavailableReason.modelError);
    }
  }

  /// Last-observation-carried-forward, then back-fill any leading gap
  /// with the first real value. Returns null if the channel is empty.
  ///
  /// Carrying forward is the right direction for clinical data: the
  /// most recent measurement remains the best estimate until a new one
  /// arrives. Back-filling the start is less principled but bounded —
  /// it only affects positions before the first measurement.
  static List<double>? _impute(List<double?> values) {
    if (values.every((v) => v == null)) return null;

    final out = List<double?>.from(values);

    double? last;
    for (var i = 0; i < out.length; i++) {
      if (out[i] != null) {
        last = out[i];
      } else {
        out[i] = last;
      }
    }

    // Anything still null is a leading gap — fill from the first known.
    final firstKnown = out.firstWhere((v) => v != null)!;
    for (var i = 0; i < out.length; i++) {
      out[i] ??= firstKnown;
    }

    return out.cast<double>();
  }

  Future<void> dispose() async {
    if (!_initialised) return;
    await _model.dispose();
    _initialised = false;
  }
}
