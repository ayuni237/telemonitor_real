import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/clinical_event.dart';
import '../services/auth_service.dart';
import '../services/events_service.dart';
import '../theme/app_theme.dart';
import '../l10n/l10n.dart';

/// The outcome of the clinician's reviews, shown to the patient (thesis ch.4,
/// Table "Application profiles": the patient views the outcome of clinician
/// decisions; Table "Behaviour change techniques": the clinician's decision
/// relayed to the patient). The patient sees the action taken and the
/// clinician's comment, not the verdict code. Nothing before the first review.
class ClinicianReviewsCard extends StatefulWidget {
  const ClinicianReviewsCard({super.key});

  @override
  State<ClinicianReviewsCard> createState() => _ClinicianReviewsCardState();
}

class _ClinicianReviewsCardState extends State<ClinicianReviewsCard> {
  /// Created once, so a rebuild of the dashboard does not resubscribe.
  Stream<List<ClinicalEvent>>? _stream;

  @override
  void initState() {
    super.initState();
    final me = AuthService.instance.currentProfile;
    if (me == null) return;
    try {
      _stream = EventsService.instance.watch(me.uid, limit: 30);
    } catch (_) {
      _stream = null; // no database (screen tests)
    }
  }

  static String actionText(AppLocalizations l10n, ClinicalAction? a) => switch (a) {
        ClinicalAction.none => l10n.actionNone,
        ClinicalAction.advice => l10n.actionAdvice,
        ClinicalAction.treatmentChange => l10n.actionTreatmentChange,
        ClinicalAction.consultation => l10n.actionConsultation,
        ClinicalAction.referral => l10n.actionReferral,
        null => l10n.reviewed,
      };

  String _date(DateTime t) => DateFormat('d MMM').format(t);

  @override
  Widget build(BuildContext context) {
    final stream = _stream;
    if (stream == null) return const SizedBox.shrink();
    return StreamBuilder<List<ClinicalEvent>>(
      stream: stream,
      builder: (context, snap) {
        final reviewed = (snap.data ?? const <ClinicalEvent>[])
            .where((e) => !e.isOpen && e.reviewedAt != null)
            .take(3)
            .toList();
        if (reviewed.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.card(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border(context), width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.medical_services_outlined, size: 18, color: AppColors.primaryText(context)),
                  const SizedBox(width: 8),
                  Text(context.l10n.fromYourClinician,
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryText(context))),
                ]),
                for (final e in reviewed) ...[
                  const SizedBox(height: 10),
                  Text(actionText(context.l10n, e.action),
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
                  Text(context.l10n.alertReviewed(_date(e.triggeredAt), _date(e.reviewedAt!)),
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context))),
                  if (e.comment.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text('"${e.comment}"',
                          style: TextStyle(fontSize: 13, color: AppColors.textPrimary(context), height: 1.4)),
                    ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
