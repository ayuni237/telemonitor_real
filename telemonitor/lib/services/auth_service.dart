import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/app_user.dart';
import 'consent_service.dart';
import 'push_service.dart';
import 'readings_repository.dart';

/// Result of looking up a clinician enrolment code.
class ClinicianCode {
  final String code;
  final String clinicianId;
  final String clinicianName;

  const ClinicianCode({
    required this.code,
    required this.clinicianId,
    required this.clinicianName,
  });
}

/// Raised when sign-up or linking fails for a reason worth showing the
/// user verbatim.
class SignUpException implements Exception {
  final String message;
  const SignUpException(this.message);
  @override
  String toString() => message;
}

/// Wraps Firebase Auth plus the Firestore users/{uid} profile lookup.
class AuthService {
  AuthService._internal();
  static final AuthService instance = AuthService._internal();

  fb_auth.FirebaseAuth get _auth => fb_auth.FirebaseAuth.instance;
  // resolved on use, so the service can be built where Firebase is not initialised (screen tests)
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  AppUser? _currentProfile;

  AppUser? get currentProfile => _currentProfile;

  /// Screen tests: a signed-in profile without Firebase.
  @visibleForTesting
  set debugProfile(AppUser? p) => _currentProfile = p;

  /// Screen tests: whether the signed-in email is confirmed.
  @visibleForTesting
  bool? debugEmailVerified;

  /// Widget tests: replaces the account creation of [signUpPatient].
  @visibleForTesting
  Future<void> Function()? debugSignUp;

  Stream<fb_auth.User?> get authStateChanges => _auth.authStateChanges();

  fb_auth.User? get currentFirebaseUser => _auth.currentUser;

  // ---------------------------------------------------------------
  // Sign in / out / reset
  // ---------------------------------------------------------------

  Future<void> signIn({required String email, required String password}) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await PushService.instance.stop();
    _currentProfile = null;
    await ReadingsRepository.instance.unbind();
    await _auth.signOut();
  }

  /// Sends a password reset email. The caller shows a deliberately
  /// generic confirmation regardless of outcome: revealing whether an
  /// address is registered would let anyone test which emails have
  /// accounts on a medical system.
  ///
  /// While the worker runs, it sends TeleMonitor's own email, asked for
  /// through password_resets/{address} (this is used signed out, so the
  /// request names the address; the worker answers only for an existing
  /// account). Otherwise, or when the request fails, Firebase's email.
  Future<void> sendPasswordReset(String email) async {
    final address = email.trim().toLowerCase();
    if (_mailAddress.hasMatch(address) && address.length <= 254 && await _workerSendsMail()) {
      if (await _askWorker(_db.collection('password_resets').doc(address), {})) return;
    }
    await _auth.sendPasswordResetEmail(email: email.trim());
  }

  static final _mailAddress = RegExp(r'^[^@\s/]+@[^@\s/]+\.[^@\s/]+$');

  /// Writes an email request for the worker; false when it is refused (the
  /// rules allow one a minute) or does not reach the server in time.
  Future<bool> _askWorker(DocumentReference<Map<String, dynamic>> request, Map<String, Object> fields) async {
    try {
      await request
          .set({...fields, 'requestedAt': FieldValue.serverTimestamp()})
          .timeout(const Duration(seconds: 15));
      return true;
    } catch (e) {
      debugPrint('Email request refused, Firebase sends its email: $e');
      return false;
    }
  }

  // ---------------------------------------------------------------
  // Email confirmation
  // ---------------------------------------------------------------
  //
  // The password reset link goes to the account's email, so an address
  // the patient cannot open means a forgotten password cannot be reset.
  // The address is confirmed by a link sent at sign-up; the dashboard
  // reminds the patient until it is done (verify_email_card.dart). The
  // app is not blocked meanwhile: a patient's readings must not wait on
  // their mailbox.

  /// True when there is nothing to confirm (signed out, or no Firebase in
  /// screen tests).
  bool get emailVerified {
    if (debugEmailVerified != null) return debugEmailVerified!;
    if (Firebase.apps.isEmpty) return true;
    return _auth.currentUser?.emailVerified ?? true;
  }

  /// Sends the confirmation link. While the worker runs, it sends it in
  /// TeleMonitor's own email (worker.py, mail.py), asked for through
  /// mail_requests/{uid}; the worker keeps config/mail.workerAt fresh. When
  /// it does not run, or the request fails, Firebase's standard email is
  /// sent instead: the link never depends on the worker.
  Future<void> sendEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) return;
    if (await _workerSendsMail() &&
        await _askWorker(_db.collection('mail_requests').doc(user.uid), {'kind': 'verify_email'})) {
      return;
    }
    await user.sendEmailVerification();
  }

  /// Whether the worker sent its heartbeat in the last few minutes.
  Future<bool> _workerSendsMail() async {
    try {
      final doc = await _db.collection('config').doc('mail').get();
      final at = doc.data()?['workerAt'];
      return at is Timestamp && DateTime.now().difference(at.toDate()).abs() < const Duration(minutes: 5);
    } catch (_) {
      return false;
    }
  }

  /// Asks the server whether the link has been opened since sign-in.
  Future<bool> refreshEmailVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  // ---------------------------------------------------------------
  // Clinician enrolment codes
  // ---------------------------------------------------------------

  /// Looks up a clinician enrolment code. Returns null when the code does
  /// not exist.
  Future<ClinicianCode?> lookupClinicianCode(String rawCode) async {
    final code = _normaliseCode(rawCode);
    if (code.isEmpty) return null;

    try {
      final doc = await _db.collection('clinician_codes').doc(code).get();

      if (!doc.exists) return null;

      final data = doc.data()!;
      final clinicianId = (data['clinicianId'] as String?)?.trim() ?? '';
      if (clinicianId.isEmpty) return null;

      return ClinicianCode(
        code: code,
        clinicianId: clinicianId,
        clinicianName: (data['name'] as String?)?.trim() ?? 'Your clinician',
      );
    } catch (e) {
      // The previous version let this fail silently, which is why the
      // screen could only ever say "code not recognised" regardless of
      // the real cause.
      debugPrint('Clinician code lookup failed: $e');
      return null;
    }
  }

  /// Codes are stored uppercase with whitespace removed, so a patient
  /// typing "mbarga-4f7k " still matches "MBARGA-4F7K".
  static String _normaliseCode(String raw) => raw.trim().toUpperCase();

  // ---------------------------------------------------------------
  // Sign up
  // ---------------------------------------------------------------

  /// Registers a new PATIENT account.
  ///
  /// [clinicianCode] is OPTIONAL. A patient may register without one and
  /// connect to a clinician later via [linkToClinician]. This keeps the
  /// app explorable by someone who has heard about it but has not yet
  /// been given a code by a doctor.
  ///
  /// The role is hard-coded and independently enforced by the security
  /// rules. There is deliberately no parameter for it: a client that
  /// could choose its own role could grant itself clinician access and
  /// read every patient's record.
  Future<void> signUpPatient({
    required String email,
    required String password,
    required String name,
    required bool acceptedTerms,
    required bool researchConsent,
    String? clinicianCode,
  }) async {
    // the form requires the tick; the security rules require the fields
    if (!acceptedTerms) {
      throw const SignUpException('Please read and accept the terms of use to create your account.');
    }
    if (debugSignUp != null) return debugSignUp!();

    // Resolve the code BEFORE creating the account, so an invalid code
    // does not leave a half-made account behind.
    ClinicianCode? code;
    final trimmedCode = clinicianCode?.trim() ?? '';
    if (trimmedCode.isNotEmpty) {
      code = await lookupClinicianCode(trimmedCode);
      if (code == null) {
        throw const SignUpException(
          'That clinician code was not recognised. Check it with your '
          'doctor, or leave it blank and connect later.',
        );
      }
    }

    fb_auth.UserCredential cred;
    try {
      cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      throw SignUpException(messageFor(e));
    }

    final uid = cred.user!.uid;

    try {
      await _db.collection('users').doc(uid).set({
        'email': email.trim(),
        'name': name.trim(),
        'role': 'patient',
        // Omitted entirely when unassigned rather than written as null.
        // The security rule that permits a later one-time link checks
        // that the field is ABSENT, so an explicit null would block it.
        if (code != null) 'assignedClinicianId': code.clinicianId,
        'createdAt': FieldValue.serverTimestamp(),
        ...ConsentService.acceptanceFields(research: researchConsent),
      });
    } catch (e) {
      try {
        await cred.user?.delete();
      } catch (_) {
        // If deletion also fails the account can be cleaned up from the
        // console; surfacing the original error is more useful.
      }
      throw SignUpException(
        'Your account could not be set up. Please try again. ($e)',
      );
    }

    // The confirmation link; a failure here (offline, quota) does not undo
    // the account: the dashboard card can send it again.
    try {
      await sendEmailVerification();
    } catch (e) {
      debugPrint('Could not send the confirmation email: $e');
    }

    await fetchCurrentUserProfile();
  }

  // ---------------------------------------------------------------
  // Linking to a clinician after sign-up
  // ---------------------------------------------------------------

  /// Links the signed-in patient to a clinician using an enrolment code.
  ///
  /// This is a ONE-TIME action. The security rules permit writing
  /// `assignedClinicianId` only when it is currently absent, so a patient
  /// cannot later switch clinicians or detach themselves. That constraint
  /// is deliberate: a patient whose readings have been flagged should not
  /// be able to quietly remove themselves from the clinician who flagged
  /// them. Corrections are made administratively.
  Future<ClinicianCode> linkToClinician(String rawCode) async {
    final me = _auth.currentUser;
    if (me == null) {
      throw const SignUpException('You must be signed in to do this.');
    }

    if (_currentProfile?.isAssigned ?? false) {
      throw const SignUpException(
        'Your account is already connected to a clinician. Contact your '
        'care team if this needs to change.',
      );
    }

    final code = await lookupClinicianCode(rawCode);
    if (code == null) {
      throw const SignUpException(
        'That code was not recognised. Please check it with your doctor.',
      );
    }

    try {
      await _db.collection('users').doc(me.uid).update({
        'assignedClinicianId': code.clinicianId,
      });
    } catch (e) {
      throw SignUpException('Could not connect to that clinician. ($e)');
    }

    await fetchCurrentUserProfile();
    return code;
  }

  // ---------------------------------------------------------------
  // Profile
  // ---------------------------------------------------------------

  /// The signed-in user's profile, live. AuthGate follows it, so a profile
  /// written just after the account (sign-up) is not missed. A document
  /// absent from the local cache is waited for; one the server says does not
  /// exist gives null.
  Stream<AppUser?> watchProfile(String uid) => _db
      .collection('users')
      .doc(uid)
      .snapshots()
      .where((s) => s.exists || !s.metadata.isFromCache)
      .map((s) => _currentProfile = s.exists ? AppUser.fromFirestore(uid, s.data()!) : null);

  Future<AppUser?> fetchCurrentUserProfile() async {
    final fbUser = _auth.currentUser;
    if (fbUser == null) {
      _currentProfile = null;
      return null;
    }
    final doc = await _db.collection('users').doc(fbUser.uid).get();
    if (!doc.exists) {
      _currentProfile = null;
      return null;
    }
    _currentProfile = AppUser.fromFirestore(fbUser.uid, doc.data()!);
    return _currentProfile;
  }

  // ---------------------------------------------------------------
  // Error messages
  // ---------------------------------------------------------------

  String messageFor(Object error) {
    if (error is SignUpException) return error.message;
    if (error is fb_auth.FirebaseAuthException) {
      switch (error.code) {
        case 'user-not-found':
        case 'wrong-password':
        case 'invalid-credential':
          return 'Incorrect email or password.';
        case 'invalid-email':
          return "That email address doesn't look right.";
        case 'email-already-in-use':
          return 'An account already exists for that email. Try signing in.';
        case 'weak-password':
          return 'Please choose a password of at least 6 characters.';
        case 'user-disabled':
          return 'This account has been disabled.';
        case 'too-many-requests':
          return 'Too many attempts — please wait a moment and try again.';
        case 'network-request-failed':
          return 'No internet connection.';
        default:
          return 'Sign-in failed (${error.code}).';
      }
    }
    return 'Something went wrong. Please try again.';
  }
}
