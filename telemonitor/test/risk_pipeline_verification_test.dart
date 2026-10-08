// Verifies the Dart pipeline against known outputs from the ACTUAL trained
// Python model (xgb_final, exported from TeleMonitor_model.ipynb) — not
// invented numbers. Run this once after wiring things up, before trusting
// any prediction shown in the app.
//
// IMPORTANT: replace 'your_app' below with your real package name from
// pubspec.yaml (the `name:` field).
import 'package:flutter_test/flutter_test.dart';
import 'package:telemonitor/services/risk_features.dart';
import 'package:telemonitor/services/risk_model_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SlidingWindowFeatures — feature engineering matches Python', () {
    test('7-day raw window produces the exact features pandas computed', () {
      // Patient 0's first window, days 0-6, from generate_synthetic()
      // (seed=42) — the literal first example make_windows() produces.
      final window = <DailyReading>[
        const DailyReading(
          sbp: 134.403715,
          dbp: 74.693256,
          glucose: 7.981594,
          hr: 85.755370,
        ),
        const DailyReading(
          sbp: 144.096377,
          dbp: 75.610588,
          glucose: 9.348850,
          hr: 71.533758,
        ),
        const DailyReading(
          sbp: 140.803939,
          dbp: 80.150321,
          glucose: 8.626594,
          hr: 75.613574,
        ),
        const DailyReading(
          sbp: 143.817420,
          dbp: 79.990233,
          glucose: 10.718628,
          hr: 75.939551,
        ),
        const DailyReading(
          sbp: 147.462160,
          dbp: 77.431573,
          glucose: 8.498345,
          hr: 72.777258,
        ),
        const DailyReading(
          sbp: 143.709903,
          dbp: 81.009331,
          glucose: 9.331972,
          hr: 80.935004,
        ),
        const DailyReading(
          sbp: 148.183930,
          dbp: 80.893759,
          glucose: 9.874381,
          hr: 67.751950,
        ),
      ];

      final features = SlidingWindowFeatures.compute(window);

      // Expected, computed in Python with numpy/pandas on the same window.
      const expected = <double>[
        143.211063, 4.268910, 1.686640, 148.183930, // sbp: mean/std/trend/last
        78.539866, 2.418429, 0.952866, 80.893759, // dbp
        9.197195, 0.854080, 0.197013, 9.874381, // glucose
        75.758066, 5.575821, -1.358717, 67.751950, // hr
      ];

      expect(features.length, 16);
      for (var i = 0; i < 16; i++) {
        expect(
          features[i],
          closeTo(expected[i], 0.001),
          reason: 'feature[$i] = ${SlidingWindowFeatures.featureOrder[i]}',
        );
      }
    });
  });

  group('RiskModelService — ONNX model matches the Python reference', () {
    test('known CRITICAL example produces the same prediction', () async {
      final service = RiskModelService();
      await service.init();

      // Row 30 of X_reference.csv — a real training example labeled critical.
      const features = <double>[
        174.065750,
        6.245589,
        1.936792,
        178.908768,
        111.364845,
        3.395811,
        -0.122800,
        113.217400,
        5.255987,
        0.594825,
        -0.183789,
        5.144424,
        128.910828,
        9.432207,
        -1.913580,
        132.907730,
      ];

      final result = await service.predictFromFeatures(features);

      expect(result.levelIndex, 3); // critical
      expect(result.levelName, 'critical');
      expect(result.probabilities[3], closeTo(0.977560, 0.01));
      expect(result.riskScore, closeTo(0.999609, 0.01)); // P(high)+P(critical)

      await service.dispose();
    });

    test('known STABLE example produces the same prediction', () async {
      final service = RiskModelService();
      await service.init();

      // Row 78 of X_reference.csv — a real training example labeled stable.
      const features = <double>[
        129.938629,
        3.396365,
        0.677869,
        131.144913,
        72.761208,
        6.483388,
        0.849733,
        75.957512,
        6.213012,
        0.371770,
        -0.100779,
        5.596431,
        107.405540,
        6.345024,
        -0.861888,
        100.967697,
      ];

      final result = await service.predictFromFeatures(features);

      expect(result.levelIndex, 0); // stable
      expect(result.probabilities[0], closeTo(0.891047, 0.01));
      expect(result.needsClinicianAlert, false);

      await service.dispose();
    });
  });
}
