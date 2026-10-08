import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/clinician_code_service.dart';
import '../theme/app_theme.dart';

/// Shows the signed-in clinician their enrolment code, with a one-tap
/// copy so it can be written on a prescription slip or sent to a patient
/// directly.
///
/// Placed on the clinician's roster screen because that is where they
/// are when a new patient needs enrolling.
class EnrolmentCodeCard extends StatelessWidget {
  const EnrolmentCodeCard({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: ClinicianCodeService.instance.watchMyCode(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 4);
        }

        final code = snapshot.data;

        // No code provisioned. Say so plainly: a clinician without a code
        // cannot enrol anyone, and a blank space would not tell them why.
        if (code == null) {
          return Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.warningBg(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline,
                    size: 16, color: AppColors.warningText(context)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No enrolment code has been issued for your account '
                    'yet. Contact the system administrator — without one, '
                    'patients cannot register to you.',
                    style: TextStyle(fontSize: 12, color: AppColors.warningText(context)),
                  ),
                ),
              ],
            ),
          );
        }

        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.qr_code_2_outlined,
                      size: 16, color: Colors.white70),
                  const SizedBox(width: 8),
                  Text(
                    'Your enrolment code',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        code,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: 2.0,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Material(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: code));
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Code copied'),
                            backgroundColor: AppColors.success,
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: 14, vertical: 13),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.copy_rounded,
                                size: 16, color: AppColors.primaryText(context)),
                            SizedBox(width: 6),
                            Text(
                              'Copy',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primaryText(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Give this code to a patient so they can register and be '
                'linked to you.',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
