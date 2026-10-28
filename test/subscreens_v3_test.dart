import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/app/game_catalog.dart';
import 'package:shared_xi/screens/games_catalog_page.dart';
import 'package:shared_xi/screens/story_mode_selection_page.dart';
import 'package:shared_xi/theme/app_theme.dart';
import 'package:shared_xi/widgets/hub_ui.dart';

import 'support/qa_capture.dart';

final _boundary = GlobalKey();

Future<BuildContext> _open(WidgetTester t, Widget page, bool light) async {
  t.view.physicalSize = const Size(390, 1600);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
      home: RepaintBoundary(key: _boundary, child: page),
    ),
  );
  await t.pumpAndSettle();
  return t.element(find.byType(Scaffold).first);
}

void main() {
  setUpAll(loadQaFonts);
  for (final light in [false, true]) {
    testWidgets('category rows put the genre label above the title '
        'light=$light', (t) async {
      final kadro = GameCatalog.groups.first;
      await _open(t, GamesCatalogPage(group: kadro), light);
      await captureQa(t, _boundary, 'category-${light ? 'light' : 'dark'}');
      for (final (tag, title) in [
        ('GÜNLÜK GÖREV', 'Squad Challenge'),
        ('HARF', 'Harf 11'),
      ]) {
        final tagAt = t.getTopLeft(find.text(tag));
        final titleAt = t.getTopLeft(find.text(title));
        expect(tagAt.dy, lessThan(titleAt.dy), reason: title);
        expect(tagAt.dx, titleAt.dx, reason: title);
      }
      expect(t.takeException(), isNull);
    });

    testWidgets('story page carries the amber story accent light=$light', (
      t,
    ) async {
      final context = await _open(t, const StoryModeSelectionPage(), light);
      final amber = hubAmber(context);
      await captureQa(t, _boundary, 'story-${light ? 'light' : 'dark'}');
      final pill = t.widget<HubPill>(
        find.ancestor(
          of: find.text('ÖNE ÇIKAN • EFSANE'),
          matching: find.byType(HubPill),
        ),
      );
      expect(pill.color, amber);
      final rowIcon = t.widget<Icon>(
        find.byIcon(storySubModes.first.icon).first,
      );
      expect(rowIcon.color, amber);
      expect(t.takeException(), isNull);
    });
  }
}
