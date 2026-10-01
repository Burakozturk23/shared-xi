import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/data/season_portrait_catalog.dart';
import 'package:shared_xi/models/player.dart';
import 'package:shared_xi/widgets/player_avatar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'source sheets decode at original dimensions and all crops fit',
    () async {
      expect(SeasonPortraitCatalog.byPlayerId.length, 81);
      for (final asset
          in SeasonPortraitCatalog.byPlayerId.values
              .map((s) => s.asset)
              .toSet()) {
        final bytes = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
        );
        final frame = await codec.getNextFrame();
        for (final spec in SeasonPortraitCatalog.byPlayerId.values.where(
          (s) => s.asset == asset,
        )) {
          expect(frame.image.width, spec.sheetWidth);
          expect(frame.image.height, spec.sheetHeight);
          expect(spec.left, greaterThanOrEqualTo(0));
          expect(spec.top, greaterThanOrEqualTo(0));
          expect(spec.left + spec.width, lessThanOrEqualTo(spec.sheetWidth));
          expect(spec.top + spec.height, lessThanOrEqualTo(spec.sheetHeight));
        }
        frame.image.dispose();
        codec.dispose();
      }
      for (final id in [424784, 28900, 52920, 68293, 588097]) {
        expect(
          SeasonPortraitCatalog.forPlayerId(id),
          isNull,
          reason: 'Namesake $id',
        );
      }
    },
  );
  testWidgets('season faces, legend priority and unknown fallback render', (
    tester,
  ) async {
    final key = GlobalKey();
    final players = [
      (8198, 'Cristiano Ronaldo'),
      (28003, 'Lionel Messi'),
      (4000000067, 'Clint Dempsey'),
      (4000000068, 'Javier Zanetti'),
      (4000000069, 'Rio Ferdinand'),
      (44501, 'Marcelo'),
      (44352, 'Luis Suárez'),
      (3373, 'Ronaldinho'),
      (424784, 'Luis Suárez'),
    ];
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox(
                width: 420,
                child: Wrap(
                  runSpacing: 16,
                  children: [
                    for (final p in players)
                      SizedBox(
                        width: 140,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            PlayerAvatar(
                              player: Player.fromJson({
                                'id': p.$1,
                                'name': p.$2,
                                'position': 'Attack',
                              }),
                              size: 96,
                            ),
                            Text(
                              p.$2,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 14, height: 1.3),
                            ),
                            Text(
                              '${p.$1}',
                              style: const TextStyle(fontSize: 12, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(() async {
      await Future<void>.delayed(const Duration(milliseconds: 500));
    });
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNWidgets(8));
    expect(find.text('LS'), findsOneWidget);
    expect(tester.takeException(), isNull);
    if (const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('.dart_tool/identity_qa/season-portraits.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    }
  });
}
