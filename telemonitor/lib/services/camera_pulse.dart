import 'dart:math' as math;
import 'dart:typed_data';

// Pulse measured with the phone camera: fingertip photoplethysmography
// (PPG). With the flash on and a fingertip over the lens, each heartbeat
// briefly fills the skin with blood, which absorbs light: the brightness of
// the image falls and rises with the pulse.
//
// The thesis (ch.2, smartphone sensing) treats this as a plausible low-cost
// source of heart rate, to be evaluated rather than relied upon. The value
// is therefore kept beside the monitor's pulse (Reading.hrCamera), shown to
// the patient and the clinician, and never used by the triage or the model;
// the readings that carry both values give the paired data of a
// Bland-Altman comparison of the camera with the monitor.
//
// This file is pure Dart, without the camera, so that it can be tested with
// synthetic signals; camera_pulse_screen.dart feeds it the frames.

/// Mean colour of the centre of a camera frame, from 0 to 255.
class FrameColour {
  final double red;
  final double green;
  const FrameColour(this.red, this.green);

  /// A fingertip lit by the flash: bright red, little green (absorbed by
  /// the blood). A room, a dark lens or a lens half covered fails.
  bool get fingerOn => red >= 70 && green <= 0.6 * red;

  /// Centre of a YUV 4:2:0 frame. The chroma planes have half the
  /// resolution; [uvPixelStride] is 2 when U and V are interleaved.
  static FrameColour fromYuv({
    required int width,
    required int height,
    required Uint8List y,
    required int yRowStride,
    required Uint8List u,
    required Uint8List v,
    required int uvRowStride,
    required int uvPixelStride,
  }) {
    final sum = _Sum();
    _centre(width, height, (x, row) {
      final yi = row * yRowStride + x;
      final ci = (row ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
      if (yi >= y.length || ci >= u.length || ci >= v.length) return;
      sum.addYuv(y[yi], u[ci], v[ci]);
    });
    return sum.colour;
  }

  /// Centre of an NV21 frame: one plane, the luma rows then V and U
  /// interleaved at half resolution.
  static FrameColour fromNv21({
    required int width,
    required int height,
    required Uint8List bytes,
    required int rowStride,
  }) {
    final sum = _Sum();
    final chroma = rowStride * height;
    _centre(width, height, (x, row) {
      final yi = row * rowStride + x;
      final ci = chroma + (row ~/ 2) * rowStride + (x ~/ 2) * 2;
      if (ci + 1 >= bytes.length) return;
      sum.addYuv(bytes[yi], bytes[ci + 1], bytes[ci]);
    });
    return sum.colour;
  }

  /// Centre of a BGRA frame (iPhone).
  static FrameColour fromBgra({
    required int width,
    required int height,
    required Uint8List bytes,
    required int rowStride,
  }) {
    final sum = _Sum();
    _centre(width, height, (x, row) {
      final i = row * rowStride + x * 4;
      if (i + 2 >= bytes.length) return;
      sum.addRgb(bytes[i + 2].toDouble(), bytes[i + 1].toDouble());
    });
    return sum.colour;
  }

  /// Visits about 40 by 40 points of the central half of the frame.
  static void _centre(int width, int height, void Function(int x, int y) visit) {
    final x0 = width ~/ 4, y0 = height ~/ 4;
    final w = width ~/ 2, h = height ~/ 2;
    final sx = math.max(1, w ~/ 40), sy = math.max(1, h ~/ 40);
    for (var row = y0; row < y0 + h; row += sy) {
      for (var x = x0; x < x0 + w; x += sx) {
        visit(x, row);
      }
    }
  }
}

class _Sum {
  double red = 0, green = 0;
  int n = 0;

  // full-range BT.601, the camera's YUV
  void addYuv(int y, int u, int v) {
    final cb = u - 128.0, cr = v - 128.0;
    addRgb(_clamp(y + 1.402 * cr), _clamp(y - 0.344136 * cb - 0.714136 * cr));
  }

  void addRgb(double r, double g) {
    red += r;
    green += g;
    n++;
  }

  FrameColour get colour => n == 0 ? const FrameColour(0, 0) : FrameColour(red / n, green / n);

  static double _clamp(double v) => v < 0 ? 0 : (v > 255 ? 255 : v);
}

/// A pulse found in a camera signal.
class PulseEstimate {
  final int bpm;

  /// Share of the signal power at the pulse frequency and its first
  /// harmonic, from 0 to 1. Noise alone stays near 0.1; a clean pulse is
  /// well above [PulseAnalysis.minQuality].
  final double quality;

  /// Beats counted in the signal.
  final int beats;

  const PulseEstimate({required this.bpm, required this.quality, required this.beats});
}

/// From a brightness signal to a pulse, or to nothing when the signal is
/// not clean enough. Two estimates must agree: the dominant frequency of
/// the spectrum and the median interval between the beats; the beats must
/// also be regular. An irregular rhythm or a moving finger gives no value
/// rather than a wrong one.
abstract final class PulseAnalysis {
  /// Samples per second after resampling (the camera's frames arrive at
  /// about 30 per second, not exactly evenly).
  static const double rate = 30;

  /// Band of the pulse: 36 to 216 beats per minute.
  static const double lowHz = 0.6, highHz = 3.6;

  static const double minQuality = 0.4;
  static const double minSeconds = 15;

  static PulseEstimate? estimate(List<int> tMicros, List<double> values) {
    if (tMicros.length < 2 || tMicros.length != values.length) return null;
    if ((tMicros.last - tMicros.first) / 1e6 < minSeconds) return null;
    // more blood, less light: inverted, each beat is a peak
    final y = bandPass(resample(tMicros, [for (final v in values) -v]));
    final (hz, quality) = dominant(y);
    if (quality < minQuality) return null;

    final peaks = beats(y, hz);
    if (peaks.length < 6) return null;
    final gaps = [for (var i = 1; i < peaks.length; i++) (peaks[i] - peaks[i - 1]).toDouble()];
    final mid = _median(gaps);
    final regular = gaps.where((g) => (g - mid).abs() <= 0.25 * mid).length / gaps.length;
    if (regular < 0.8) return null;

    final spectral = hz * 60, counted = 60 * rate / mid;
    if ((spectral - counted).abs() > math.max(4, 0.07 * spectral)) return null;
    return PulseEstimate(bpm: spectral.round(), quality: quality, beats: peaks.length);
  }

  /// Even samples at [rate] per second, by linear interpolation.
  static List<double> resample(List<int> tMicros, List<double> x) {
    final t0 = tMicros.first;
    final n = ((tMicros.last - t0) / 1e6 * rate).floor() + 1;
    final out = List<double>.filled(n, 0);
    var j = 0;
    for (var i = 0; i < n; i++) {
      final t = t0 + i * 1e6 / rate;
      while (j < tMicros.length - 2 && tMicros[j + 1] < t) {
        j++;
      }
      final ta = tMicros[j], tb = tMicros[j + 1];
      final w = tb == ta ? 0.0 : ((t - ta) / (tb - ta)).clamp(0.0, 1.0);
      out[i] = x[j] + w * (x[j + 1] - x[j]);
    }
    return out;
  }

  /// Keeps the band of the pulse: removes the slow drift (breathing,
  /// pressure of the finger, exposure) and the fast noise. Zero phase.
  static List<double> bandPass(List<double> x) {
    final n = x.length;
    final mean = x.reduce((a, b) => a + b) / n;
    var y = [for (final v in x) v - mean];
    y = _filtfilt(y, _Biquad.highPass(lowHz, rate));
    return _filtfilt(y, _Biquad.lowPass(highHz, rate));
  }

  /// Frequency of the largest peak of the spectrum in the pulse band, in
  /// hertz, and the share of the band's power around it and its harmonic.
  static (double, double) dominant(List<double> y) {
    const step = 0.01;
    final n = y.length;
    final w = [for (var i = 0; i < n; i++) y[i] * (0.5 - 0.5 * math.cos(2 * math.pi * i / (n - 1)))];
    final freqs = <double>[];
    final power = <double>[];
    for (var f = lowHz; f <= highHz + 1e-9; f += step) {
      // a rotating phasor instead of a sine and a cosine per sample
      final c = math.cos(2 * math.pi * f / rate), s = math.sin(2 * math.pi * f / rate);
      var re = 0.0, im = 0.0, xr = 1.0, xi = 0.0;
      for (var i = 0; i < n; i++) {
        re += w[i] * xr;
        im -= w[i] * xi;
        final nr = xr * c - xi * s;
        xi = xr * s + xi * c;
        xr = nr;
      }
      freqs.add(f);
      power.add(re * re + im * im);
    }
    var k = 0;
    for (var i = 1; i < power.length; i++) {
      if (power[i] > power[k]) k = i;
    }
    var hz = freqs[k];
    if (k > 0 && k < power.length - 1) {
      final a = power[k - 1], b = power[k], c = power[k + 1];
      final d = a - 2 * b + c;
      if (d != 0) hz += step * 0.5 * (a - c) / d;
    }
    var near = 0.0, total = 0.0;
    for (var i = 0; i < power.length; i++) {
      total += power[i];
      if ((freqs[i] - hz).abs() <= 0.1 || (freqs[i] - 2 * hz).abs() <= 0.1) near += power[i];
    }
    return (hz, total == 0 ? 0.0 : near / total);
  }

  /// Positions of the beats: the highest peaks at least 60 % of the
  /// expected interval apart.
  static List<int> beats(List<double> y, double hz) {
    final gap = (0.6 * rate / hz).floor();
    final maxima = <int>[
      for (var i = 1; i < y.length - 1; i++)
        if (y[i] > 0 && y[i] > y[i - 1] && y[i] >= y[i + 1]) i,
    ]..sort((a, b) => y[b].compareTo(y[a]));
    final kept = <int>[];
    for (final i in maxima) {
      if (kept.every((j) => (i - j).abs() >= gap)) kept.add(i);
    }
    return kept..sort();
  }

  static List<double> _filtfilt(List<double> x, _Biquad f) {
    final n = x.length;
    final pad = math.min(n - 1, (3 * rate).round());
    // odd extension at both ends, so the filter starts without a jump
    final ext = [
      for (var i = pad; i >= 1; i--) 2 * x[0] - x[i],
      ...x,
      for (var i = n - 2; i >= n - 1 - pad; i--) 2 * x[n - 1] - x[i],
    ];
    final once = f.run(ext);
    final twice = f.run(once.reversed.toList()).reversed.toList();
    return twice.sublist(pad, pad + n);
  }

  static double _median(List<double> v) {
    final s = [...v]..sort();
    final m = s.length ~/ 2;
    return s.length.isOdd ? s[m] : (s[m - 1] + s[m]) / 2;
  }
}

/// Second-order Butterworth section (audio EQ cookbook).
class _Biquad {
  final double b0, b1, b2, a1, a2;
  const _Biquad(this.b0, this.b1, this.b2, this.a1, this.a2);

  factory _Biquad.lowPass(double hz, double rate) {
    final w = 2 * math.pi * hz / rate, cw = math.cos(w), alpha = math.sin(w) / math.sqrt2;
    final a0 = 1 + alpha;
    return _Biquad((1 - cw) / 2 / a0, (1 - cw) / a0, (1 - cw) / 2 / a0, -2 * cw / a0, (1 - alpha) / a0);
  }

  factory _Biquad.highPass(double hz, double rate) {
    final w = 2 * math.pi * hz / rate, cw = math.cos(w), alpha = math.sin(w) / math.sqrt2;
    final a0 = 1 + alpha;
    return _Biquad((1 + cw) / 2 / a0, -(1 + cw) / a0, (1 + cw) / 2 / a0, -2 * cw / a0, (1 - alpha) / a0);
  }

  List<double> run(List<double> x) {
    var z1 = 0.0, z2 = 0.0;
    return [
      for (final v in x)
        () {
          final out = b0 * v + z1;
          z1 = b1 * v - a1 * out + z2;
          z2 = b2 * v - a2 * out;
          return out;
        }(),
    ];
  }
}

enum PulsePhase {
  /// No finger on the lens yet.
  waiting,

  /// Finger on the lens; the first seconds are left out while the
  /// exposure settles and the finger finds its place.
  settling,
  measuring,
  done,

  /// Measured, but the signal was not clean enough to give a value.
  failed,
}

/// Follows a measurement frame by frame: waits for the finger, lets the
/// signal settle, records [measure] of it, then analyses it. The finger
/// lifted for more than [liftTolerance] starts it again.
class PulseMeter {
  static const Duration settle = Duration(seconds: 3);
  static const Duration measure = Duration(seconds: 20);
  static const Duration liftTolerance = Duration(milliseconds: 600);

  /// Points of the live trace: 4 seconds at 30 frames per second.
  static const int traceLength = 120;

  PulsePhase _phase = PulsePhase.waiting;
  PulseEstimate? _result;
  bool _interrupted = false;
  int _since = 0, _last = 0;
  int? _offSince;
  final _t = <int>[];
  final _red = <double>[];
  final _green = <double>[];
  final _trace = <double>[];

  PulsePhase get phase => _phase;

  /// The pulse, once [phase] is done.
  PulseEstimate? get result => _result;

  /// The finger moved away during a measurement, which starts again.
  bool get interrupted => _interrupted;

  /// From 0 to 1 while measuring.
  double get progress => switch (_phase) {
    PulsePhase.measuring => ((_last - _since) / measure.inMicroseconds).clamp(0.0, 1.0),
    PulsePhase.done || PulsePhase.failed => 1.0,
    _ => 0.0,
  };

  /// Whole seconds left while measuring.
  int get secondsLeft => ((1 - progress) * measure.inSeconds).ceil();

  /// The latest brightness changes, beats upward, for display.
  List<double> get trace => List.unmodifiable(_trace);

  /// One frame, at [tMicros] on a steady clock.
  void add(int tMicros, FrameColour c) {
    if (_phase == PulsePhase.done || _phase == PulsePhase.failed) return;
    _last = tMicros;
    if (!c.fingerOn) {
      _offSince ??= tMicros;
      if (_phase != PulsePhase.waiting && tMicros - _offSince! >= liftTolerance.inMicroseconds) {
        _interrupted = _interrupted || _phase == PulsePhase.measuring;
        _clear();
      }
      return;
    }
    _offSince = null;
    if (_phase == PulsePhase.waiting) {
      _phase = PulsePhase.settling;
      _since = tMicros;
    } else if (_phase == PulsePhase.settling) {
      if (tMicros - _since >= settle.inMicroseconds) {
        _phase = PulsePhase.measuring;
        _interrupted = false;
        _since = tMicros;
        _record(tMicros, c);
      }
    } else {
      _record(tMicros, c);
      if (tMicros - _since >= measure.inMicroseconds) _finish();
    }
  }

  /// A new measurement.
  void restart() {
    _clear();
    _interrupted = false;
    _result = null;
  }

  void _clear() {
    _phase = PulsePhase.waiting;
    _offSince = null;
    _t.clear();
    _red.clear();
    _green.clear();
    _trace.clear();
  }

  void _record(int t, FrameColour c) {
    _t.add(t);
    _red.add(c.red);
    _green.add(c.green);
    final recent = _red.length < 15 ? _red : _red.sublist(_red.length - 15);
    final mean = recent.reduce((a, b) => a + b) / recent.length;
    _trace.add(mean - c.red);
    if (_trace.length > traceLength) _trace.removeAt(0);
  }

  void _finish() {
    // the red channel carries the pulse, unless the flash saturates it
    final red = PulseAnalysis.estimate(_t, _red);
    final green = PulseAnalysis.estimate(_t, _green);
    _result = red == null ? green : (green == null || red.quality >= green.quality ? red : green);
    _phase = _result == null ? PulsePhase.failed : PulsePhase.done;
  }
}
