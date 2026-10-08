import 'package:flutter/material.dart';

import '../models/reading.dart';
import '../models/risk_assessment.dart';
import '../services/risk_assessment_service.dart';
import '../theme/app_theme.dart';

/// Shows the model's current risk assessment for a set of readings, or
/// an honest explanation of why there isn't one yet.
///
/// Self-contained: give it the patient's readings (most recent first)
/// and it handles running the model, the loading state, and every
/// unavailable case.
class RiskCard extends StatefulWidget {
  final List<Reading> readings;

  /// Compact form for the clinician's patient list; full form for the
  /// patient dashboard and patient detail view.
  final bool compact;

  const RiskCard({super.key, required this.readings, this.compact = false});

  @override
  State<RiskCard> createState() => _RiskCardState();
}

class _RiskCardState extends State<RiskCard> {
  RiskAssessment? _assessment;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void didUpdateWidget(RiskCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-run when the readings actually change — a new reading logged
    // elsewhere should update the score without a manual refresh.
    if (oldWidget.readings.length != widget.readings.length ||
        (widget.readings.isNotEmpty &&
            oldWidget.readings.isNotEmpty &&
            oldWidget.readings.first.timestamp !=
                widget.readings.first.timestamp)) {
      _run();
    }
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() => _running = true);
    final result =
        await RiskAssessmentService.instance.assess(widget.readings);
    if (!mounted) return;
    setState(() {
      _assessment = result;
      _running = false;
    });
  }

  /// Foreground and background for each risk level.
  ///
  /// The hue is constant across themes: red means danger whether the
  /// device is light or dark. Only the background panel darkens, so the
  /// mapping from colour to clinical meaning never shifts.
  (Color, Color) _levelColors(BuildContext context, int level) {
    switch (level) {
      case 0:
        return (AppColors.successText(context), AppColors.successBg(context));
      case 1:
        return (AppColors.warningText(context), AppColors.warningBg(context));
      default:
        return (AppColors.dangerText(context), AppColors.dangerBg(context));
    }
  }

  static const _levelLabels = <int, String>{
    0: 'Stable',
    1: 'Moderate',
    2: 'High',
    3: 'Critical',
  };

  @override
  Widget build(BuildContext context) {
    final a = _assessment;

    if (_running && a == null) {
      return _shell(
        child: const SizedBox(
          height: 40,
          child: Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
      );
    }

    if (a == null) return const SizedBox();

    if (!a.isAvailable) return _unavailable(a);

    final p = a.prediction!;
    final (fg, bg) = _levelColors(context, p.levelIndex);
    final label = _levelLabels[p.levelIndex]!;

    if (widget.compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      );
    }

    return _shell(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.insights_outlined, size: 16, color: fg),
              const SizedBox(width: 8),
              Text(
                'Predicted risk level',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.primaryText(context),
                ),
              ),
              const Spacer(),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                (p.riskScore * 100).toStringAsFixed(0),
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.bold,
                  color: fg,
                  height: 1,
                ),
              ),
              const SizedBox(width: 3),
              Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Text(
                  '% risk score',
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary(context)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Probability of being in a high or critical state, based on '
            'the last 7 readings.',
            style: TextStyle(
                fontSize: 11, color: AppColors.textSecondary(context)),
          ),
          if (a.isLowConfidence) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.warningBg(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline,
                      size: 14, color: AppColors.warningText(context)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Based partly on carried-forward values '
                      '(${(a.completeness * 100).toStringAsFixed(0)}% measured). '
                      'Log ${a.imputedChannels.join(' and ')} more regularly '
                      'for a more reliable score.',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.warningText(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _unavailable(RiskAssessment a) {
    if (widget.compact) {
      return Text(
        a.reason == RiskUnavailableReason.notEnoughReadings
            ? 'Risk: pending'
            : 'Risk: n/a',
        style: TextStyle(fontSize: 10, color: AppColors.textMuted(context)),
      );
    }

    return _shell(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.hourglass_empty,
              size: 16, color: AppColors.textMuted(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Risk score not available yet',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  a.explanation,
                  style: TextStyle(
                      fontSize: 11, color: AppColors.textSecondary(context)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _shell({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: child,
    );
  }
}
