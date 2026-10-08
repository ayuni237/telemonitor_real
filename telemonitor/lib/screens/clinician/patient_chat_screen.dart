import 'package:flutter/material.dart';

import '../../models/app_user.dart';
import '../../theme/app_theme.dart';
import '../../widgets/chat_thread_view.dart';
import '../../widgets/presence_title.dart';

/// A clinician's conversation with one specific patient.
class PatientChatScreen extends StatelessWidget {
  final AppUser patient;
  const PatientChatScreen({super.key, required this.patient});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        titleSpacing: 0,
        title: PresenceTitle(
          name: patient.displayName,
          otherUid: patient.uid,
        ),
      ),
      body: ChatThreadView(patientId: patient.uid),
    );
  }
}
