import 'package:flutter/material.dart';

import '../models/reading.dart';
import '../services/home_protocol.dart';
import '../theme/app_theme.dart';

/// The verification profile of the yellow level (thesis ch.4, Table
/// "tab:thresholds", Figure "two-stage triage"): an isolated reading above
/// the home target leads to more readings, and only the mean of the profile
/// reaches a clinical decision. Shows what to measure, the progress and the
/// result. Nothing when no profile is running or recently finished.
class ProfileCard extends StatelessWidget {
  final List<Reading> readings;
  final bool forClinician;

  /// For tests; the current time otherwise.
  final DateTime? now;

  const ProfileCard({super.key, required this.readings, this.forClinician = false, this.now});

  String _date(DateTime t) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${t.day} ${months[t.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final profiles = VerificationProfile.active(readings, now ?? DateTime.now());
    if (profiles.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      for (final p in profiles) ...[_card(context, p), const SizedBox(height: 20)],
    ]);
  }

  Widget _card(BuildContext context, ProfileResult p) {
    final bp = p.kind == ProfileKind.bloodPressure;
    final done = p.status == ProfileStatus.complete;
    final off = done && p.offTarget == true;
    final (Color fg, Color bg) = switch (p.status) {
      ProfileStatus.complete when off => (AppColors.dangerText(context), AppColors.dangerBg(context)),
      ProfileStatus.complete => (AppColors.successText(context), AppColors.successBg(context)),
      ProfileStatus.incomplete => (AppColors.warningText(context), AppColors.warningBg(context)),
      ProfileStatus.inProgress => (AppColors.primaryText(context), AppColors.tint(context)),
    };
    final title = bp ? '7-day blood pressure check' : 'One-day glucose check';
    final how = bp
        ? 'Every morning and every evening for 7 days: sit and rest 5 minutes, then take two readings '
            'one minute apart and log both.'
        : 'During one day: before and 90 minutes after each of your three meals (6 readings). '
            'Choose "Before meal" or "After meal" when you log each one.';
    final progress = bp
        ? '${p.readings} of ${p.expected} readings · ${p.days} day${p.days == 1 ? '' : 's'} · until ${_date(p.end)}'
        : 'Before meals: ${p.beforeMeal} of 3 · after meals: ${p.afterMeal} of 3 · until ${_date(p.end)}';
    final mean = bp
        ? (p.meanSbp == null ? null : 'Average ${p.meanSbp!.round()}/${p.meanDbp!.round()} mmHg (target below 135/85)')
        : [
            if (p.meanBeforeMeal != null)
              'before meals: ${p.meanBeforeMeal!.toStringAsFixed(1)} mmol/L (target 7 or less)',
            if (p.meanAfterMeal != null)
              'after meals: ${p.meanAfterMeal!.toStringAsFixed(1)} mmol/L (target 10 or less)',
          ].fold<String?>(null, (acc, x) => acc == null ? 'Average $x' : '$acc; $x');
    final result = switch (p.status) {
      ProfileStatus.inProgress => forClinician ? 'In progress.' : how,
      ProfileStatus.complete when off => forClinician
          ? 'Off target: teleconsultation (red event in the queue).'
          : 'Your average is above the target. Your clinician has the result; contact your health centre.',
      ProfileStatus.complete => forClinician ? 'On target.' : 'Your average is on target. Keep measuring as usual.',
      ProfileStatus.incomplete => forClinician
          ? 'Incomplete: too few readings to conclude.'
          : 'Not enough readings to conclude. Contact your health centre or start the check again.',
    };
    final value = done ? 1.0 : (p.readings / p.expected).clamp(0.0, 1.0);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: fg.withValues(alpha: 0.35), width: 0.8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(bp ? Icons.favorite_outline : Icons.water_drop_outlined, size: 18, color: fg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryText(context))),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
              child: Text(
                switch (p.status) {
                  ProfileStatus.inProgress => 'In progress',
                  ProfileStatus.complete => off ? 'Above target' : 'On target',
                  ProfileStatus.incomplete => 'Incomplete',
                },
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: AppColors.field(context),
              valueColor: AlwaysStoppedAnimation<Color>(fg),
            ),
          ),
          const SizedBox(height: 8),
          Text(progress, style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
          if (mean != null) ...[
            const SizedBox(height: 4),
            Text(mean,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
          ],
          const SizedBox(height: 8),
          Text(result, style: TextStyle(fontSize: 13, color: done || p.status == ProfileStatus.incomplete ? fg : AppColors.textPrimary(context), height: 1.4)),
        ],
      ),
    );
  }
}
