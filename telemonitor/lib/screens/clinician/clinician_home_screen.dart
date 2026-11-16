import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../models/reading.dart';
import '../../services/app_messenger.dart';
import '../../services/auth_service.dart';
import '../../services/clinician_queue.dart';
import '../../services/events_service.dart';
import '../../services/patients_service.dart';
import '../../services/push_service.dart';
import '../../widgets/enrolment_code_card.dart';
import '../../widgets/event_widgets.dart';
import '../../widgets/user_avatar.dart';
import '../../widgets/verdict_sheet.dart';
import '../../theme/app_theme.dart';
import 'patient_chat_screen.dart';
import 'patient_detail_screen.dart';

/// Clinician home: the queue of unreviewed events in priority order
/// (thesis ch.4 §Clinician dashboard), and the roster with the enrolment code
/// and every assigned patient's latest reading, updating live.
class ClinicianHomeScreen extends StatefulWidget {
  const ClinicianHomeScreen({super.key});

  @override
  State<ClinicianHomeScreen> createState() => _ClinicianHomeScreenState();
}

class _ClinicianHomeScreenState extends State<ClinicianHomeScreen> {
  final _queue = ClinicianQueue(FirebaseFirestore.instance);
  StreamSubscription<List<AppUser>>? _roster;
  List<AppUser>? _patients;
  Object? _rosterError;

  @override
  void initState() {
    super.initState();
    _roster = PatientsService.instance.watchMyPatients().listen(
      (ps) {
        setState(() => _patients = ps);
        _queue.follow(ps);
      },
      onError: (Object e) => setState(() => _rosterError = e),
    );
    PushService.instance.opened.addListener(_openFromPush);
    // a notification that launched the app was tapped before this screen existed
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFromPush());
  }

  @override
  void dispose() {
    PushService.instance.opened.removeListener(_openFromPush);
    _roster?.cancel();
    _queue.dispose();
    super.dispose();
  }

  /// Names the colleague who receives this clinician's alerts left
  /// unreviewed too long (queue-age sweep of the worker).
  Future<void> _editAlternate() async {
    final result = await showDialog<String>(
      context: context,
      builder: (_) => _AlternateDialog(me: AuthService.instance.currentProfile),
    );
    if (result == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final name = await EventsService.instance.setAlternate(result.trim().isEmpty ? null : result);
      messenger.showSnackBar(SnackBar(
          content: Text(name == null ? 'Alternate removed.' : '$name is now your alternate.')));
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Could not save: $e')));
    }
  }

  /// A tapped message notification: the conversation with that patient.
  Future<void> _openFromPush() async {
    final target = PushService.instance.opened.value;
    if (!mounted || target == null) return;
    PushService.instance.opened.value = null;
    final navigator = Navigator.of(context);
    var patient = _patients?.where((p) => p.uid == target.patientId).firstOrNull;
    if (patient == null) {
      try {
        final snap = await FirebaseFirestore.instance.collection('users').doc(target.patientId).get();
        if (snap.exists) patient = AppUser.fromFirestore(snap.id, snap.data()!);
      } catch (_) {
        // no longer assigned, or offline with nothing cached
      }
    }
    if (!mounted) return;
    if (patient == null) {
      AppMessenger.show('This conversation could not be opened.', error: true);
      return;
    }
    final p = patient;
    navigator.popUntil((route) => route.isFirst);
    navigator.push(MaterialPageRoute(builder: (_) => PatientChatScreen(patient: p)));
  }

  void _open(AppUser p) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => PatientDetailScreen(patient: p)),
      );

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
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
            // The clinician's own optional photo, shown to their patients.
            if (AuthService.instance.currentProfile case final me?)
              IconButton(
                tooltip: 'My photo',
                onPressed: () => showProfilePhotoSheet(context, uid: me.uid, forClinician: true),
                icon: UserAvatar(
                  uid: me.uid,
                  name: me.displayName,
                  size: 28,
                  background: Colors.white.withValues(alpha: 0.2),
                  border: Border.all(color: Colors.white, width: 1.5),
                  fontSize: 11,
                ),
              ),
            IconButton(
              tooltip: 'Alternate clinician',
              icon: const Icon(Icons.swap_horiz, size: 22),
              onPressed: _editAlternate,
            ),
            IconButton(
              tooltip: 'Sign out',
              icon: const Icon(Icons.logout, size: 20),
              onPressed: () => AuthService.instance.signOut(),
            ),
          ],
          bottom: TabBar(
            indicatorColor: Colors.white,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.6),
            tabs: [
              ListenableBuilder(
                listenable: _queue,
                builder: (_, _) => Tab(text: 'Queue (${_queue.items.length})'),
              ),
              const Tab(text: 'Patients'),
            ],
          ),
        ),
        body: TabBarView(children: [_queueTab(), _rosterTab()]),
      ),
    );
  }

  Widget _queueTab() {
    return ListenableBuilder(
      listenable: _queue,
      builder: (context, _) {
        if (_rosterError != null || _queue.error != null) {
          return _message(context, Icons.error_outline, 'Could not load the queue.',
              (_rosterError ?? _queue.error).toString());
        }
        if (_patients == null) return const Center(child: CircularProgressIndicator());
        final items = _queue.items;
        if (items.isEmpty) {
          return _message(context, Icons.inbox_outlined, 'No alert to review.',
              'Yellow and red readings, model alerts and patients who stopped sending '
                  'readings appear here, the most urgent first.');
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            for (final it in items)
              QueueRow(
                item: it,
                onOpen: () => it.isForeign ? showVerdictSheet(context, it.event) : _open(it.patient),
              ),
          ],
        );
      },
    );
  }

  Widget _rosterTab() {
    if (_rosterError != null) {
      return _message(context, Icons.error_outline, 'Could not load patients.', _rosterError.toString());
    }
    final patients = _patients;
    if (patients == null) return const Center(child: CircularProgressIndicator());

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
                UserAvatar(uid: patient.uid, name: patient.displayName, size: 42, fontSize: 13),
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

        final r = Reading.effective(snapshot.data!.docs.map(Reading.fromFirestore)).first;
        final isHigh = r.isAlert;

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

/// Names the alternate clinician. It owns its text controller, disposed with
/// the dialog: disposing it as soon as the dialog returns breaks the field,
/// still on screen while the dialog fades out.
class _AlternateDialog extends StatefulWidget {
  final AppUser? me;

  const _AlternateDialog({required this.me});

  @override
  State<_AlternateDialog> createState() => _AlternateDialogState();
}

class _AlternateDialogState extends State<_AlternateDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return AlertDialog(
      title: const Text('Alternate clinician'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            me?.alternateClinicianName == null
                ? 'No alternate named. Alerts you leave unreviewed are escalated to nobody.'
                : 'Current alternate: ${me!.alternateClinicianName}.',
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: "Colleague's enrolment code"),
          ),
        ],
      ),
      actions: [
        if (me?.alternateClinicianId != null)
          TextButton(onPressed: () => Navigator.pop(context, ''), child: const Text('Remove')),
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, _controller.text), child: const Text('Save')),
      ],
    );
  }
}
