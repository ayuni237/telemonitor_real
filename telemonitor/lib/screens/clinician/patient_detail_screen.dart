import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/reading.dart';
import '../../widgets/risk_card.dart';
import '../../theme/app_theme.dart';
import 'patient_chat_screen.dart';

/// One patient as seen by their assigned clinician: profile details on
/// top, the model's risk assessment, then the full reading history.
///
/// Reads Firestore directly rather than going through
/// ReadingsRepository: that repository follows exactly one patient and
/// is bound to the signed-in patient's own data, so a clinician
/// re-binding it would fight over shared state.
class PatientDetailScreen extends StatelessWidget {
  final AppUser patient;
  const PatientDetailScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        title: Text(
          patient.displayName,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Message patient',
            icon: const Icon(Icons.chat_bubble_outline, size: 20),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PatientChatScreen(patient: patient),
              ),
            ),
          ),
        ],
      ),
      // The profile is streamed rather than taken from the AppUser passed
      // in: the roster snapshot could be minutes old by the time the
      // clinician opens it, and stale clinical details are worse than a
      // brief loading state.
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(patient.uid)
            .snapshots(),
        builder: (context, profileSnap) {
          final profile = (profileSnap.hasData && profileSnap.data!.exists)
              ? AppUser.fromFirestore(
                  patient.uid,
                  profileSnap.data!.data() as Map<String, dynamic>,
                )
              : patient;

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _ProfileCard(patient: profile)),

              // The model's assessment, between the profile and the raw
              // readings — a clinician wants the summary judgement
              // before the underlying numbers.
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _RiskSection(patientId: patient.uid),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    'Reading history',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryText(context),
                    ),
                  ),
                ),
              ),
              _ReadingsSliver(patientId: patient.uid),
              const SliverToBoxAdapter(child: SizedBox(height: 32)),
            ],
          );
        },
      ),
    );
  }
}

/// Runs the risk model over this patient's most recent readings.
///
/// Only the last [_windowSize] readings are fetched — that is all the
/// model looks at, and limiting the query keeps this independent of how
/// long the patient's full history grows.
class _RiskSection extends StatelessWidget {
  final String patientId;
  const _RiskSection({required this.patientId});

  /// Kept in step with SlidingWindowFeatures.windowSize. If the model is
  /// ever retrained on a different window, both must change together.
  static const int _windowSize = 7;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .collection('readings')
          .orderBy('timestamp', descending: true)
          .limit(_windowSize)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final readings = snapshot.data!.docs
            .map(Reading.fromFirestore)
            .toList();
        return RiskCard(readings: readings);
      },
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final AppUser patient;
  const _ProfileCard({required this.patient});

  /// True only when the value is present AND non-blank. Guards against a
  /// field that was saved as an empty or whitespace string, which would
  /// otherwise render as a label with nothing beside it.
  static bool _has(String? v) => v != null && v.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final hasPhone = _has(patient.phone);
    final hasEmergency = _has(patient.emergencyContact);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(context), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
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
                      fontSize: 15,
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
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primaryText(context),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      patient.email,
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (!patient.hasClinicalInfo) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
              decoration: BoxDecoration(
                color: AppColors.field(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'No clinical information recorded for this patient yet.',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary(context),
                ),
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (patient.age != null)
                  _pill(context, '${patient.age} yrs', Icons.cake_outlined),
                if (_has(patient.sex))
                  _pill(context, patient.sex!, Icons.person_outline),
                // Units appended here rather than stored, so an older
                // profile saved as plain "162" still reads correctly.
                if (_has(patient.height))
                  _pill(
                    context,
                    _withUnit(patient.height!, 'cm'),
                    Icons.height,
                  ),
                if (_has(patient.weight))
                  _pill(
                    context,
                    _withUnit(patient.weight!, 'kg'),
                    Icons.monitor_weight_outlined,
                  ),
                if (_has(patient.bloodType))
                  _pill(context, patient.bloodType!, Icons.water_drop_outlined),
              ],
            ),

            if (patient.conditions.isNotEmpty) ...[
              const SizedBox(height: 16),
              _sectionTitle(
                context,
                'Conditions',
                Icons.medical_information_outlined,
              ),
              const SizedBox(height: 8),
              ...patient.conditions.map(
                (c) => _bullet(context, c, AppColors.dangerText(context)),
              ),
            ],

            if (patient.medications.isNotEmpty) ...[
              const SizedBox(height: 16),
              _sectionTitle(context, 'Medications', Icons.medication_outlined),
              const SizedBox(height: 8),
              ...patient.medications.map(
                (m) => _bullet(context, m, AppColors.primaryText(context)),
              ),
            ],

            if (hasPhone || hasEmergency) ...[
              const SizedBox(height: 16),
              _sectionTitle(context, 'Contact', Icons.phone_outlined),
              const SizedBox(height: 8),
              if (hasPhone) _kv(context, 'Phone', patient.phone!),
              if (hasEmergency)
                _kv(context, 'Emergency', patient.emergencyContact!),
            ],
          ],
        ],
      ),
    );
  }

  /// Appends a unit unless the stored value already carries letters.
  static String _withUnit(String value, String unit) {
    final v = value.trim();
    return RegExp(r'[a-zA-Z]').hasMatch(v) ? v : '$v $unit';
  }

  static String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  Widget _pill(BuildContext context, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.tint(context),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: AppColors.primaryText(context)),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.primaryText(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.textSecondary(context)),
        const SizedBox(width: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _bullet(BuildContext context, String text, Color dot) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 2),
      child: Row(
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                color: AppColors.primaryText(context),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary(context),
            ),
          ),
          Flexible(
            child: Text(
              value,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryText(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadingsSliver extends StatelessWidget {
  final String patientId;
  const _ReadingsSliver({required this.patientId});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .collection('readings')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return SliverToBoxAdapter(
            child: _note(
              context,
              'Could not load readings.\n${snapshot.error}',
            ),
          );
        }
        if (!snapshot.hasData) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        final readings = snapshot.data!.docs
            .map(Reading.fromFirestore)
            .toList();
        if (readings.isEmpty) {
          return SliverToBoxAdapter(
            child: _note(
              context,
              'This patient has not logged any readings yet.',
            ),
          );
        }

        return SliverList(
          delegate: SliverChildBuilderDelegate(
            (context, i) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ReadingTile(reading: readings[i]),
            ),
            childCount: readings.length,
          ),
        );
      },
    );
  }

  Widget _note(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Center(
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary(context),
          ),
        ),
      ),
    );
  }
}

class _ReadingTile extends StatelessWidget {
  final Reading reading;
  const _ReadingTile({required this.reading});

  String _formatted(DateTime ts) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    final time =
        '${ts.hour.toString().padLeft(2, '0')}:${ts.minute.toString().padLeft(2, '0')}';
    return '${ts.day} ${months[ts.month - 1]} · $time';
  }

  @override
  Widget build(BuildContext context) {
    final isHigh =
        reading.bpStatus == 'critical' ||
        reading.bpStatus == 'stage2' ||
        reading.glucoseStatus == 'critical' ||
        reading.glucoseStatus == 'high';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHigh
              ? AppColors.dangerBorder(context)
              : Colors.grey.withValues(alpha: 0.15),
          width: 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatted(reading.timestamp),
                style: TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary(context),
                ),
              ),
              if (reading.context.isNotEmpty)
                Text(
                  reading.context,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(context),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              if (reading.hasBP)
                _chip(
                  context,
                  Icons.favorite_outline,
                  '${reading.sbp}/${reading.dbp}',
                  'mmHg',
                  isHigh,
                ),
              if (reading.hasGlucose)
                _chip(
                  context,
                  Icons.water_drop_outlined,
                  '${reading.glucose}',
                  'mmol/L',
                  false,
                ),
              if (reading.hr != null)
                _chip(
                  context,
                  Icons.monitor_heart_outlined,
                  '${reading.hr}',
                  'bpm',
                  false,
                ),
            ],
          ),
          if (reading.notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              reading.notes,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary(context),
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(
    BuildContext context,
    IconData icon,
    String value,
    String unit,
    bool alert,
  ) {
    final color = alert
        ? AppColors.dangerText(context)
        : AppColors.primaryText(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 5),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        const SizedBox(width: 3),
        Text(
          unit,
          style: TextStyle(fontSize: 10, color: AppColors.textMuted(context)),
        ),
      ],
    );
  }
}
