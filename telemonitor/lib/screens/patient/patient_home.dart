import 'package:flutter/material.dart';

import '../../services/push_service.dart';
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
  static const _messages = 2;

  @override
  void initState() {
    super.initState();
    PushService.instance.opened.addListener(_openFromPush);
    // a notification that launched the app was tapped before this screen existed
    WidgetsBinding.instance.addPostFrameCallback((_) => _openFromPush());
  }

  @override
  void dispose() {
    PushService.instance.opened.removeListener(_openFromPush);
    super.dispose();
  }

  /// A tapped message notification: the Messages tab, above whatever was open.
  void _openFromPush() {
    if (!mounted || PushService.instance.opened.value == null) return;
    PushService.instance.opened.value = null;
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _index = _messages);
  }

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
