import 'package:flutter/material.dart';

import '../../services/care_finder_service.dart';
import '../../theme/app_theme.dart';

/// Lets a patient find care facilities near them.
///
/// Sits alongside the risk score deliberately: knowing that a reading is
/// in the critical range is only useful if the patient also knows where
/// to go. Measurement without access is advice a patient cannot act on.
class CareFinderScreen extends StatelessWidget {
  /// When true, the hospital option is shown first and highlighted —
  /// used when the patient arrives here from a high or critical risk
  /// alert rather than from ordinary navigation.
  final bool urgent;

  const CareFinderScreen({super.key, this.urgent = false});

  @override
  Widget build(BuildContext context) {
    final categories = urgent
        ? [
            CareCategory.hospital,
            CareCategory.clinic,
            CareCategory.pharmacy,
            CareCategory.laboratory,
          ]
        : CareCategory.values;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text(
          'Find care near you',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (urgent) _urgentBanner(context),
          Text(
            'Tap a category to see what is nearby in Google Maps.',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary(context),
            ),
          ),
          const SizedBox(height: 16),
          ...categories.map((c) => _categoryCard(
                context,
                c,
                highlighted: urgent && c == CareCategory.hospital,
              )),
          const SizedBox(height: 8),
          _privacyNote(context),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _urgentBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerBg(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.dangerBorder(context), width: 0.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded,
              size: 20, color: AppColors.dangerText(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Your recent readings are in a range that needs attention. '
              'If you feel unwell, go to a hospital rather than waiting for '
              'your next appointment.',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.dangerText(context),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(CareCategory c) {
    switch (c) {
      case CareCategory.pharmacy:
        return Icons.local_pharmacy_outlined;
      case CareCategory.hospital:
        return Icons.local_hospital_outlined;
      case CareCategory.clinic:
        return Icons.medical_services_outlined;
      case CareCategory.laboratory:
        return Icons.biotech_outlined;
    }
  }

  Widget _categoryCard(BuildContext context, CareCategory c,
      {bool highlighted = false}) {
    final fg = highlighted
        ? AppColors.dangerText(context)
        : AppColors.primaryText(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlighted
              ? AppColors.dangerBorder(context)
              : AppColors.border(context),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _open(context, c),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: highlighted
                        ? AppColors.dangerBg(context)
                        : AppColors.tint(context),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_iconFor(c), color: fg, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        c.label,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        c.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(context),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.open_in_new,
                    size: 18, color: AppColors.textMuted(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, CareCategory c) async {
    final ok = await CareFinderService.instance.findNearby(c);
    if (ok || !context.mounted) return;
    // Launching can fail on a device with no maps app and no browser.
    // Say so rather than leaving the tap looking unresponsive.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text(
          'Could not open Maps on this device. Please search for '
          '"pharmacie near me" in your browser.',
        ),
        backgroundColor: AppColors.danger,
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Widget _privacyNote(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.tint(context),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lock_outline,
              size: 16, color: AppColors.textSecondary(context)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'TeleMonitor does not access or store your location. The '
              'search is handled by Google Maps on your device.',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary(context),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
