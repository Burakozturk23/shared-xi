import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/models/coach_honours.dart';
import 'package:shared_xi/screens/coach_honours_page.dart';
import 'package:shared_xi/screens/three_modes_page.dart';
import 'package:shared_xi/services/coach_honours_service.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'three_modes_page_test.dart' show FakeModes;

class ArchiveBundle extends CachingAssetBundle {
  ArchiveBundle(this.source, {this.failures = 0});
  final String source;
  int failures, calls = 0;
  @override
  Future<ByteData> load(String key) async => throw UnsupportedError(key);
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    calls++;
    if (failures > 0) {
      failures--;
      throw const FormatException('temporary load failure');
    }
    return source;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final source = File(
    'assets/data/coach_honours_archive.json',
  ).readAsStringSync();
  final catalog = CoachHonoursCatalog.fromJson(
    jsonDecode(source) as Map<String, dynamic>,
  );
  final pep = catalog.forCoach('coach_0')!;
  final missing = catalog.forCoach('coach_20')!;
  final boundary = GlobalKey();

  Future<void> mount(
    WidgetTester t,
    Widget page, {
    bool light = false,
    bool large = false,
  }) async {
    t.view.physicalSize = Size(large ? 320 : 390, 1000);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        key: UniqueKey(),
        theme: light ? OrtakSahaTheme.light : OrtakSahaTheme.dark,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(large ? 1.8 : 1)),
          child: child!,
        ),
        home: RepaintBoundary(key: boundary, child: page),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> capture(WidgetTester t, String name) async {
    if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
    await t.runAsync(() async {
      final image =
          await (boundary.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('.dart_tool/coach_archive_qa/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  setUpAll(() async {
    for (final f in [
      ('Inter', 'assets/fonts/Inter-Body-Variable.ttf'),
      ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(f.$1)..addFont(rootBundle.load(f.$2))).load();
    }
  });
  test(
    'archive is bundled, typed and keeps missing data distinct from zero',
    () async {
      final loaded = await CoachHonoursService().load();
      expect(loaded.coaches.length, 98);
      expect(loaded.snapshotDate, isNull);
      expect(loaded.coaches.where((c) => c.hasTrophyRecord).length, 80);
      expect(
        pep.honours
            .firstWhere((h) => h.competitionId == 'Champions_League_winner')
            .count,
        2,
      );
      expect(pep.honours.where((h) => h.competitionId == 'NONE'), isEmpty);
      expect(
        pep.honours.firstWhere((h) => h.category == 'individual').count,
        2,
      );
      expect(missing.hasTrophyRecord, isFalse);
      expect(missing.unclassifiedCount, isNull);
      expect(catalog.forCoach('coach_693'), isNull);
    },
  );
  test('search handles accents, full-name aliases and competition names', () {
    expect(
      CoachHonoursService.matches(
        catalog.forCoach('coach_portrait_jurgen_klopp')!,
        'jurgen klopp',
      ),
      isTrue,
    );
    expect(
      CoachHonoursService.matches(
        catalog.forCoach('coach_26')!,
        'william moyes',
      ),
      isTrue,
    );
    expect(CoachHonoursService.matches(pep, 'sampiyonlar ligi'), isTrue);
    expect(CoachHonoursService.matches(pep, 'olmayan hoca'), isFalse);
  });
  test('failed loads retry and successful loads cache', () async {
    final bundle = ArchiveBundle(source, failures: 1),
        service = CoachHonoursService(bundle: ArchiveBundle(source));
    final retry = CoachHonoursService(bundle: bundle);
    await expectLater(retry.load(), throwsFormatException);
    await retry.load();
    await retry.load();
    expect(bundle.calls, 2);
    expect(identical(await service.load(), await service.load()), isTrue);
  });
  test('invalid or unknown honours cannot become runtime achievements', () {
    for (final count in [-1, 0, 1.5]) {
      final bad = jsonDecode(source) as Map<String, dynamic>;
      final rows = bad['coaches'] as List;
      final row = rows.firstWhere((r) => (r['honours'] as List).isNotEmpty);
      row['honours'][0]['count'] = count;
      expect(() => CoachHonoursCatalog.fromJson(bad), throwsFormatException);
    }
    final bad = jsonDecode(source) as Map<String, dynamic>;
    bad['schemaVersion'] = 2;
    expect(() => CoachHonoursCatalog.fromJson(bad), throwsFormatException);
  });
  testWidgets(
    'search, filters, no results and detail navigation work offline',
    (t) async {
      await mount(
        t,
        CoachHonoursPage(
          service: CoachHonoursService(bundle: ArchiveBundle(source)),
        ),
      );
      expect(find.text('98 / 98 teknik direktör'), findsOneWidget);
      await t.enterText(find.byType(TextField), 'pep guardiola');
      await t.pumpAndSettle();
      expect(find.text('1 / 98 teknik direktör'), findsOneWidget);
      await t.ensureVisible(find.text('Pep Guardiola'));
      await t.tap(find.text('Pep Guardiola'));
      await t.pumpAndSettle();
      expect(find.text('Başarı defteri'), findsOneWidget);
      await t.pageBack();
      await t.pumpAndSettle();
      await t.ensureVisible(find.byType(TextField));
      await t.enterText(find.byType(TextField), 'zzzz');
      await t.pumpAndSettle();
      expect(find.text('0 / 98 teknik direktör'), findsOneWidget);
      await t.tap(find.byTooltip('Aramayı temizle'));
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Kupa satırı eksik'));
      await t.tap(find.text('Kupa satırı eksik'));
      await t.pumpAndSettle();
      expect(find.text('18 / 98 teknik direktör'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('load error exposes working retry', (t) async {
    await mount(
      t,
      CoachHonoursPage(
        service: CoachHonoursService(
          bundle: ArchiveBundle(source, failures: 1),
        ),
      ),
    );
    expect(find.text('Başarı arşivi yüklenemedi.'), findsOneWidget);
    await t.tap(find.text('Tekrar dene'));
    await t.pumpAndSettle();
    expect(find.text('98 / 98 teknik direktör'), findsOneWidget);
  });
  testWidgets('Hoca 11 links the bundled archive without starting a game', (
    t,
  ) async {
    final fake = FakeModes('coach_xi');
    await mount(
      t,
      ThreeModesPage(
        mode: 'coach_xi',
        service: fake,
        honoursService: CoachHonoursService(bundle: ArchiveBundle(source)),
      ),
    );
    await t.tap(find.byTooltip('Hoca başarı arşivi'));
    await t.pumpAndSettle();
    expect(find.byType(CoachHonoursPage), findsOneWidget);
    expect(find.text('98 / 98 teknik direktör'), findsOneWidget);
    expect(fake.lastMutation, isNull);
  });
  for (final light in [false, true]) {
    testWidgets(
      'archive, trophies and missing coverage render at large text: $light',
      (t) async {
        await mount(
          t,
          CoachHonoursPage(
            service: CoachHonoursService(bundle: ArchiveBundle(source)),
            initialCoachId: 'coach_0',
            initialQuery: 'unrelated',
          ),
          light: light,
          large: light,
        );
        expect(find.text('1 / 98 teknik direktör'), findsOneWidget);
        await capture(t, 'list_$light');
        expect(t.takeException(), isNull);
        await mount(
          t,
          CoachHonoursDetailPage(coach: pep),
          light: light,
          large: light,
        );
        await capture(t, 'detail_$light');
        expect(t.takeException(), isNull);
        await t.drag(find.byType(ListView), const Offset(0, -650));
        await t.pumpAndSettle();
        await capture(t, 'cups_$light');
        expect(t.takeException(), isNull);
        await mount(
          t,
          CoachHonoursDetailPage(coach: missing),
          light: light,
          large: light,
        );
        await capture(t, 'missing_$light');
        expect(t.takeException(), isNull);
      },
    );
  }
}
