import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/readings_repository.dart';
import 'login_screen.dart';
import 'patient/patient_dashboard.dart';
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

        return FutureBuilder<AppUser?>(
          future: AuthService.instance.fetchCurrentUserProfile(),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const _SplashLoader();
            }

            final profile = profileSnapshot.data;
            if (profile == null) {
              return _NoProfileScreen(uid: firebaseUser.uid);
            }

            if (profile.role == UserRole.clinician) {
              return const ClinicianHomeScreen();
            }
            return _PatientShell(patientId: profile.uid);
          },
        );
      },
    );
  }
}

/// Binds the shared readings repository to the signed-in patient before
/// showing their dashboard. Binding lives here — in initState, once —
/// rather than inside build(), so it isn't re-triggered on every
/// rebuild.
class _PatientShell extends StatefulWidget {
  final String patientId;
  const _PatientShell({required this.patientId});

  @override
  State<_PatientShell> createState() => _PatientShellState();
}

class _PatientShellState extends State<_PatientShell> {
  @override
  void initState() {
    super.initState();
    ReadingsRepository.instance.bindTo(widget.patientId);
  }

  @override
  Widget build(BuildContext context) => const PatientDashboard();
}

class _SplashLoader extends StatelessWidget {
  const _SplashLoader();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF1A3C6E),
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
      backgroundColor: const Color(0xFFF5F7FA),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off_outlined,
                  size: 48, color: Colors.grey),
              const SizedBox(height: 16),
              const Text(
                'No profile found for this account.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                'Add a Firestore document at users/$uid with an email, '
                'name, and role field to finish setting up this account.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
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
