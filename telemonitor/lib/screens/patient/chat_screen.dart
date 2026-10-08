import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/patients_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/chat_thread_view.dart';
import '../../widgets/presence_title.dart';
import '../connect_clinician_screen.dart';

/// The patient's conversation with their assigned clinician.
class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  AppUser? _clinician;
  bool _loadingClinician = true;

  @override
  void initState() {
    super.initState();
    _loadClinician();
  }

  Future<void> _loadClinician() async {
    final me = AuthService.instance.currentProfile;
    if (me == null || !me.isAssigned) {
      if (mounted) setState(() => _loadingClinician = false);
      return;
    }
    final clinician =
        await PatientsService.instance.fetchUser(me.assignedClinicianId!);
    if (!mounted) return;
    setState(() {
      _clinician = clinician;
      _loadingClinician = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = AuthService.instance.currentProfile;

    if (me == null) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(title: const Text('Messages')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // An unassigned patient has nobody on the other end. Saying so is
    // better than a working-looking chat whose messages nobody reads.
    if (!_loadingClinician && !me.isAssigned) {
      return Scaffold(
        backgroundColor: AppColors.background(context),
        appBar: AppBar(
          title: const Text(
            'Messages',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.person_search_outlined,
                    size: 44, color: AppColors.textMuted(context)),
                const SizedBox(height: 14),
                Text(
                  'No clinician connected yet',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: AppColors.textPrimary(context),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Enter the code your doctor gives you to start a '
                  'conversation with them.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary(context)),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () async {
                    final linked = await Navigator.push<bool>(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ConnectClinicianScreen()),
                    );
                    if (linked == true && mounted) {
                      setState(() => _loadingClinician = true);
                      _loadClinician();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('Connect to a clinician'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: PresenceTitle(
          name: _loadingClinician
              ? 'Messages'
              : (_clinician?.displayName ?? 'Your clinician'),
          otherUid: me.assignedClinicianId,
          icon: Icons.medical_services_outlined,
        ),
      ),
      // The patient's own uid is the thread id.
      body: ChatThreadView(patientId: me.uid),
    );
  }
}
