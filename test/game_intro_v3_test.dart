import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/theme/app_theme.dart';
import 'package:shared_xi/widgets/game_ui.dart';
import 'package:shared_xi/widgets/hub_ui.dart';

void main() {
  for (final light in [false, true]) {
    testWidgets('game intros share the V3 hero card light=$light', (t) async {
      await t.pumpWidget(
        MaterialApp(
          theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
          home: const Scaffold(
            body: GameIntro(
              icon: Icons.hub_outlined,
              title: 'Kulüpler arasında bir bağ kur.',
              message: 'Ortak futbolcuları bul.',
            ),
          ),
        ),
      );
      expect(
        find.ancestor(
          of: find.text('Kulüpler arasında bir bağ kur.'),
          matching: find.byType(HubHeroCard),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(HubIconBox),
          matching: find.byIcon(Icons.hub_outlined),
        ),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
    });
  }
}
