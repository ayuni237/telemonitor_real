import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'firebase_options.dart';
import 'l10n/l10n.dart';
import 'screens/auth_gate.dart';
import 'services/app_messenger.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // Offline persistence: Firestore caches data locally and queues writes
  // made while offline, replaying them when connectivity returns.
  FirebaseFirestore.instance.settings = const Settings(
    persistenceEnabled: true,
    cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
  );

  // Loaded before runApp so the first frame is already in the chosen
  // theme and language, rather than flashing the wrong one and switching.
  await ThemeController.instance.load();
  await initializeDateFormatting(); // month and day names in French too
  await LocaleController.instance.load();

  runApp(const TeleMonitorApp());
}

class TeleMonitorApp extends StatelessWidget {
  const TeleMonitorApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Rebuilds the whole app when the theme or the language changes, so the
    // switch takes effect immediately rather than on next launch.
    return AnimatedBuilder(
      animation: Listenable.merge([ThemeController.instance, LocaleController.instance]),
      builder: (context, _) {
        return MaterialApp(
          title: 'TeleMonitor',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeController.instance.mode,
          locale: LocaleController.instance.locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          scaffoldMessengerKey: AppMessenger.key,
          home: const AuthGate(),
        );
      },
    );
  }
}
