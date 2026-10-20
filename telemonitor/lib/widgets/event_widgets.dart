import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/clinical_event.dart';
import '../models/risk_assessment.dart';
import '../services/clinician_queue.dart';
import '../services/queue_logic.dart';
import '../theme/app_theme.dart';
import 'verdict_sheet.dart';

String _date(DateTime t) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${t.day} ${months[t.month - 1]} ${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
}

/// The triggering fact, with units and context.
String describeTrigger(ClinicalEvent e) {
  final t = e.trigger;
  if (e.source == TriggerSource.nonTransmission) {
    final last = t['lastReadingAt'];
    final when = last is Timestamp ? _date(last.toDate()) : 'unknown';
    return 'No reading since $when (checkup period ${t['checkupPeriodDays'] ?? '?'} days)';
  }
  final parts = <String>[
    if (t['sbp'] != null) '${t['sbp']}/${t['dbp']} mmHg',
    if (t['hr'] != null) 'pulse ${t['hr']} bpm',
    if (t['glucose'] != null) 'glucose ${t['glucose']} mmol/L',
  ];
  final ctx = (t['context'] as String?) ?? '';
  return '${parts.join(' · ')}${ctx.isEmpty ? '' : ' ($ctx)'}';
}

String trendLabel(TrendDirection d) => switch (d) {
      TrendDirection.rising => 'rising',
      TrendDirection.falling => 'falling',
      TrendDirection.stable => 'stable',
      TrendDirection.unknown => 'too few readings',
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
        ? 'never reviewed'
        : '${DateTime.now().difference(item.lastReviewedAt!).inDays} d since last review';
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
              Row(children: [
                tierChip(context, e.tier.name.toUpperCase(), e.tier),
                const SizedBox(width: 6),
                _sourceChip(context, e.source),
                const Spacer(),
                Text(_date(e.triggeredAt), style: muted),
              ]),
              const SizedBox(height: 8),
              Text(describeTrigger(e),
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryText(context))),
              const SizedBox(height: 4),
              Text(
                  '14-day trend: systolic ${trendLabel(item.sbpTrend)}, glucose ${trendLabel(item.glucoseTrend)}',
                  style: muted),
              Text(
                  '${pseudonymOf(item.patient.uid)} · ${ageBand(item.patient.age)} · $sinceReview',
                  style: muted),
              Text(
                  'Thresholds ${e.thresholdVersion}${e.modelVersion == null ? '' : ' · model ${e.modelVersion}'}'
                  '${e.score == null ? '' : ' · calibrated P(alert) ${(e.score! * 100).toStringAsFixed(0)}%'}',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted(context))),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => showVerdictSheet(context, e),
                  child: const Text('Verdict'),
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
          Row(children: [
            tierChip(context, e.tier.name.toUpperCase(), e.tier),
            const SizedBox(width: 6),
            _sourceChip(context, e.source),
            const Spacer(),
            Text(_date(e.triggeredAt), style: muted),
          ]),
          const SizedBox(height: 6),
          Text(describeTrigger(e), style: TextStyle(fontSize: 13, color: AppColors.primaryText(context))),
          const SizedBox(height: 4),
          if (e.isOpen)
            Row(children: [
              Text('Open', style: muted.copyWith(fontWeight: FontWeight.w600)),
              const Spacer(),
              TextButton(onPressed: () => showVerdictSheet(context, e), child: const Text('Verdict')),
            ])
          else
            Text(
              '${e.verdict?.label ?? '—'} · ${e.action?.label ?? '—'}'
              '${e.reviewedAt == null ? '' : ' · reviewed ${_date(e.reviewedAt!)}'}'
              '${e.comment.isEmpty ? '' : '\n${e.comment}'}',
              style: muted,
            ),
        ],
      ),
    );
  }
}
