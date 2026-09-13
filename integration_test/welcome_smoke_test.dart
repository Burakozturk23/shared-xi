import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_xi/screens/welcome_page.dart';
import 'package:shared_xi/theme/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Linkball core navigation renders on Android', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const WelcomePage(observeAuth: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('LINKBALL'), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(4));
    await tester.tap(find.text('Oyunlar').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'lingo');
    await tester.pumpAndSettle();
    expect(find.text('Futbol Lingo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
