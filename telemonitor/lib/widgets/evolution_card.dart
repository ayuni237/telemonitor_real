import 'package:flutter/material.dart';

import '../models/reading.dart';
import '../services/state_evolution.dart';
import '../theme/app_theme.dart';

/// How each vital sign moved: the last 24 hours against the three days
/// before. Descriptive, not an alert: the colours stay neutral and the risk
/// tier remains the only judgement shown (ch.4 §Trends and what the patient
/// sees). The clinician's risk card adds the state-change distance computed
/// by the risk service.
class EvolutionCard extends StatelessWidget {
  final List<Reading> readings;

  const EvolutionCard({super.key, required this.readings});

  String _fmt(String c, double v) => c == 'glucose' ? v.toStringAsFixed(1) : v.round().toString();

  @override
  Widget build(BuildContext context) {
    final changes = StateEvolution.of(readings);
    final muted = TextStyle(fontSize: 11, color: AppColors.textSecondary(context));
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.compare_arrows, size: 16, color: AppColors.primaryText(context)),
            const SizedBox(width: 8),
            Text('Evolution',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryText(context))),
          ]),
          const SizedBox(height: 4),
          Text('Last 24 hours compared with the three days before', style: muted),
          const SizedBox(height: 10),
          if (changes.isEmpty)
            Text('Not enough readings yet: log readings on several days to see how they change.',
                style: muted)
          else
            for (final ch in changes) _row(context, ch),
        ],
      ),
    );
  }

  Widget _row(BuildContext context, ChannelChange ch) {
    final step = StateEvolution.resolution[ch.channel]!;
    final stable = ch.change.abs() < step;
    final icon = stable ? Icons.trending_flat : (ch.change > 0 ? Icons.trending_up : Icons.trending_down);
    final sign = ch.change > 0 ? '+' : (ch.change < 0 ? '−' : '');
    final unit = StateEvolution.units[ch.channel]!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 18, color: AppColors.primaryText(context)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(StateEvolution.names[ch.channel]!,
              style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context))),
        ),
        Text('${_fmt(ch.channel, ch.current)} $unit',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryText(context))),
        const SizedBox(width: 8),
        SizedBox(
          width: 86,
          child: Text(
            stable ? 'stable' : '$sign${_fmt(ch.channel, ch.change.abs())} $unit',
            textAlign: TextAlign.right,
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary(context)),
          ),
        ),
      ]),
    );
  }
}
