import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:telemonitor/l10n/l10n.dart';
import 'package:telemonitor/screens/login_screen.dart';

Map<String, dynamic> _arb(String lang) =>
    jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;

Set<String> _placeholders(String s) => RegExp(r'\{(\w+)[,}]').allMatches(s).map((m) => m[1]!).toSet();

/// The app as main() builds it: the language comes from LocaleController.
Widget _app(Widget home) => ListenableBuilder(
      listenable: LocaleController.instance,
      builder: (_, _) => MaterialApp(
        locale: LocaleController.instance.locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await LocaleController.instance.load();
    await LocaleController.instance.choose('en');
  });

  test('every text exists in French, with the same placeholders', () {
    final en = _arb('en'), fr = _arb('fr');
    final keys = en.keys.where((k) => !k.startsWith('@'));
    expect(fr.keys.where((k) => !k.startsWith('@')).toSet(), keys.toSet());
    for (final k in keys) {
      expect((fr[k] as String).trim(), isNotEmpty, reason: k);
      expect(_placeholders(fr[k] as String), _placeholders(en[k] as String), reason: k);
    }
  });

  testWidgets('EN | FR on the login screen switches the app and is remembered', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_app(const LoginScreen()));
    expect(find.text('Forgot password?'), findsOneWidget);

    await tester.tap(find.text('FR'));
    await tester.pumpAndSettle();
    expect(find.text('Mot de passe oublié ?'), findsOneWidget);
    expect(find.text('Se connecter'), findsOneWidget);
    expect((await SharedPreferences.getInstance()).getString('language'), 'fr');

    await tester.tap(find.text('EN'));
    await tester.pumpAndSettle();
    expect(find.text('Sign In'), findsOneWidget);
  });

  test('a phone where the user never chose takes the language of the account', () async {
    SharedPreferences.setMockInitialValues({});
    await LocaleController.instance.load(); // nothing saved: the phone's language (English in tests)
    await LocaleController.instance.syncWithAccount('uid1', 'fr');
    expect(LocaleController.instance.code, 'fr');
    // once chosen on the phone, the phone's choice stays
    await LocaleController.instance.choose('en');
    await LocaleController.instance.syncWithAccount('uid1', 'fr');
    expect(LocaleController.instance.code, 'en');
  });

  test('times and dates read naturally in French', () async {
    await initializeDateFormatting();
    await LocaleController.instance.choose('fr');
    final fr = lookupAppLocalizations(const Locale('fr'));
    final now = DateTime(2026, 11, 16, 15, 0);
    expect(fr.ago(DateTime(2026, 11, 16, 14, 55), now), 'il y a 5 min');
    expect(fr.dayAndTime(DateTime(2026, 11, 15, 9, 10), now), 'Hier, 09:10');
    expect(fr.dayAndTime(DateTime(2026, 11, 3, 8, 0), now), '3 nov., 08:00');
    expect(fr.readingsPending(2), startsWith('2 mesures sont enregistrées'));
    expect(fr.homeLevel(2), 'Rouge');
    expect(fr.sexLabel('Female'), 'Femme');
  });
}
