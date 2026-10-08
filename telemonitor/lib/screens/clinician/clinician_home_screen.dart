import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/reading.dart';
import '../../services/auth_service.dart';
import '../../services/patients_service.dart';
import '../../widgets/enrolment_code_card.dart';
import '../../theme/app_theme.dart';
import 'patient_detail_screen.dart';

/// Clinician roster: the enrolment code, then every assigned patient with
/// their latest reading, updating live.
class ClinicianHomeScreen extends StatelessWidget {
  const ClinicianHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: const Text(
          'My Patients',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout, size: 20),
            onPressed: () => AuthService.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<List<AppUser>>(
        stream: PatientsService.instance.watchMyPatients(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return _message(context, 
              Icons.error_outline,
              'Could not load patients.',
              snapshot.error.toString(),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final patients = snapshot.data!;

          // The enrolment code sits above the roster in BOTH states.
          // An empty roster is precisely when a clinician most needs
          // their code, so it must not be hidden behind having patients.
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const EnrolmentCodeCard(),
              if (patients.isEmpty)
                _emptyRoster(context)
              else
                ...patients.map((p) => _PatientCard(patient: p)),
            ],
          );
        },
      ),
    );
  }

  Widget _emptyRoster(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          Icon(Icons.people_outline, size: 44, color: AppColors.textMuted(context)),
          const SizedBox(height: 14),
          const Text(
            'No patients connected yet.',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text(
            'Share the code above with a patient so they can register and '
            'be linked to you.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
          ),
        ],
      ),
    );
  }

  Widget _message(BuildContext context, IconData icon, String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: AppColors.textMuted(context)),
            const SizedBox(height: 14),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientCard extends StatelessWidget {
  final AppUser patient;
  const _PatientCard({required this.patient});

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border(context),
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
              builder: (_) => PatientDetailScreen(patient: patient),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      _initials(patient.displayName),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.displayName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryText(context),
                        ),
                      ),
                      const SizedBox(height: 3),
                      _LatestReadingLine(patientId: patient.uid),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: AppColors.textMuted(context), size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Live one-line summary of the patient's most recent reading.
class _LatestReadingLine extends StatelessWidget {
  final String patientId;
  const _LatestReadingLine({required this.patientId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: PatientsService.instance.watchLatestReading(patientId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Text(
            'No readings yet',
            style: TextStyle(fontSize: 11, color: AppColors.textMuted(context)),
          );
        }

        final r = Reading.fromFirestore(snapshot.data!.docs.first);
        final isHigh = r.bpStatus == 'critical' ||
            r.bpStatus == 'stage2' ||
            r.glucoseStatus == 'critical' ||
            r.glucoseStatus == 'high';

        final parts = <String>[];
        if (r.hasBP) parts.add('${r.sbp}/${r.dbp}');
        if (r.hasGlucose) parts.add('${r.glucose} mmol/L');

        return Row(
          children: [
            if (isHigh) ...[
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: AppColors.dangerText(context),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 5),
            ],
            Flexible(
              child: Text(
                parts.isEmpty ? 'Reading logged' : parts.join(' · '),
                style: TextStyle(
                  fontSize: 11,
                  color: isHigh ? AppColors.dangerText(context) : AppColors.textSecondary(context),
                  fontWeight: isHigh ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
