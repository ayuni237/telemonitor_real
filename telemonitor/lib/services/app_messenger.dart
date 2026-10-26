import 'package:flutter/material.dart';

/// App-wide snack bars, for messages that arrive after the screen that caused
/// them has closed: a push notification received while the app is open, or a
/// write that the server refused once the connection returned.
class AppMessenger {
  AppMessenger._();

  static final GlobalKey<ScaffoldMessengerState> key = GlobalKey<ScaffoldMessengerState>();

  static void show(String text, {bool error = false}) {
    key.currentState?.showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: error ? const Color(0xFFA32D2D) : null,
      duration: const Duration(seconds: 6),
    ));
  }
}
