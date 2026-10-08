import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';

import '../models/risk_prediction.dart';
import 'risk_features.dart';

/// Loads the bundled TeleMonitor ONNX model once and runs on-device
/// inference — no network call, no server, works fully offline. This is
/// the piece that satisfies the offline-first rationale from Chapter 1/2
/// of the thesis (Dodoo 2022; Akinola 2025): the risk classification
/// always works, connectivity or not. Firebase sync (history, clinician
/// dashboard) stays a separate, independent concern from this class.
///
/// Usage:
/// ```dart
/// final service = RiskModelService();
/// await service.init();
/// final result = await service.predict(last7DaysOfReadings);
/// print(result.levelName);   // e.g. "high"
/// print(result.riskScore);   // R = P(high) + P(critical)
/// await service.dispose();   // call when done (e.g. in State.dispose())
/// ```
class RiskModelService {
  static const String assetPath = 'assets/models/telemonitor_risk_model.onnx';

  final OnnxRuntime _ort = OnnxRuntime();
  OrtSession? _session;

  bool get isReady => _session != null;

  Future<void> init() async {
    _session = await _ort.createSessionFromAsset(assetPath);
  }

  /// Full pipeline: raw daily readings -> features -> prediction.
  Future<RiskPrediction> predict(List<DailyReading> last7Days) {
    final features = SlidingWindowFeatures.compute(last7Days);
    return predictFromFeatures(features);
  }

  /// Lower-level entry point that skips feature engineering — takes the
  /// 16-value feature vector directly. Mainly useful for testing the ONNX
  /// plumbing in isolation (see test/risk_pipeline_verification_test.dart),
  /// but also usable if you ever compute features elsewhere.
  Future<RiskPrediction> predictFromFeatures(List<double> features) async {
    final session = _session;
    if (session == null) {
      throw StateError(
        'RiskModelService.init() must be awaited before predict().',
      );
    }
    if (features.length != SlidingWindowFeatures.featureOrder.length) {
      throw ArgumentError(
        'Expected ${SlidingWindowFeatures.featureOrder.length} features, '
        'got ${features.length}.',
      );
    }

    final inputs = {
      'input': await OrtValue.fromList(features, [1, features.length]),
    };

    final outputs = await session.run(inputs);

    final levelIndex = _flatten(await outputs['label']!.asList())
        .first
        .round();
    final probabilities = _flatten(await outputs['probabilities']!.asList());

    for (final t in inputs.values) {
      t.dispose();
    }
    for (final t in outputs.values) {
      t.dispose();
    }

    return RiskPrediction(levelIndex, probabilities);
  }

  /// The ONNX runtime plugin may return tensor data as a flat list or a
  /// nested list depending on shape — flatten defensively so both work.
  static List<double> _flatten(dynamic data) {
    final out = <double>[];
    void walk(dynamic v) {
      if (v is List) {
        for (final e in v) {
          walk(e);
        }
      } else if (v is num) {
        out.add(v.toDouble());
      }
    }

    walk(data);
    return out;
  }

  Future<void> dispose() async {
    await _session?.close();
    _session = null;
  }
}
