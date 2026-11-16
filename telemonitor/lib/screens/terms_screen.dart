import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/auth_service.dart';
import '../services/consent_service.dart';
import '../theme/app_theme.dart';
import '../widgets/consent_checks.dart';
import '../l10n/l10n.dart';

/// Terms of use and privacy notice, version [ConsentService.termsVersion].
///
/// Written for patients: what the app is and is not, what it keeps, who sees
/// it, the optional research use, and the patient's rights under Cameroon's
/// personal data law. A change in substance needs a new version number, so
/// every patient is asked to accept it again.
/// The sections of the terms, (title, paragraphs), in the user's language;
/// the French text says the same as the English one.
List<(String, List<String>)> termsSections(AppLocalizations l) => [
      (l.termsS1Title, [l.termsS1P1, l.termsS1P2]),
      (l.termsS2Title, [l.termsS2B1, l.termsS2B2, l.termsS2B3, l.termsS2B4, l.termsS2B5, l.termsS2B6]),
      (l.termsS3Title, [l.termsS3B1, l.termsS3B2, l.termsS3B3, l.termsS3P1, l.termsS3P2]),
      (l.termsS4Title, [l.termsS4P1, l.termsS4P2, l.termsS4P3]),
      (l.termsS5Title, [l.termsS5P1]),
      (l.termsS6Title, [l.termsS6P1]),
      (l.termsS7Title, [l.termsS7P1]),
    ];

/// The terms as a list of widgets, for a scrolling view.
List<Widget> termsBody(BuildContext context) {
  final version = DateFormat('d MMMM y').format(DateTime.parse(ConsentService.termsVersion));
  return [
    Text(
      context.l10n.termsVersionOf(version),
      style: TextStyle(fontSize: 12, color: AppColors.textMuted(context)),
    ),
    for (final (title, paragraphs) in termsSections(context.l10n)) ...[
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
      appBar: AppBar(title: Text(context.l10n.termsOfUse, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600))),
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
      messenger.showSnackBar(SnackBar(content: Text(context.l10n.choiceNotSaved('$e'))));
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
          widget.updated ? context.l10n.updatedTerms : context.l10n.termsOfUse,
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
                        ? context.l10n.termsChanged
                        : context.l10n.readAndAcceptTerms,
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
                          : Text(context.l10n.acceptAndContinue, style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  TextButton(
                    onPressed: _saving ? null : () => AuthService.instance.signOut(),
                    child: Text(context.l10n.signOut),
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
