import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/consent_service.dart';
import '../services/push_service.dart';
import '../theme/app_theme.dart';
import '../services/readings_repository.dart';
import 'login_screen.dart';
import 'terms_screen.dart';
import 'patient/patient_home.dart';
import 'clinician/clinician_home_screen.dart';

/// Root routing widget: Login vs Patient view vs Clinician view, based
/// on live Firebase Auth state plus the role stored in Firestore.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<fb_auth.User?>(
      stream: AuthService.instance.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _SplashLoader();
        }

        final firebaseUser = snapshot.data;
        if (firebaseUser == null) {
          return const LoginScreen();
        }

        return _ProfileGate(key: ValueKey(firebaseUser.uid), uid: firebaseUser.uid);
      },
    );
  }
}

/// Follows the signed-in user's profile document, live rather than read
/// once: at sign-up the account exists a moment before its profile, and a
/// single read made in between would never see it.
class _ProfileGate extends StatefulWidget {
  final String uid;
  const _ProfileGate({super.key, required this.uid});

  @override
  State<_ProfileGate> createState() => _ProfileGateState();
}

class _ProfileGateState extends State<_ProfileGate> {
  late final Stream<AppUser?> _profile = AuthService.instance.watchProfile(widget.uid);

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppUser?>(
      stream: _profile,
      builder: (context, profileSnapshot) {
        if (profileSnapshot.connectionState == ConnectionState.waiting) {
          return const _SplashLoader();
        }

        final profile = profileSnapshot.data;
        if (profile == null) {
          return _NoProfileScreen(uid: widget.uid);
        }
        // idempotent: registers this device for the worker's notifications
        PushService.instance.start(profile.uid);

        if (profile.role == UserRole.clinician) {
          return const ClinicianHomeScreen();
        }
        return _PatientShell(profile: profile);
      },
    );
  }
}

/// Binds the shared readings repository to the signed-in patient before
/// showing their dashboard. Binding lives here — in initState, once —
/// rather than inside build(), so it isn't re-triggered on every
/// rebuild.
///
/// A patient who has not accepted the current terms of use (an account made
/// before them, or before their latest version) accepts them first.
class _PatientShell extends StatefulWidget {
  final AppUser profile;
  const _PatientShell({required this.profile});

  @override
  State<_PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<_PatientShell> {
  late bool _termsAccepted = widget.profile.termsVersion == ConsentService.termsVersion;

  @override
  void initState() {
    super.initState();
    ReadingsRepository.instance.bindTo(widget.profile.uid);
  }

  @override
  Widget build(BuildContext context) {
    if (_termsAccepted) return const PatientHome();
    return AcceptTermsScreen(
      updated: widget.profile.termsVersion != null,
      initialResearch: widget.profile.researchConsent,
      onAccepted: () => setState(() => _termsAccepted = true),
    );
  }
}

class _SplashLoader extends StatelessWidget {
  const _SplashLoader();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(child: CircularProgressIndicator(color: Colors.white)),
    );
  }
}

/// Signed in to Firebase Auth but no matching users/{uid} document.
class _NoProfileScreen extends StatelessWidget {
  final String uid;
  const _NoProfileScreen({required this.uid});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background(context),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.person_off_outlined,
                  size: 48, color: AppColors.textMuted(context)),
              const SizedBox(height: 16),
              Text(
                'No profile found for this account.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.textPrimary(context)),
              ),
              const SizedBox(height: 8),
              Text(
                'Add a Firestore document at users/$uid with an email, '
                'name, and role field to finish setting up this account.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary(context)),
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => AuthService.instance.signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
