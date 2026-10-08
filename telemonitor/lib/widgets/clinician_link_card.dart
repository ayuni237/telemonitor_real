import 'package:flutter/material.dart';

import '../services/auth_service.dart';
import '../screens/connect_clinician_screen.dart';
import '../theme/app_theme.dart';

/// Prompts a patient who has no clinician to connect to one.
////// Renders nothing at all once the patient is connected, so it can be
/// dropped into the dashboard and the profile screen without either
/// needing conditional logic of its own.
class ClinicianLinkCard extends StatefulWidget {
  const ClinicianLinkCard({super.key});

  @override
  State<ClinicianLinkCard> createState() => _ClinicianLinkCardState();
}

class _ClinicianLinkCardState extends State<ClinicianLinkCard> {
  @override
  Widget build(BuildContext context) {
    final me = AuthService.instance.currentProfile;

    // Already connected, or profile not loaded — nothing to prompt.
    if (me == null || me.isAssigned) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.warningBg(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_search_outlined,
                size: 16,
                color: AppColors.warningText(context),
              ),
              const SizedBox(width: 8),
              Text(
                'No clinician connected',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.warningText(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'You can record readings now, but nobody is reviewing them yet. '
            'Enter the code your doctor gives you to connect.',
            style: TextStyle(
              fontSize: 12,
              color: AppColors.warningText(context),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () async {
                final linked = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ConnectClinicianScreen(),
                  ),
                );
                // Rebuild so the card disappears once connected.
                if (linked == true && mounted) setState(() {});
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.warningText(context),
                side: BorderSide(color: AppColors.warningText(context), width: 0.8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Connect to a clinician',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
