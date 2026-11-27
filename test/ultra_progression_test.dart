import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/models/mission_models.dart';
import 'package:shared_xi/screens/progression_center_page.dart';
import 'package:shared_xi/screens/season_pass_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'package:shared_xi/widgets/hub_ui.dart';

import 'player_experience_test.dart' show ProgressFake, open, reveal;
import 'season_pass_page_test.dart' show SeasonFake;

Future<void> _show(WidgetTester t, Widget page) async {
  t.view.physicalSize = const Size(390, 3000);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(MaterialApp(theme: OrtakSahaTheme.dark, home: page));
  await t.pumpAndSettle();
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('daily check-in marks claimed, ready and locked days', (t) async {
    await open(t, ProgressionCenterPage(gateway: ProgressFake()));
    // The fixture's next reward is day 4 of 7 and can be claimed now.
    for (final day in [1, 2, 3]) {
      expect(find.byKey(ValueKey('daily-day-$day-claimed')), findsOneWidget);
    }
    expect(find.byKey(const ValueKey('daily-day-4-ready')), findsOneWidget);
    for (final day in [5, 6, 7]) {
      expect(find.byKey(ValueKey('daily-day-$day-locked')), findsOneWidget);
    }
    expect(find.text('4. gün ödülünü al'), findsOneWidget);
    expect(find.byType(DailyResetCountdown), findsOneWidget);
    // One mission waits to be claimed.
    await reveal(t, find.text('1 ÖDÜL HAZIR'));
    expect(find.text('1 ÖDÜL HAZIR'), findsOneWidget);
  });

  testWidgets('weekly tab shows claimed rewards against the weekly limit', (
    t,
  ) async {
    final g = ProgressFake()
      ..missionData = MissionProfile.fromMap({
        'dateKey': '2026-09-23',
        'weekKey': '2026-W39',
        'weeklyEnabled': true,
        'weeklyClaimLimit': 2,
        'weeklyCompletedCount': 1,
        'daily': [],
        'weekly': [],
        'general': [],
      });
    await open(t, ProgressionCenterPage(gateway: g));
    await reveal(t, find.text('Haftalık'));
    await t.tap(find.text('Haftalık'));
    await t.pumpAndSettle();
    await reveal(t, find.byKey(const ValueKey('weekly-progress')));
    expect(find.text('1/2 haftalık ödül alındı'), findsOneWidget);
  });

  testWidgets('season route claims every ready reward at once', (t) async {
    final g = SeasonFake();
    await _show(t, SeasonPassPage(gateway: g));
    expect(find.text('Kademe 5 / 20'), findsOneWidget);
    expect(find.text('ÜCRETSİZ YOL'), findsOneWidget);
    expect(find.text('PRO YOL'), findsOneWidget);
    // The next locked stop says how far away it is.
    expect(find.text('50 SP kaldı'), findsWidgets);
    await t.tap(find.text('Tümünü al (5 hazır)'));
    await t.pumpAndSettle();
    expect(g.claims, 5);
    expect(find.textContaining('Tümünü al'), findsNothing);
    expect(t.takeException(), isNull);
  });
}
