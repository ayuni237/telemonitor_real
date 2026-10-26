// ignore_for_file: invalid_use_of_visible_for_testing_member
// Screen captures for the design review, with the real Roboto font, in light
// and dark mode at phone size. Not part of `flutter test` (outside test/):
//
//   flutter test test_screens --update-goldens
//
// PNGs are written to test_screens/goldens/. A layout overflow fails the run.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemonitor/models/app_user.dart';
import 'package:telemonitor/models/clinical_event.dart';
import 'package:telemonitor/models/reading.dart';
import 'package:telemonitor/models/risk_assessment.dart';
import 'package:telemonitor/screens/connect_clinician_screen.dart';
import 'package:telemonitor/screens/login_screen.dart';
import 'package:telemonitor/screens/patient/edit_profile_screen.dart';
import 'package:telemonitor/screens/patient/care_finder_screen.dart';
import 'package:telemonitor/screens/patient/history_screen.dart';
import 'package:telemonitor/screens/patient/log_reading_screen.dart';
import 'package:telemonitor/screens/patient/patient_home.dart';
import 'package:telemonitor/screens/signup_screen.dart';
import 'package:telemonitor/services/auth_service.dart';
import 'package:telemonitor/services/clinician_queue.dart';
import 'package:telemonitor/services/queue_logic.dart';
import 'package:telemonitor/services/readings_repository.dart';
import 'package:telemonitor/theme/app_theme.dart';
import 'package:telemonitor/widgets/event_widgets.dart';
import 'package:telemonitor/widgets/risk_card.dart';

final _fonts = '${Platform.environment['FLUTTER_ROOT'] ?? 'C:/flutter'}/bin/cache/artifacts/material_fonts';

Future<void> _loadFonts() async {
  Future<ByteData> f(String name) async => ByteData.sublistView(File('$_fonts/$name').readAsBytesSync());
  final roboto = FontLoader('Roboto')
    ..addFont(f('roboto-regular.ttf'))
    ..addFont(f('roboto-medium.ttf'))
    ..addFont(f('roboto-bold.ttf'));
  await roboto.load();
  await (FontLoader('MaterialIcons')..addFont(f('materialicons-regular.otf'))).load();
}

final now = DateTime.now();
Reading r(String id, int hoursAgo,
        {int? sbp, int? dbp, int? hr, double? glucose, String ctx = 'Fasting', int count = 1, String? supersedes}) =>
    Reading(
      id: id,
      timestamp: now.subtract(Duration(hours: hoursAgo)),
      recordedAt: now.subtract(Duration(hours: hoursAgo)),
      sbp: sbp,
      dbp: dbp,
      hr: hr,
      glucose: glucose,
      context: ctx,
      readingCount: count,
      firstSbp: count == 2 ? (sbp ?? 0) + 4 : null,
      firstDbp: count == 2 ? dbp : null,
      supersedes: supersedes,
    );

final readings = [
  r('a', 2, sbp: 164, dbp: 98, hr: 82, glucose: 7.9, count: 2),
  r('b', 14, sbp: 152, dbp: 94, hr: 78, ctx: 'After meal'),
  r('c', 26, sbp: 147, dbp: 91, glucose: 10.6, ctx: 'After meal'),
  r('d', 50, sbp: 139, dbp: 88, hr: 74),
  r('e', 98, sbp: 141, dbp: 90, glucose: 6.1),
  r('f', 170, sbp: 133, dbp: 85, hr: 70),
  r('g', 260, sbp: 128, dbp: 82, glucose: 5.6),
];

const patient = AppUser(
  uid: 'k3f9a2c7patient',
  email: 'a.nkeng@example.org',
  name: 'Aline Nkeng',
  role: UserRole.patient,
  assignedClinicianId: 'doc',
  age: 58,
  sex: 'Female',
  conditions: ['Hypertension', 'Type 2 diabetes'],
  medications: ['Amlodipine', 'Metformin'],
);

ClinicalEvent ev(String id, RiskTier tier, TriggerSource src, int hoursAgo,
        {bool open = true, bool escalated = false}) =>
    ClinicalEvent(
      id: id,
      patientId: patient.uid,
      clinicianId: 'doc',
      triggeredAt: now.subtract(Duration(hours: hoursAgo)),
      source: src,
      tier: tier,
      trigger: src == TriggerSource.nonTransmission
          ? {'checkupPeriodDays': 3}
          : {'sbp': 182, 'dbp': 112, 'hr': 96, 'glucose': null, 'context': 'Morning'},
      thresholdVersion: '2026-10-19',
      score: src == TriggerSource.model ? 0.34 : null,
      modelVersion: src == TriggerSource.model ? 'haemodynamic-catboost-1a2b3c' : null,
      isOpen: open,
      verdict: open ? null : Verdict.confirmed,
      action: open ? null : ClinicalAction.consultation,
      reviewedAt: open ? null : now.subtract(const Duration(hours: 1)),
      comment: open ? '' : 'Seen in clinic tomorrow morning.',
      escalatedAt: escalated ? now.subtract(const Duration(hours: 1)) : null,
    );

Widget queueScreen() => Scaffold(
      appBar: AppBar(title: const Text('My Patients')),
      body: Builder(builder: (context) {
        return ListView(padding: const EdgeInsets.all(16), children: [
          QueueRow(
              item: QueueItem(
                  event: ev('1', RiskTier.red, TriggerSource.rule, 5, escalated: true),
                  patient: patient,
                  sbpTrend: TrendDirection.rising,
                  glucoseTrend: TrendDirection.unknown,
                  lastReviewedAt: now.subtract(const Duration(days: 6))),
              onOpen: () {}),
          QueueRow(
              item: QueueItem(
                  event: ev('2', RiskTier.yellow, TriggerSource.model, 20),
                  patient: patient,
                  sbpTrend: TrendDirection.stable,
                  glucoseTrend: TrendDirection.falling),
              onOpen: () {}),
          QueueRow(
              item: QueueItem(
                  event: ev('3', RiskTier.yellow, TriggerSource.nonTransmission, 30),
                  patient: const AppUser(uid: 'zz11xx', email: '', name: '', role: UserRole.patient),
                  sbpTrend: TrendDirection.unknown,
                  glucoseTrend: TrendDirection.unknown,
                  isForeign: true),
              onOpen: () {}),
          EventLogTile(event: ev('4', RiskTier.red, TriggerSource.rule, 50, open: false)),
        ]);
      }),
    );

Widget riskScreen(bool clinician) => Scaffold(
      appBar: AppBar(title: Text(clinician ? 'Risk card — clinician' : 'Risk card — patient')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: RiskCard(readings: readings, age: 58, sex: 'Female', forClinician: clinician),
      ),
    );

final screens = <String, Widget Function()>{
  'login': () => const LoginScreen(),
  'signup': () => const SignUpScreen(),
  'home': () => const PatientHome(),
  'log_reading': () => const LogReadingScreen(),
  'correct_reading': () => LogReadingScreen(correcting: readings.first),
  'history': () => const HistoryScreen(),
  'risk_patient': () => riskScreen(false),
  'risk_clinician': () => riskScreen(true),
  'queue': queueScreen,
  'care_finder': () => const CareFinderScreen(),
  'edit_profile': () => const EditProfileScreen(profile: patient),
  'connect_clinician': () => const ConnectClinicianScreen(),
};

/// Screens checked again with the text enlarged by 30 %, as many older
/// patients set their phone: nothing may overflow.
const largeText = ['home', 'log_reading', 'history', 'queue'];

void main() {
  setUpAll(() async {
    await _loadFonts();
    AuthService.instance.debugProfile = patient;
    ReadingsRepository.instance.debugSetReadings(readings);
  });

  for (final (dark, scale) in [(false, 1.0), (true, 1.0), (false, 1.3)]) {
    for (final e in screens.entries) {
      if (scale != 1.0 && !largeText.contains(e.key)) continue;
      final name = '${e.key}_${dark ? 'dark' : 'light'}${scale != 1.0 ? '_large' : ''}';
      testWidgets(name, (tester) async {
        tester.view.physicalSize = const Size(1080, 2340);
        tester.view.devicePixelRatio = 2.75;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: e.value(),
        ));
        for (var i = 0; i < 5; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
      });
    }
  }
}
