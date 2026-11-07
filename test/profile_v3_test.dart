import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/models/progression_models.dart';
import 'package:shared_xi/screens/player_profile_page.dart';
import 'package:shared_xi/services/profile_service.dart';
import 'package:shared_xi/theme/app_theme.dart';

import 'support/qa_capture.dart';

final _boundary = GlobalKey();

UserProfile _profile(List<RankedResult> results) => UserProfile(
  uid: 'test',
  displayName: 'Kaptan Berat',
  normalizedName: 'kaptanberat',
  accountType: 'google',
  wins: 12,
  losses: 4,
  elo: 1240,
  recentMatches: [
    for (final (i, r) in results.indexed)
      MatchHistoryEntry(matchId: 'm$i', result: r),
  ],
);

Future<void> _open(
  WidgetTester t,
  UserProfile profile, {
  bool light = false,
}) async {
  t.view.physicalSize = const Size(390, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
      home: RepaintBoundary(
        key: _boundary,
        child: Scaffold(
          body: PlayerProfileBody(
            profile: profile,
            level: const ProgressionLevel(
              level: 12,
              currentXp: 1840,
              nextLevelXp: 2500,
              cap: 50,
            ),
            onEditNickname: () {},
            onEditAvatar: () {},
            onLinkAccount: () {},
            onOpen: (_) {},
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadQaFonts);
  for (final light in [false, true]) {
    testWidgets('profile shows level ring and last five results light=$light', (
      t,
    ) async {
      const r = RankedResult.values;
      await _open(
        t,
        _profile([
          r[0], r[0], r[2], r[1], r[0], r[1], r[0], // newest first; 7 matches
        ]),
        light: light,
      );
      final ring = t.widget<CircularProgressIndicator>(
        find.descendant(
          of: find.byKey(const ValueKey('profile-level-ring')),
          matching: find.byType(CircularProgressIndicator),
        ),
      );
      expect(ring.value, closeTo(1840 / 2500, .01));
      await captureQa(t, _boundary, 'profile-v3-${light ? 'light' : 'dark'}');
      final strip = find.byKey(const ValueKey('profile-form-strip'));
      expect(strip, findsOneWidget);
      final labels = t
          .widgetList<Text>(
            find.descendant(of: strip, matching: find.byType(Text)),
          )
          .map((w) => w.data)
          .toList();
      expect(labels, ['Son 5 maç', 'G', 'G', 'B', 'M', 'G']);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('form strip stays hidden without ranked matches', (t) async {
    await _open(t, _profile(const []));
    expect(find.byKey(const ValueKey('profile-form-strip')), findsNothing);
  });
}
