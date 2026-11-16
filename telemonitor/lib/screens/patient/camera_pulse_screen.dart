import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../services/camera_pulse.dart';
import '../../services/home_protocol.dart';
import '../../theme/app_theme.dart';
import '../../l10n/l10n.dart';

/// Measures the pulse with the back camera and its flash (camera_pulse.dart).
/// Returns the [PulseEstimate] the patient chose to keep, or null.
///
/// The frames are read in memory and dropped at once: no picture or video
/// is kept or sent, only the pulse found in them.
class CameraPulseScreen extends StatefulWidget {
  const CameraPulseScreen({super.key});

  /// Android and iOS phones; not the web and desktop versions.
  static bool get supported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  @override
  State<CameraPulseScreen> createState() => _CameraPulseScreenState();
}

class _CameraPulseScreenState extends State<CameraPulseScreen> with WidgetsBindingObserver {
  CameraController? _camera;
  final _meter = PulseMeter();
  final _clock = Stopwatch()..start();
  String? _error;
  bool _noFlash = false;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      // the permission prompt also makes the app inactive: keep a camera
      // that is still starting
      final c = _camera;
      if (c != null && c.value.isInitialized) {
        _stop();
        if (!_finished) _meter.restart();
      }
    } else if (state == AppLifecycleState.resumed && _camera == null && _error == null && !_finished) {
      _start();
    }
  }

  bool get _finished => _meter.phase == PulsePhase.done || _meter.phase == PulsePhase.failed;

  Future<void> _start() async {
    if (_starting) return;
    _starting = true;
    try {
      final back = (await availableCameras()).where((c) => c.lensDirection == CameraLensDirection.back);
      if (back.isEmpty) {
        if (mounted) setState(() => _error = l10nNow.noBackCamera);
        return;
      }
      final camera = CameraController(
        back.first,
        ResolutionPreset.low,
        enableAudio: false,
        fps: 30,
        imageFormatGroup: defaultTargetPlatform == TargetPlatform.iOS
            ? ImageFormatGroup.bgra8888
            : ImageFormatGroup.yuv420,
      );
      _camera = camera;
      await camera.initialize();
      if (!mounted || _camera != camera) {
        await camera.dispose();
        return;
      }
      try {
        await camera.setFlashMode(FlashMode.torch);
      } on CameraException {
        _noFlash = true;
      }
      await camera.startImageStream(_onFrame);
      if (mounted) setState(() {});
    } on CameraException catch (e) {
      await _stop();
      if (mounted) setState(() => _error = _message(e));
    } catch (e) {
      await _stop();
      if (mounted) setState(() => _error = l10nNow.cameraNotStarted('$e'));
    } finally {
      _starting = false;
    }
  }

  Future<void> _stop() async {
    final c = _camera;
    _camera = null;
    if (c == null) return;
    try {
      if (c.value.isStreamingImages) await c.stopImageStream();
      if (c.value.isInitialized) await c.setFlashMode(FlashMode.off);
    } catch (_) {
      // the camera is released below in any case
    }
    await c.dispose();
  }

  void _onFrame(CameraImage image) {
    final colour = _colourOf(image);
    if (colour == null || !mounted) return;
    _meter.add(_clock.elapsedMicroseconds, colour);
    // the flash goes off as soon as the measurement ends
    if (_finished) _stop();
    setState(() {});
  }

  static FrameColour? _colourOf(CameraImage image) {
    final p = image.planes;
    switch (image.format.group) {
      case ImageFormatGroup.bgra8888:
        return FrameColour.fromBgra(
          width: image.width,
          height: image.height,
          bytes: p[0].bytes,
          rowStride: p[0].bytesPerRow,
        );
      case ImageFormatGroup.nv21:
        return FrameColour.fromNv21(
          width: image.width,
          height: image.height,
          bytes: p[0].bytes,
          rowStride: p[0].bytesPerRow,
        );
      case ImageFormatGroup.yuv420 when p.length >= 2:
        // three planes on Android; two on iPhone, with U and V interleaved
        final three = p.length >= 3;
        return FrameColour.fromYuv(
          width: image.width,
          height: image.height,
          y: p[0].bytes,
          yRowStride: p[0].bytesPerRow,
          u: p[1].bytes,
          v: three ? p[2].bytes : Uint8List.sublistView(p[1].bytes, 1),
          uvRowStride: p[1].bytesPerRow,
          uvPixelStride: p[1].bytesPerPixel ?? (three ? 1 : 2),
        );
      default:
        return null;
    }
  }

  static String _message(CameraException e) => switch (e.code) {
    'CameraAccessDenied' || 'CameraAccessDeniedWithoutPrompt' || 'CameraAccessRestricted' || 'cameraPermission' =>
      l10nNow.cameraNotAllowed,
    _ => l10nNow.cameraNotStartedCode(e.description ?? e.code),
  };

  void _again() {
    setState(() {
      _meter.restart();
      _error = null;
    });
    _start();
  }

  // ---------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final phase = _meter.phase;
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: Text(context.l10n.pulseWithCamera, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            _instructions(),
            const SizedBox(height: 28),
            if (_error != null)
              _errorCard()
            else ...[
              Center(child: _dial(phase)),
              const SizedBox(height: 18),
              if (!_finished)
                Text(
                  _status(phase),
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, height: 1.4, color: AppColors.textPrimary(context)),
                ),
              if (_noFlash && !_finished) ...[
                const SizedBox(height: 8),
                Text(
                  context.l10n.noFlash,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
                ),
              ],
              if (phase == PulsePhase.measuring) ...[
                const SizedBox(height: 20),
                SizedBox(
                  height: 72,
                  child: CustomPaint(painter: _TracePainter(_meter.trace, AppColors.primaryText(context))),
                ),
              ],
              if (phase == PulsePhase.done) _resultCard(_meter.result!),
              if (phase == PulsePhase.failed) _failedCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _instructions() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.tint(context), borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.touch_app_outlined, color: AppColors.primaryText(context), size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              context.l10n.pulseHowTo,
              style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.textSecondary(context)),
            ),
          ),
        ],
      ),
    );
  }

  String _status(PulsePhase phase) => switch (phase) {
    PulsePhase.waiting when _meter.interrupted =>
      context.l10n.pulseFingerMoved,
    PulsePhase.waiting =>
      _camera?.value.isInitialized == true
          ? context.l10n.pulseCover
          : context.l10n.pulseStarting,
    PulsePhase.settling => context.l10n.pulseFingerDetected,
    _ => context.l10n.pulseMeasuring,
  };

  Widget _dial(PulsePhase phase) {
    final c = _camera;
    final live = c != null && c.value.isInitialized;
    Widget centre;
    if (phase == PulsePhase.done) {
      centre = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${_meter.result!.bpm}',
            style: TextStyle(fontSize: 44, fontWeight: FontWeight.w700, color: AppColors.primaryText(context)),
          ),
          Text('bpm', style: TextStyle(fontSize: 13, color: AppColors.textSecondary(context))),
        ],
      );
    } else if (phase == PulsePhase.measuring) {
      centre = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.favorite, size: 28, color: AppColors.primaryText(context)),
          const SizedBox(height: 6),
          Text(
            '${_meter.secondsLeft} s',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600, color: AppColors.primaryText(context)),
          ),
        ],
      );
    } else if (live && !_finished) {
      // what the camera sees: red once the finger covers it
      centre = ClipOval(
        child: SizedBox(
          width: 104,
          height: 104,
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(width: 100, height: 100 * c.value.aspectRatio, child: CameraPreview(c)),
          ),
        ),
      );
    } else {
      centre = Icon(Icons.monitor_heart_outlined, size: 40, color: AppColors.textMuted(context));
    }
    return SizedBox(
      width: 180,
      height: 180,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: _meter.progress,
              strokeWidth: 8,
              backgroundColor: AppColors.border(context),
              color: AppColors.primaryText(context),
            ),
          ),
          centre,
        ],
      ),
    );
  }

  Widget _resultCard(PulseEstimate r) {
    final level = HomeProtocol.pulse(r.bpm);
    final outside = level == HomeProtocol.red;
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.pulseResultNote,
            style: TextStyle(fontSize: 12, height: 1.45, color: AppColors.textSecondary(context)),
          ),
          if (outside) ...[
            const SizedBox(height: 10),
            Text(
              r.bpm <= 40 ? context.l10n.pulseVeryLow : context.l10n.pulseVeryHigh,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary(context),
              ),
            ),
          ],
          const SizedBox(height: 14),
          SizedBox(
            height: 46,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, r),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(context.l10n.useThisValue, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
          TextButton(onPressed: _again, child: Text(context.l10n.measureAgain)),
        ],
      ),
    );
  }

  Widget _failedCard() {
    return _card(
      context.l10n.pulseFailed,
      context.l10n.tryAgain,
    );
  }

  Widget _errorCard() => _card(_error!, context.l10n.tryAgain);

  Widget _card(String text, String action) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(text, style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.textPrimary(context))),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _again, child: Text(action)),
          ),
        ],
      ),
    );
  }
}

/// The latest seconds of the signal, scaled to the height available.
class _TracePainter extends CustomPainter {
  final List<double> trace;
  final Color colour;
  _TracePainter(this.trace, this.colour);

  @override
  void paint(Canvas canvas, Size size) {
    if (trace.length < 2) return;
    var lo = trace.first, hi = trace.first;
    for (final v in trace) {
      if (v < lo) lo = v;
      if (v > hi) hi = v;
    }
    final span = hi - lo < 1e-6 ? 1.0 : hi - lo;
    final dx = size.width / (PulseMeter.traceLength - 1);
    final path = Path();
    for (var i = 0; i < trace.length; i++) {
      final x = i * dx;
      final y = size.height * (1 - (trace[i] - lo) / span);
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = colour
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_TracePainter old) => true;
}
