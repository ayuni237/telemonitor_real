import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemonitor/screens/signup_screen.dart';
import 'package:telemonitor/services/auth_service.dart';

void main() {
  testWidgets('the sign-up page closes once the account is made, uncovering the home', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    var accounts = 0;
    AuthService.instance.debugSignUp = () async => accounts++;
    addTearDown(() => AuthService.instance.debugSignUp = null);

    // the root stands for AuthGate, which shows the home under the sign-up page
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen())),
              child: const Text('home'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pumpAndSettle();

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Aline Nkeng');
    await tester.enterText(fields.at(1), 'a.nkeng@example.org');
    await tester.enterText(fields.at(2), 'secret12');
    await tester.tap(find.byType(Checkbox).first); // the terms of use
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(accounts, 1);
    expect(find.byType(SignUpScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('a refused sign-up keeps the page open with the reason', (tester) async {
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    AuthService.instance.debugSignUp = () async => throw const SignUpException('An account already exists.');
    addTearDown(() => AuthService.instance.debugSignUp = null);

    await tester.pumpWidget(const MaterialApp(home: SignUpScreen()));
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'Aline Nkeng');
    await tester.enterText(fields.at(1), 'a.nkeng@example.org');
    await tester.enterText(fields.at(2), 'secret12');
    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(find.byType(SignUpScreen), findsOneWidget);
    expect(find.text('An account already exists.'), findsOneWidget);
    final button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Create account'));
    expect(button.onPressed, isNotNull, reason: 'the button is usable again');
  });
}
