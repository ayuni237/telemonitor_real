import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:telemonitor/screens/login_screen.dart';

void main() {
  testWidgets('the "Forgot password?" dialog closes cleanly after "Send link"', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.75;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    final field = find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField));
    await tester.enterText(field, 'a.nkeng@example.org');
    await tester.tap(find.text('Send link'));
    // frame by frame through the closing animation: the field is still on screen
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pumpAndSettle();

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.byType(LoginScreen), findsOneWidget);
  });
}
