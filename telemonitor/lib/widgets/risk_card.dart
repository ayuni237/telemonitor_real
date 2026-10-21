import 'package:flutter/material.dart';

import '../models/reading.dart';
import '../models/risk_assessment.dart';
import '../services/clinical_levels.dart';
import '../services/events_service.dart';
import '../services/risk_assessment_service.dart';
import '../theme/app_theme.dart';

/// Shows the risk tier of a patient (green, yellow, red) and where it comes
/// from: the guideline rule on the last readings, raised if needed by the
/// online model (thesis ch.3 §Thresholds and the three levels).
///
/// Self-contained: give it the patient's readings (any order) and, when
/// known, age and sex.
///
/// What each reader sees follows ch.4 §Trends and what the patient sees: the
/// patient sees the tier, the reason and, at yellow or red, the permitted
/// instruction, never a model score or a probability; the clinician also
/// sees the model's calibrated alert probability, with its source.
class RiskCard extends StatefulWidget {
  final List<Reading> readings;
  final int? age;
  final String? sex;

  /// Clinician view: shows the model probabilities. Patient view otherwise.
  final bool forClinician;

  /// Patient view only: when the online model raises the tier, write a model
  /// event for the clinician's queue.
  final bool raiseEvents;

  /// Compact form for the clinician's patient list; full form for the
  /// patient dashboard and patient detail view.
  final bool compact;

  const RiskCard({
    super.key,
    required this.readings,
    this.age,
    this.sex,
    this.forClinician = false,
    this.raiseEvents = false,
    this.compact = false,
  });

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
    if (_signature(oldWidget.readings) != _signature(widget.readings)) _run();
  }

  /// Changes when a reading is added or corrected.
  static String _signature(List<Reading> rs) =>
      '${rs.length}:${rs.map((r) => r.id ?? r.timestamp.toIso8601String()).join(',')}';

  /// Latest reading by measurement time.
  Reading? get _latest => widget.readings.isEmpty
      ? null
      : widget.readings.reduce((a, b) => a.timestamp.isAfter(b.timestamp) ? a : b);

  Future<void> _run() async {
    if (_running) return;
    setState(() => _running = true);
    final result = await RiskAssessmentService.instance
        .assess(widget.readings, age: widget.age, sex: widget.sex);
    if (!mounted) return;
    setState(() {
      _assessment = result;
      _running = false;
    });
    final latest = _latest;
    if (widget.raiseEvents && latest != null) {
      EventsService.instance.raiseModelEvent(latest, result);
    }
  }

  /// The one instruction the patient may receive (ch.4 §Safety boundary):
  /// contact the health centre; seek care now at red. Never a dose.
  static String? patientInstruction(RiskTier t) => switch (t) {
        RiskTier.red => 'Seek care today: go to your health centre or hospital. '
            'If you feel chest pain, breathlessness, weakness or confusion, go now.',
        RiskTier.yellow => 'Contact your health centre and measure again as your '
            'clinician advised.',
        RiskTier.green => null,
      };

  (Color, Color, String) _tierStyle(BuildContext context, RiskTier t) => switch (t) {
        RiskTier.red => (AppColors.dangerText(context), AppColors.dangerBg(context), 'Red'),
        RiskTier.yellow => (AppColors.warningText(context), AppColors.warningBg(context), 'Yellow'),
        RiskTier.green => (AppColors.successText(context), AppColors.successBg(context), 'Green'),
      };

  static const _conditionNames = {'haemodynamic': 'Blood pressure / pulse', 'glycaemic': 'Glucose'};

  @override
  Widget build(BuildContext context) {
    final a = _assessment;
    if (a == null) {
      return _running ? _shell(child: const _Spinner()) : const SizedBox();
    }
    final (fg, bg, label) = _tierStyle(context, a.tier);

    if (widget.compact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Text(a.hasData ? label : 'No data',
            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
      );
    }

    if (!a.hasData) {
      return _shell(
        child: Text('No reading in the last four days — log a reading to see the risk tier.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
      );
    }

    final muted = TextStyle(fontSize: 11, color: AppColors.textSecondary(context));
    return _shell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.insights_outlined, size: 16, color: fg),
            const SizedBox(width: 8),
            Text('Risk tier',
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryText(context))),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
              child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
            ),
          ]),
          const SizedBox(height: 10),
          Text('Guideline rule on the last readings: ${ClinicalLevels.name(a.ruleLevel)}', style: muted),
          if (!widget.forClinician && a.tier.index > a.ruleTier.index) ...[
            const SizedBox(height: 4),
            Text('Your recent readings suggest a higher risk than the last value alone.', style: muted),
          ],
          if (widget.forClinician)
            for (final e in a.conditions.entries) ...[
              const SizedBox(height: 4),
              Text(
                  '${_conditionNames[e.key] ?? e.key}: '
                  '${(e.value.alertProbability * 100).toStringAsFixed(0)}% calibrated probability of a high or '
                  'critical reading at the next measurement (${e.value.tier.name}; ${e.value.model})',
                  style: muted),
            ],
          if (widget.forClinician && a.stateChange != null) ...[
            const SizedBox(height: 4),
            Text(
                'State change, last 24 h against the three days before: '
                '${a.stateChange!.toStringAsFixed(1)} (${a.stateChangeMeasure})',
                style: muted),
          ],
          if (!widget.forClinician && patientInstruction(a.tier) != null) ...[
            const SizedBox(height: 10),
            Text(patientInstruction(a.tier)!,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg)),
          ],
          const SizedBox(height: 8),
          Text(
            a.source == RiskSource.online
                ? (widget.forClinician
                    ? 'Trigger: risk model (online) combined with the guideline rule; the model can raise the tier, never lower it.'
                    : 'Checked with the risk service and the guideline rule.')
                : 'Guideline rule only (${a.offlineReason ?? 'offline'}).',
            style: TextStyle(fontSize: 10, color: AppColors.textMuted(context)),
          ),
          if (widget.forClinician && a.provisionalThresholds)
            Text('Tier cut-points are provisional until set with the clinician.',
                style: TextStyle(fontSize: 10, color: AppColors.textMuted(context))),
        ],
      ),
    );
  }

  Widget _shell({required Widget child}) => Container(
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

class _Spinner extends StatelessWidget {
  const _Spinner();

  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 40,
        child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
      );
}
