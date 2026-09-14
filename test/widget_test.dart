import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/screens/welcome_page.dart';
import 'package:shared_xi/theme/app_theme.dart';

void main() {
  testWidgets(
    'Home prioritizes daily games and discovery without cloud or database',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.darkTheme,
          home: const WelcomePage(observeAuth: false),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('LINKBALL'), findsOneWidget);
      expect(find.text('Günün Maçları'), findsOneWidget);
      expect(find.text('Ortak Oyuncu Keşfi'), findsOneWidget);
      expect(find.byType(NavigationDestination), findsNWidgets(4));
      await tester.tap(find.text('Oyunlar').last);
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
