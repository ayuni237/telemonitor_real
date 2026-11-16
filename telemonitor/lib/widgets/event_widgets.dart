import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/clinical_event.dart';
import '../models/risk_assessment.dart';
import '../services/clinician_queue.dart';
import '../services/queue_logic.dart';
import '../theme/app_theme.dart';
import 'verdict_sheet.dart';
import '../l10n/l10n.dart';

String _date(DateTime t) => DateFormat('d MMM HH:mm').format(t);

/// The triggering fact, with units and context.
String describeTrigger(ClinicalEvent e) {
  final t = e.trigger;
  if (e.source == TriggerSource.nonTransmission) {
    final last = t['lastReadingAt'];
    final days = t['checkupPeriodDays'];
    final l10n = l10nNow;
    final period = days == null ? '' : l10n.checkupPeriodSuffix((days as num).toInt());
    return last is Timestamp
        ? l10n.noReadingSince(_date(last.toDate()), period)
        : days == null
            ? l10n.noReadingInPeriod
            : l10n.noReadingForDays((days as num).toInt());
  }
  if (t['profile'] == 'bp_7d') {
    return l10nNow.bpProfileOff('${(t['meanSbp'] as num?)?.round()}', '${(t['meanDbp'] as num?)?.round()}',
        '${t['readings']}', '${t['days']}');
  }
  if (t['profile'] == 'glucose_6pt') {
    return l10nNow.glucoseProfileOff('${t['meanBeforeMeal'] ?? '—'}', '${t['meanAfterMeal'] ?? '—'}');
  }
  final parts = <String>[
    if (t['sbp'] != null) '${t['sbp']}/${t['dbp']} mmHg',
    if (t['hr'] != null) l10nNow.triggerPulse('${t['hr']}'),
    if (t['glucose'] != null) l10nNow.triggerGlucose('${t['glucose']}'),
  ];
  final ctx = (t['context'] as String?) ?? '';
  return '${parts.join(' · ')}${ctx.isEmpty ? '' : ' (${l10nNow.readingContextShort(ctx)})'}';
}

String trendLabel(TrendDirection d) => switch (d) {
      TrendDirection.rising => l10nNow.trendRising,
      TrendDirection.falling => l10nNow.trendFalling,
      TrendDirection.stable => l10nNow.stable,
      TrendDirection.unknown => l10nNow.trendTooFew,
    };

(Color, Color) tierColors(BuildContext context, RiskTier t) => switch (t) {
      RiskTier.red => (AppColors.dangerText(context), AppColors.dangerBg(context)),
      RiskTier.yellow => (AppColors.warningText(context), AppColors.warningBg(context)),
      RiskTier.green => (AppColors.successText(context), AppColors.successBg(context)),
    };

Widget tierChip(BuildContext context, String text, RiskTier t) {
  final (fg, bg) = tierColors(context, t);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
    child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
  );
}

Widget _sourceChip(BuildContext context, TriggerSource s) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.field(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: Text(s.label, style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context))),
    );

Widget _escalatedChip(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: AppColors.dangerBg(context), borderRadius: BorderRadius.circular(20)),
      child: Text(context.l10n.escalated,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.dangerText(context))),
    );

/// Level, source and escalation chips (wrapping on narrow screens), and the
/// time the event was raised.
Widget _header(BuildContext context, ClinicalEvent e, TextStyle muted) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Wrap(spacing: 6, runSpacing: 6, children: [
            tierChip(context, context.l10n.homeLevel(e.tier.index).toUpperCase(), e.tier),
            _sourceChip(context, e.source),
            if (e.isEscalated) _escalatedChip(context),
          ]),
        ),
        const SizedBox(width: 8),
        Padding(padding: const EdgeInsets.only(top: 3), child: Text(_date(e.triggeredAt), style: muted)),
      ],
    );

/// A queue row: everything needed for a triage decision without opening
/// the record (thesis ch.4, Table "Content of a queue row").
class QueueRow extends StatelessWidget {
  final QueueItem item;
  final VoidCallback onOpen;
  const QueueRow({super.key, required this.item, required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final e = item.event;
    final muted = TextStyle(fontSize: 11, color: AppColors.textSecondary(context));
    final sinceReview = item.lastReviewedAt == null
        ? context.l10n.neverReviewed
        : context.l10n.daysSinceReview(DateTime.now().difference(item.lastReviewedAt!).inDays);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _header(context, e, muted),
              const SizedBox(height: 8),
              Text(describeTrigger(e),
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryText(context))),
              const SizedBox(height: 4),
              if (item.isForeign)
                Text(context.l10n.escalatedToYou, style: muted)
              else ...[
                Text(
                    context.l10n.trendLine(trendLabel(item.sbpTrend), trendLabel(item.glucoseTrend)),
                    style: muted),
                Text(
                    '${pseudonymOf(item.patient.uid)} · ${ageBand(item.patient.age)} · $sinceReview',
                    style: muted),
              ],
              Text(
                  context.l10n.thresholdsLine(e.thresholdVersion) +
                      (e.modelVersion == null ? '' : context.l10n.modelSuffix(e.modelVersion!)) +
                      (e.score == null ? '' : context.l10n.probabilitySuffix((e.score! * 100).toStringAsFixed(0))),
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted(context))),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                  onPressed: () => showVerdictSheet(context, e),
                  child: Text(context.l10n.verdict),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The event record of one patient, newest first, with the verdict of each
/// closed event and a verdict button on open ones.
class EventLogTile extends StatelessWidget {
  final ClinicalEvent event;
  const EventLogTile({super.key, required this.event});

  @override
  Widget build(BuildContext context) {
    final e = event;
    final muted = TextStyle(fontSize: 11, color: AppColors.textSecondary(context));
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, e, muted),
          const SizedBox(height: 6),
          Text(describeTrigger(e), style: TextStyle(fontSize: 13, color: AppColors.primaryText(context))),
          const SizedBox(height: 4),
          if (e.isOpen)
            Row(children: [
              Text(context.l10n.eventOpen, style: muted.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(onPressed: () => showVerdictSheet(context, e), child: Text(context.l10n.verdict)),
            ])
          else
            Text(
              '${e.verdict?.label ?? '—'} · ${e.action?.label ?? '—'}'
              '${e.reviewedAt == null ? '' : context.l10n.reviewedSuffix(_date(e.reviewedAt!))}'
              '${e.comment.isEmpty ? '' : '\n${e.comment}'}',
              style: muted,
            ),
        ],
      ),
    );
  }
}
