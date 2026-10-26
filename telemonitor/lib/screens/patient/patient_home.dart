import 'package:flutter/material.dart';

import 'chat_screen.dart';
import 'history_screen.dart';
import 'log_reading_screen.dart';
import 'patient_dashboard.dart';
import 'profile_screen.dart';

/// The patient's shell: four tabs (home, history, messages, profile) and one
/// primary action, logging a reading, always one tap away on the home and
/// history tabs. Only the visible tab is built: an open message thread counts
/// as being online and marks messages as read, so it must not stay alive
/// behind another tab. The tabs' data live in the repositories, so nothing is
/// lost when switching.
class PatientHome extends StatefulWidget {
  const PatientHome({super.key});

  @override
  State<PatientHome> createState() => _PatientHomeState();
}

class _PatientHomeState extends State<PatientHome> {
  int _index = 0;

  static const _tabs = [PatientDashboard(), HistoryScreen(), ChatScreen(), ProfileScreen()];

  void _log() => Navigator.push(context, MaterialPageRoute(builder: (_) => const LogReadingScreen()));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _tabs[_index],
      floatingActionButton: _index <= 1
          ? FloatingActionButton.extended(
              onPressed: _log,
              icon: const Icon(Icons.add),
              label: const Text('Log a reading', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'History'),
          NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline), selectedIcon: Icon(Icons.chat_bubble), label: 'Messages'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
