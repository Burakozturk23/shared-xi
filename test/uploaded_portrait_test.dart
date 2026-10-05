import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/data/uploaded_portrait_catalog.dart';
import 'package:shared_xi/models/coach.dart';
import 'package:shared_xi/widgets/coach_avatar.dart';
import 'package:shared_xi/widgets/player_portrait.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('all supplied sources decode and all portrait rectangles fit', () async {
    final specs = UploadedPortraitCatalog.portraits.values;
    expect(specs.length, 216);
    for (final asset in specs.map((p) => p.asset).toSet()) {
      final bytes = await rootBundle.load(asset);
      final codec = await ui.instantiateImageCodec(bytes.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      for (final spec in specs.where((s) => s.asset == asset)) {
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
  });

  testWidgets('coach-specific, reused player, and unknown portraits stay distinct', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Row(children: [
      for (final (id, name) in [('seed_pep', 'Pep Guardiola'), ('seed_zidane', 'Zinedine Zidane'), ('unknown', 'Unknown')])
        CoachAvatar(coach: Coach(id: id, name: name, countries: const [], clubIds: const [])),
    ]))));
    await tester.runAsync(() async { await Future<void>.delayed(const Duration(milliseconds: 400)); });
    await tester.pumpAndSettle();
    expect(find.byType(PortraitCrop), findsOneWidget);
    expect(find.byType(PlayerPortrait), findsOneWidget);
    expect(find.text('U'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
