import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_service.dart';

/// Terms of use and research consent (lib/screens/terms_screen.dart).
///
/// Accepting the terms is required to use the app; the research consent is a
/// separate, optional choice that the patient can change at any time from
/// the profile. Each choice is stamped with the server time, which the
/// security rules check (firestore.rules, isValidConsentChange), so the
/// record shows when it was given. The research extract
/// (telemonitor-research, serve/research_export.py) takes only the patients
/// whose `researchConsent` is true at the time of the extract.
class ConsentService {
  ConsentService._();
  static final ConsentService instance = ConsentService._();

  /// Changed when the terms change in substance: every patient is then asked
  /// to read and accept the new version at their next sign-in.
  static const String termsVersion = '2026-11-14';

  static const Duration _timeout = Duration(seconds: 15);

  /// Fields written with the new profile at sign-up, and when accepting the
  /// terms later.
  static Map<String, dynamic> acceptanceFields({required bool research}) => {
        'termsVersion': termsVersion,
        'termsAcceptedAt': FieldValue.serverTimestamp(),
        'researchConsent': research,
        'researchConsentAt': FieldValue.serverTimestamp(),
      };

  /// Accepts the current terms (an account made before the terms existed,
  /// or after they changed). A [TimeoutException] means the choice is kept
  /// on the phone and sent when it is back online.
  Future<void> acceptTerms({required bool research}) => _write(acceptanceFields(research: research));

  /// Gives or withdraws the research consent.
  Future<void> setResearchConsent(bool value) =>
      _write({'researchConsent': value, 'researchConsentAt': FieldValue.serverTimestamp()});

  Future<void> _write(Map<String, dynamic> data) async {
    final uid = AuthService.instance.currentProfile?.uid;
    if (uid == null) throw StateError('Not signed in.');
    await FirebaseFirestore.instance.collection('users').doc(uid).update(data).timeout(_timeout);
    await AuthService.instance.fetchCurrentUserProfile();
  }
}
