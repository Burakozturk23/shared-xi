// STEP 07B.3
//
// Device-level deterministic integration smoke.
//
// Production SharedXIApp boot intentionally includes Runtime V3 and platform
// services. The release startup path is already covered by the dedicated
// production smoke scripts. This CI integration baseline verifies that the
// real WelcomePage renders correctly on an Android device/emulator without
// introducing Firebase/network timing into the test.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:shared_xi/screens/welcome_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Linkball WelcomePage renders on Android device', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: WelcomePage()));
    await tester.pump(const Duration(milliseconds: 250));

    expect(find.text('LINKBALL'), findsOneWidget);
    expect(find.text('Ortak oyuncu evreni'), findsOneWidget);
    expect(find.text('HEMEN OYNA'), findsOneWidget);
    expect(find.byIcon(Icons.sports_soccer), findsOneWidget);
  });
}
