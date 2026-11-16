import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemonitor/models/app_user.dart';
import 'package:telemonitor/screens/signup_screen.dart';
import 'package:telemonitor/screens/terms_screen.dart';
import 'package:telemonitor/services/auth_service.dart';
import 'package:telemonitor/services/consent_service.dart';
import 'package:telemonitor/widgets/verify_email_card.dart';

Widget _app(Widget home) => MaterialApp(home: home);

void main() {
  group('profile fields', () {
    test('terms and research consent are read from the profile', () {
      final t = DateTime.utc(2026, 11, 14, 9);
      final u = AppUser.fromFirestore('u1', {
        'email': 'a@b.org',
        'role': 'patient',
        'termsVersion': ConsentService.termsVersion,
        'termsAcceptedAt': Timestamp.fromDate(t),
        'researchConsent': true,
      });
      expect(u.termsVersion, ConsentService.termsVersion);
      expect(u.termsAcceptedAt!.isAtSameMomentAs(t), isTrue);
      expect(u.researchConsent, isTrue);
    });

    test('an account made before the terms has no consent', () {
      final u = AppUser.fromFirestore('u1', {'email': 'a@b.org', 'role': 'patient'});
      expect(u.termsVersion, isNull);
      expect(u.researchConsent, isFalse);
    });

    test('the fields written at sign-up name the current version', () {
      final f = ConsentService.acceptanceFields(research: false);
      expect(f['termsVersion'], ConsentService.termsVersion);
      expect(f['researchConsent'], isFalse);
      expect(f.keys, containsAll(['termsAcceptedAt', 'researchConsentAt']));
    });

    test('sign-up without accepting the terms is refused before any account is made', () async {
      await expectLater(
        AuthService.instance.signUpPatient(
            email: 'a@b.org', password: 'secret1', name: 'A', acceptedTerms: false, researchConsent: true),
        throwsA(isA<SignUpException>()),
      );
    });
  });

  group('screens', () {
    testWidgets('the sign-up form asks for the terms before creating the account', (tester) async {
      tester.view.physicalSize = const Size(1080, 3200);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(const SignUpScreen()));
      await tester.enterText(find.byType(TextField).at(0), 'Aline Nkeng');
      await tester.enterText(find.byType(TextField).at(1), 'a@b.org');
      await tester.enterText(find.byType(TextField).at(2), 'secret1');
      final create = find.widgetWithText(ElevatedButton, 'Create account');
      await tester.ensureVisible(create);
      await tester.tap(create);
      await tester.pump();
      expect(find.text('Please read and accept the terms of use to create your account.'), findsOneWidget);
      expect(find.byType(Checkbox), findsNWidgets(2));
    });

    testWidgets('the terms screen continues only once the terms are ticked', (tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.75;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(AcceptTermsScreen(onAccepted: () {})));
      FilledButton button() => tester.widget<FilledButton>(find.byType(FilledButton));
      expect(button().onPressed, isNull);
      await tester.tap(find.byType(Checkbox).first);
      await tester.pump();
      expect(button().onPressed, isNotNull);
      // the research tick stays optional and separate
      expect(tester.widget<Checkbox>(find.byType(Checkbox).last).value, isFalse);
    });

    testWidgets('the email reminder shows only while the address is not confirmed', (tester) async {
      AuthService.instance.debugProfile =
          const AppUser(uid: 'u1', email: 'a@b.org', name: 'A', role: UserRole.patient);
      addTearDown(() {
        AuthService.instance.debugEmailVerified = null;
        AuthService.instance.debugProfile = null;
      });

      AuthService.instance.debugEmailVerified = false;
      await tester.pumpWidget(_app(const Scaffold(body: VerifyEmailCard())));
      expect(find.text('Confirm your email address'), findsOneWidget);
      expect(find.textContaining('a@b.org'), findsOneWidget);

      AuthService.instance.debugEmailVerified = true;
      await tester.pumpWidget(_app(const Scaffold(body: VerifyEmailCard(key: ValueKey(2)))));
      expect(find.text('Confirm your email address'), findsNothing);
    });
  });
}
