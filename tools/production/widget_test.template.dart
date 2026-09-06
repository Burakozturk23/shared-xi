// STEP 07B.2.2
//
// Deterministic UI smoke test for the current Linkball product contract.
//
// Do not boot SharedXIApp here: production startup intentionally initializes
// Runtime V3 and schedules legacy Repository warmup. Those are integration
// concerns and make a unit/widget CI test depend on platform/database timing.
//
// This test renders the actual WelcomePage directly and verifies the visible
// home-screen identity/navigation contract without Firebase or DB side effects.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_xi/screens/welcome_page.dart';

void main() {
  testWidgets('WelcomePage renders Linkball home navigation', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: WelcomePage(),
      ),
    );

    expect(find.text('LINKBALL'), findsOneWidget);
    expect(find.text('Ortak oyuncu evreni'), findsOneWidget);
    expect(find.text('HEMEN OYNA'), findsOneWidget);
    expect(find.byIcon(Icons.sports_soccer), findsOneWidget);
  });
}
