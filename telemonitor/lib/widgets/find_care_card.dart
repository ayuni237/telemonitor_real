import 'package:flutter/material.dart';

import '../models/reading.dart';
import '../services/readings_repository.dart';
import '../screens/patient/care_finder_screen.dart';
import '../theme/app_theme.dart';

/// Entry point to the care finder.
///
/// Works out for itself whether the patient's latest reading is alarming,
/// so it can be dropped into any screen without that screen needing to
/// pass anything in.
///
/// It escalates when a reading is in the high or critical range: telling
/// a patient their pressure is dangerous is only actionable if they also
/// know where to go.
class FindCareCard extends StatefulWidget {
  const FindCareCard({super.key});

  @override
  State<FindCareCard> createState() => _FindCareCardState();
}

class _FindCareCardState extends State<FindCareCard> {
  @override
  void initState() {
    super.initState();
    ReadingsRepository.instance.addListener(_onChanged);
  }

  @override
  void dispose() {
    ReadingsRepository.instance.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (mounted) setState(() {});
  }

  bool get _urgent {
    final readings = ReadingsRepository.instance.readings;
    if (readings.isEmpty) return false;
    final Reading r = readings.first;
    return r.bpStatus == 'critical' ||
        r.bpStatus == 'stage2' ||
        r.glucoseStatus == 'critical' ||
        r.glucoseStatus == 'high';
  }

  @override
  Widget build(BuildContext context) {
    final urgent = _urgent;
    final fg = urgent
        ? AppColors.dangerText(context)
        : AppColors.primaryText(context);

    return Container(
      decoration: BoxDecoration(
        color: urgent ? AppColors.dangerBg(context) : AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: urgent
              ? AppColors.dangerBorder(context)
              : AppColors.border(context),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => CareFinderScreen(urgent: urgent),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  urgent
                      ? Icons.local_hospital_outlined
                      : Icons.place_outlined,
                  size: 22,
                  color: fg,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        urgent
                            ? 'Find a hospital near you'
                            : 'Find care near you',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: fg,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        urgent
                            ? 'Your latest reading needs attention'
                            : 'Pharmacies, clinics, hospitals and laboratories',
                        style: TextStyle(
                          fontSize: 11,
                          color: urgent
                              ? fg
                              : AppColors.textSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 20, color: AppColors.textMuted(context)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
