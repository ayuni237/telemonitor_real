import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemonitor/models/reading.dart';
import 'package:telemonitor/screens/patient/log_reading_screen.dart';
import 'package:telemonitor/services/camera_pulse.dart';

/// Frames of a fingertip on the lens: about 30 per second, unevenly spaced,
/// with breathing, a slow drift of the finger's pressure and sensor noise.
/// [bpm] varies by [variability] with the breathing, as a real pulse does;
/// [irregular] draws every beat at random, as in an irregular rhythm.
List<(int, FrameColour)> fingertip({
  required double bpm,
  double seconds = 24,
  double amplitude = 1.6,
  double noise = 0.3,
  double variability = 0.03,
  bool irregular = false,
  bool saturated = false,
  int seed = 1,
}) {
  final rnd = math.Random(seed);
  double gauss() => math.sqrt(-2 * math.log(1 - rnd.nextDouble())) * math.cos(2 * math.pi * rnd.nextDouble());
  final frames = <(int, FrameColour)>[];
  var t = 0.0, phase = 0.0, beatHz = bpm / 60;
  while (t < seconds) {
    final dt = 1 / 30 + (rnd.nextDouble() - 0.5) * 0.01;
    t += dt;
    final hz = irregular ? beatHz : bpm / 60 * (1 + variability * math.sin(2 * math.pi * 0.25 * t));
    final before = phase;
    phase += hz * dt;
    if (irregular && phase.floor() != before.floor()) beatHz = bpm / 60 * (0.55 + 0.9 * rnd.nextDouble());
    final p = phase % 1;
    final pulse = amplitude * (math.sin(2 * math.pi * p) + 0.4 * math.sin(4 * math.pi * p + 0.8));
    final drift = 4 * math.sin(2 * math.pi * 0.2 * t) + 0.5 * t;
    final red = saturated ? 255.0 : 190 + drift - pulse + noise * gauss();
    final green = 45 + 0.3 * drift - 0.5 * pulse + noise * gauss();
    frames.add(((t * 1e6).round(), FrameColour(red, green)));
  }
  return frames;
}

PulseEstimate? analyse(List<(int, FrameColour)> frames, {bool green = false}) =>
    PulseAnalysis.estimate([for (final f in frames) f.$1], [for (final f in frames) green ? f.$2.green : f.$2.red]);

void main() {
  group('pulse from the brightness signal', () {
    test('a resting pulse of 72 is found within 2 beats per minute', () {
      final e = analyse(fingertip(bpm: 72));
      expect(e, isNotNull);
      expect(e!.bpm, closeTo(72, 2));
      expect(e.quality, greaterThan(PulseAnalysis.minQuality));
      expect(e.beats, inInclusiveRange(25, 30));
    });

    test('slow and fast pulses are found too', () {
      for (final bpm in [45.0, 58.0, 95.0, 120.0, 150.0, 185.0]) {
        final e = analyse(fingertip(bpm: bpm, seed: bpm.round()));
        expect(e, isNotNull, reason: '$bpm bpm');
        expect(e!.bpm, closeTo(bpm, 3), reason: '$bpm bpm');
      }
    });

    test('noise without a pulse gives no value', () {
      for (var seed = 1; seed <= 10; seed++) {
        expect(analyse(fingertip(bpm: 72, amplitude: 0, noise: 1.5, seed: seed)), isNull, reason: 'seed $seed');
      }
    });

    test('an irregular rhythm gives no value rather than a wrong one', () {
      for (var seed = 1; seed <= 10; seed++) {
        expect(analyse(fingertip(bpm: 80, irregular: true, seed: seed)), isNull, reason: 'seed $seed');
      }
    });

    test('less than 15 seconds of signal gives no value', () {
      expect(analyse(fingertip(bpm: 72, seconds: 12)), isNull);
    });
  });

  group('frame colour', () {
    test('a lit fingertip is told apart from a room or a dark lens', () {
      expect(const FrameColour(210, 40).fingerOn, isTrue);
      expect(const FrameColour(140, 115).fingerOn, isFalse, reason: 'a room');
      expect(const FrameColour(35, 8).fingerOn, isFalse, reason: 'finger without the flash');
    });

    // Y 120, U 110, V 200: red 120 + 1.402 x 72, green 120 + 0.344 x 18 - 0.714 x 72
    const red = 220.9, green = 74.8;

    test('YUV frames with interleaved chroma (Android)', () {
      const w = 64, h = 48;
      final uv = Uint8List(w * h ~/ 2);
      for (var i = 0; i < uv.length; i += 2) {
        uv[i] = 110;
        if (i + 1 < uv.length) uv[i + 1] = 200;
      }
      final c = FrameColour.fromYuv(
        width: w,
        height: h,
        y: Uint8List(w * h)..fillRange(0, w * h, 120),
        yRowStride: w,
        u: uv,
        v: Uint8List.sublistView(uv, 1),
        uvRowStride: w,
        uvPixelStride: 2,
      );
      expect(c.red, closeTo(red, 0.5));
      expect(c.green, closeTo(green, 0.5));
      expect(c.fingerOn, isTrue);
    });

    test('NV21 frames', () {
      const w = 64, h = 48;
      final bytes = Uint8List(w * h * 3 ~/ 2)..fillRange(0, w * h, 120);
      for (var i = w * h; i < bytes.length; i += 2) {
        bytes[i] = 200; // V first
        bytes[i + 1] = 110;
      }
      final c = FrameColour.fromNv21(width: w, height: h, bytes: bytes, rowStride: w);
      expect(c.red, closeTo(red, 0.5));
      expect(c.green, closeTo(green, 0.5));
    });

    test('BGRA frames (iPhone)', () {
      const w = 64, h = 48;
      final bytes = Uint8List(w * h * 4);
      for (var i = 0; i < bytes.length; i += 4) {
        bytes.setAll(i, [20, 50, 210, 255]);
      }
      final c = FrameColour.fromBgra(width: w, height: h, bytes: bytes, rowStride: w * 4);
      expect(c.red, 210);
      expect(c.green, 50);
    });
  });

  group('measurement', () {
    test('waits for the finger, settles, measures 20 seconds, then gives the pulse', () {
      final m = PulseMeter();
      final frames = fingertip(bpm: 76, seconds: 25);
      final phases = <PulsePhase>{};
      var lastProgress = 0.0;
      for (final (t, c) in frames) {
        m.add(t, c);
        phases.add(m.phase);
        expect(m.progress, greaterThanOrEqualTo(lastProgress));
        lastProgress = m.progress;
      }
      expect(phases, containsAll([PulsePhase.settling, PulsePhase.measuring, PulsePhase.done]));
      expect(m.result!.bpm, closeTo(76, 2));
      expect(m.trace.length, PulseMeter.traceLength);
    });

    test('lifting the finger starts the measurement again', () {
      final m = PulseMeter();
      final frames = fingertip(bpm: 70, seconds: 10);
      for (final (t, c) in frames) {
        m.add(t, c);
      }
      expect(m.phase, PulsePhase.measuring);
      final end = frames.last.$1;
      for (var i = 1; i <= 30; i++) {
        m.add(end + i * 33333, const FrameColour(140, 115));
      }
      expect(m.phase, PulsePhase.waiting);
      expect(m.interrupted, isTrue);

      final start = end + 31 * 33333;
      for (final (t, c) in fingertip(bpm: 70, seconds: 25, seed: 9)) {
        m.add(start + t, c);
      }
      expect(m.phase, PulsePhase.done);
      expect(m.interrupted, isFalse);
      expect(m.result!.bpm, closeTo(70, 2));
    });

    test('a brief slip of the finger does not stop the measurement', () {
      final m = PulseMeter();
      for (final (t, c) in fingertip(bpm: 82, seconds: 25)) {
        final slipping = t > 12e6 && t < 12.3e6;
        m.add(t, slipping ? const FrameColour(140, 115) : c);
      }
      expect(m.phase, PulsePhase.done);
      expect(m.result!.bpm, closeTo(82, 2));
    });

    test('a flash that saturates the red channel falls back on the green one', () {
      final m = PulseMeter();
      for (final (t, c) in fingertip(bpm: 66, seconds: 25, saturated: true)) {
        m.add(t, c);
      }
      expect(m.phase, PulsePhase.done);
      expect(m.result!.bpm, closeTo(66, 2));
    });

    test('a noisy measurement ends without a value, and can be restarted', () {
      final m = PulseMeter();
      for (final (t, c) in fingertip(bpm: 72, seconds: 25, amplitude: 0, noise: 1.5)) {
        m.add(t, c);
      }
      expect(m.phase, PulsePhase.failed);
      expect(m.result, isNull);
      m.restart();
      expect(m.phase, PulsePhase.waiting);
      expect(m.progress, 0);
    });
  });

  group('entry screen', () {
    testWidgets('offers the camera pulse, and a correction keeps it unless removed', (tester) async {
      tester.view.physicalSize = const Size(1080, 5200);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(const MaterialApp(home: LogReadingScreen()));
      expect(find.text('Pulse with the phone camera (optional)'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Measure'), findsOneWidget);

      final old = Reading(
        id: 'x',
        timestamp: DateTime.now(),
        sbp: 140,
        dbp: 90,
        hr: 76,
        hrCamera: 74,
        hrCameraQuality: 0.8,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: LogReadingScreen(key: const ValueKey(2), correcting: old),
        ),
      );
      expect(find.text('Pulse by camera: 74 bpm'), findsOneWidget);
      await tester.tap(find.byTooltip('Remove'));
      await tester.pump();
      expect(find.text('Pulse with the phone camera (optional)'), findsOneWidget);
    });
  });
}
