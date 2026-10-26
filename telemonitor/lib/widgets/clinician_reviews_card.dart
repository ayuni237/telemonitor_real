import 'package:flutter/material.dart';

import '../models/clinical_event.dart';
import '../services/auth_service.dart';
import '../services/events_service.dart';
import '../theme/app_theme.dart';

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

  static String actionText(ClinicalAction? a) => switch (a) {
        ClinicalAction.none => 'No change needed',
        ClinicalAction.advice => 'Advice from your clinician',
        ClinicalAction.treatmentChange => 'Your clinician adjusted your treatment',
        ClinicalAction.consultation => 'Your clinician asks to see you',
        ClinicalAction.referral => 'You are referred for further care',
        null => 'Reviewed',
      };

  String _date(DateTime t) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${t.day} ${months[t.month - 1]}';
  }

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
                  Text('From your clinician',
                      style: TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryText(context))),
                ]),
                for (final e in reviewed) ...[
                  const SizedBox(height: 10),
                  Text(actionText(e.action),
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context))),
                  Text('Alert of ${_date(e.triggeredAt)}, reviewed ${_date(e.reviewedAt!)}',
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
