import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/clinical_event.dart';
import '../../models/reading.dart';
import '../../services/events_service.dart';
import '../../services/queue_logic.dart';
import '../../widgets/event_widgets.dart';
import '../../widgets/evolution_card.dart';
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
                  child: _RiskSection(patientId: patient.uid, age: patient.age, sex: patient.sex),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                  child: _EventsSection(patient: profile),
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

/// Risk tier of this patient from their recent readings.
///
/// The rule floor and the online model look at the last four days
/// (RiskAssessmentService.window); the newest readings are fetched and the
/// service keeps those within the window.
class _RiskSection extends StatelessWidget {
  final String patientId;
  final int? age;
  final String? sex;
  const _RiskSection({required this.patientId, this.age, this.sex});

  /// Enough readings to cover four days at several readings a day.
  static const int _fetch = 50;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(patientId)
          .collection('readings')
          .orderBy('timestamp', descending: true)
          .limit(_fetch)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final readings = Reading.effective(snapshot.data!.docs.map(Reading.fromFirestore));
        return Column(children: [
          RiskCard(readings: readings, age: age, sex: sex, forClinician: true),
          const SizedBox(height: 12),
          EvolutionCard(readings: readings),
        ]);
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

        // Every document, corrected ones included and marked: the record is
        // append-only and the clinician sees both versions.
        final readings = snapshot.data!.docs
            .map(Reading.fromFirestore)
            .toList();
        final superseded = {for (final r in readings) if (r.supersedes != null) r.supersedes};
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
              child: _ReadingTile(
                reading: readings[i],
                superseded: superseded.contains(readings[i].id),
              ),
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

  /// Replaced by a later correction; shown for audit, not counted.
  final bool superseded;
  const _ReadingTile({required this.reading, this.superseded = false});

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

  /// How the reading was obtained: protocol pair, correction, late entry.
  String get _provenance => [
        if (superseded) 'replaced by a correction',
        if (reading.isCorrection) 'correction of an earlier entry',
        if (reading.readingCount == 2)
          'second of two readings (first ${reading.firstSbp}/${reading.firstDbp})',
        if (reading.isBackdated && reading.recordedAt != null)
          'entered ${_formatted(reading.recordedAt!)}',
        if (reading.qualityFlag != null && reading.qualityFlag != 'ok')
          'quality check: ${reading.qualityFlag!.replaceAll('_', ' ')}',
      ].join(' · ');

  @override
  Widget build(BuildContext context) {
    // High or critical on either condition (thesis label, ClinicalLevels).
    final isHigh = reading.isAlert && !superseded;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isHigh
              ? AppColors.dangerBorder(context)
              : AppColors.border(context),
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
          if (_provenance.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              _provenance,
              style: TextStyle(fontSize: 11, color: AppColors.textMuted(context)),
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

/// The patient's event record and their checkup period (non-transmission
/// alarm), with the verdict of each event.
class _EventsSection extends StatelessWidget {
  final AppUser patient;
  const _EventsSection({required this.patient});

  Future<void> _editPeriod(BuildContext context, int current) async {
    final days = await showDialog<int>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Checkup period'),
        children: [
          for (final d in const [1, 2, 3, 5, 7, 14, 30])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, d),
              child: Text('$d day${d == 1 ? '' : 's'}${d == current ? '  (current)' : ''}'),
            ),
        ],
      ),
    );
    if (days == null || days == current) return;
    try {
      await EventsService.instance.setCheckupPeriod(patient.uid, days);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final period = patient.checkupPeriodDays ?? defaultCheckupPeriodDays;
    final title = TextStyle(
        fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.primaryText(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Text('Alerts and verdicts', style: title),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _editPeriod(context, period),
            icon: const Icon(Icons.timer_outlined, size: 16),
            label: Text('Checkup every $period d${patient.checkupPeriodDays == null ? ' (default)' : ''}',
                style: const TextStyle(fontSize: 12)),
          ),
        ]),
        StreamBuilder<List<ClinicalEvent>>(
          stream: EventsService.instance.watch(patient.uid, limit: 20),
          builder: (context, snap) {
            if (snap.hasError) {
              return Text('Could not load alerts: ${snap.error}',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)));
            }
            final events = snap.data;
            if (events == null) return const SizedBox(height: 24);
            if (events.isEmpty) {
              return Text('No alert recorded for this patient.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)));
            }
            return Column(children: [for (final e in events) EventLogTile(event: e)]);
          },
        ),
      ],
    );
  }
}
