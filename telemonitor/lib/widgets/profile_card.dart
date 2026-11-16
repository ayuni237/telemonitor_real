import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/reading.dart';
import '../services/home_protocol.dart';
import '../theme/app_theme.dart';
import '../l10n/l10n.dart';

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

  String _date(BuildContext context, DateTime t) => DateFormat('d MMM').format(t);

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
    final l10n = context.l10n;
    final title = bp ? l10n.bpCheckTitle : l10n.glucoseCheckTitle;
    final how = bp ? l10n.bpCheckHow : l10n.glucoseCheckHow;
    final progress = bp
        ? l10n.bpCheckProgress(p.readings, p.expected, l10n.periodDays(p.days), _date(context, p.end))
        : l10n.glucoseCheckProgress(p.beforeMeal, p.afterMeal, _date(context, p.end));
    final mean = bp
        ? (p.meanSbp == null ? null : l10n.bpCheckMean('${p.meanSbp!.round()}/${p.meanDbp!.round()}'))
        : [
            if (p.meanBeforeMeal != null) l10n.meanBeforeMeals(p.meanBeforeMeal!.toStringAsFixed(1)),
            if (p.meanAfterMeal != null) l10n.meanAfterMeals(p.meanAfterMeal!.toStringAsFixed(1)),
          ].fold<String?>(null, (acc, x) => acc == null ? l10n.averageOf(x) : l10n.joinedBySemicolon(acc, x));
    final result = switch (p.status) {
      ProfileStatus.inProgress => forClinician ? l10n.checkInProgressClinician : how,
      ProfileStatus.complete when off => forClinician ? l10n.checkOffTargetClinician : l10n.checkOffTargetPatient,
      ProfileStatus.complete => forClinician ? l10n.checkOnTargetClinician : l10n.checkOnTargetPatient,
      ProfileStatus.incomplete => forClinician ? l10n.checkIncompleteClinician : l10n.checkIncompletePatient,
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
                  ProfileStatus.inProgress => context.l10n.inProgress,
                  ProfileStatus.complete => off ? context.l10n.aboveTarget : context.l10n.onTarget,
                  ProfileStatus.incomplete => context.l10n.incomplete,
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
