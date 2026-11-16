import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/consent_service.dart';
import '../theme/app_theme.dart';
import '../widgets/consent_checks.dart';

/// Terms of use and privacy notice, version [ConsentService.termsVersion].
///
/// Written for patients: what the app is and is not, what it keeps, who sees
/// it, the optional research use, and the patient's rights under Cameroon's
/// personal data law. A change in substance needs a new version number, so
/// every patient is asked to accept it again.
const List<(String, List<String>)> termsSections = [
  (
    'What TeleMonitor is',
    [
      'TeleMonitor helps you follow your blood pressure and blood sugar at home with your clinician. '
          'You enter your readings; the app compares them with your home targets and your clinician '
          'reviews the alerts.',
      'TeleMonitor does not replace a consultation and is not an emergency service. It never changes '
          'your treatment: only your clinician can. If you feel very unwell, go to the nearest health '
          'centre or hospital without waiting for an answer in the app.',
    ],
  ),
  (
    'The information the app keeps',
    [
      '• Your account: name and email address.',
      '• Your profile, if you fill it in: age, sex, height, weight, conditions, medications, phone, '
          'emergency contact and an optional photo.',
      '• Your readings (blood pressure, heart rate, blood sugar, when you measured and your notes), the '
          'alerts they raise and your clinician\'s review of them.',
      '• If you measure your pulse with the phone camera, the pulse found: the images of the camera are '
          'read on the phone and dropped at once, never kept or sent.',
      '• The messages you exchange with your clinician.',
      '• What the service needs to work: when you last used the app, and the address used to send '
          'notifications to your phone.',
    ],
  ),
  (
    'Who can see it',
    [
      '• You.',
      '• The clinician you connect to, and the colleague they name to replace them when an alert waits '
          'too long.',
      '• The administrator of the system, only to keep it working.',
      'Your information is stored on Google Firebase servers and travels encrypted. Access rules let each '
          'person see only what they are allowed to see.',
      'When you use the health assistant, your question, age, sex, conditions, medications and recent '
          'readings are sent to Google\'s Gemini service to prepare the answer, never your name or contact '
          'details. Do not type your name or other personal details in the assistant.',
    ],
  ),
  (
    'Research, only if you agree',
    [
      'If you tick the research box, your information may also be used for medical research on the home '
          'follow-up of hypertension and diabetes, by the TeleMonitor project of the GISDIA laboratory, '
          'National Higher Polytechnic School of Douala (ENSPD), University of Douala.',
      'Before any use, your name, email, phone numbers, emergency contact, photo, messages and notes are '
          'removed, and your account is replaced by a code. Results are published only as figures about '
          'groups of patients, in which no one can be recognised.',
      'Saying no changes nothing in your care. You can change your choice at any time in your profile; '
          'from then on, your information is left out of new research extracts.',
    ],
  ),
  (
    'Your rights',
    [
      'Under Law No. 2024/017 of 23 December 2024 on the protection of personal data in Cameroon, you can '
          'see your information (the app shows it to you), have it corrected, withdraw your research '
          'consent, and ask for your account and your information to be deleted. For a deletion or any '
          'question, ask your clinician or the administrator.',
    ],
  ),
  (
    'Keeping your account safe',
    [
      'Keep your password to yourself. Confirm your email address: it is the only way to set a new '
          'password if you forget yours. On a shared phone, sign out when you finish.',
    ],
  ),
  (
    'Changes to these terms',
    [
      'If these terms change, the app shows you the new version and asks you to accept it before you '
          'continue.',
    ],
  ),
];

/// The terms as a list of widgets, for a scrolling view.
List<Widget> termsBody(BuildContext context) {
  final version = DateFormat('d MMMM y').format(DateTime.parse(ConsentService.termsVersion));
  return [
    Text(
      'Version of $version',
      style: TextStyle(fontSize: 12, color: AppColors.textMuted(context)),
    ),
    for (final (title, paragraphs) in termsSections) ...[
      const SizedBox(height: 18),
      Text(
        title,
        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.primaryText(context)),
      ),
      for (final p in paragraphs)
        Padding(
          padding: EdgeInsets.only(top: 8, left: p.startsWith('• ') ? 8 : 0),
          child: Text(
            p,
            style: TextStyle(fontSize: 13, height: 1.45, color: AppColors.textPrimary(context)),
          ),
        ),
    ],
  ];
}

/// Read-only view, from the sign-up form and the profile.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(title: const Text('Terms of use', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: termsBody(context)),
      ),
    );
  }
}

/// Shown once to a patient whose account was made before these terms, or
/// before their latest version (auth_gate.dart): the app is used only after
/// they are accepted.
class AcceptTermsScreen extends StatefulWidget {
  /// The patient accepted an earlier version (wording: "updated").
  final bool updated;
  final bool initialResearch;
  final VoidCallback onAccepted;

  const AcceptTermsScreen({
    super.key,
    required this.onAccepted,
    this.updated = false,
    this.initialResearch = false,
  });

  @override
  State<AcceptTermsScreen> createState() => _AcceptTermsScreenState();
}

class _AcceptTermsScreenState extends State<AcceptTermsScreen> {
  bool _terms = false;
  late bool _research = widget.initialResearch;
  bool _saving = false;

  Future<void> _accept() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ConsentService.instance.acceptTerms(research: _research);
    } on TimeoutException {
      // kept on the phone, sent when it is back online
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(content: Text('Could not save your choice: $e')));
      return;
    }
    if (mounted) widget.onAccepted();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          widget.updated ? 'Updated terms of use' : 'Terms of use',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                children: [
                  Text(
                    widget.updated
                        ? 'The terms have changed. Please read them and accept them to continue.'
                        : 'Please read the terms of use and accept them to continue.',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
                  ),
                  const SizedBox(height: 6),
                  ...termsBody(context),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              decoration: BoxDecoration(
                color: AppColors.card(context),
                border: Border(top: BorderSide(color: AppColors.border(context), width: 0.5)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ConsentChecks(
                    terms: _terms,
                    research: _research,
                    showReadLink: false,
                    onTerms: (v) => setState(() => _terms = v),
                    onResearch: (v) => setState(() => _research = v),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      onPressed: _terms && !_saving ? _accept : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Accept and continue', style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : () => AuthService.instance.signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
