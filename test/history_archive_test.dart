import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/models/history_record.dart';
import 'package:shared_xi/screens/history_archive_page.dart';
import 'package:shared_xi/services/history/history_repository.dart';

HistoryRecord match(String name, {int id = 1}) => HistoryRecord({'id': id, 'home': name, 'away': 'Germany', 'date': '2020-01-01', 'competition': 'Friendly', 'home_score': 1, 'away_score': 0, 'score_basis': 'including_extra_time'});
class FakeHistory implements HistoryRepository {
  List<HistoryRecord> rows = [match('England')];
  bool fail = false;
  final List<int> offsets = [];
  final Map<String, Completer<List<HistoryRecord>>> pending = {};
  @override
  Future<List<HistoryRecord>> browse({required bool squads, required HistoryScope scope, String query = '', int offset = 0}) async {
    offsets.add(offset);
    if (fail) throw StateError('unavailable');
    if (pending.containsKey(query)) return pending[query]!.future;
    return offset > 0 ? [] : rows;
  }
  @override
  Future<HistoryDetail> detail(String id, {required bool squads}) async => HistoryDetail(record: match('England'), goals: [HistoryRecord({'scorer': 'Player', 'team': 'England', 'minute': null})]);
  @override
  Future<List<HistoryRecord>> selections() async => [HistoryRecord({'id': 1, 'title': 'Catalog only', 'date': '1971-01-01', 'match_id': null})];
}

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await tester.runAsync(() async {
    final image = await (key.currentContext!.findRenderObject() as RenderRepaintBoundary).toImage(pixelRatio: 1);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.dart_tool/history_qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    for (final (name,path) in [('Satoshi','assets/fonts/Satoshi-Variable.ttf'),('Inter','assets/fonts/Inter-Body-Variable.ttf'),('MaterialIcons','fonts/MaterialIcons-Regular.otf')]) {
      await (FontLoader(name)..addFont(rootBundle.load(path))).load();
    }
  });
  test('queries bind hostile and wildcard input and keep scope restrictions', () {
    final query = historyBrowseQuery(squads: false, scope: HistoryScope.championsLeague, query: "x%' OR 1=1 --", offset: 40);
    expect(query.sql, contains("m.competition='uefa.champions'"));
    expect(query.sql, isNot(contains('OR 1=1')));
    expect(query.arguments.first, contains(r'\%'));
    expect(query.arguments.last, 40);
    final squads = historyBrowseQuery(squads: true, scope: HistoryScope.international);
    expect(squads.sql, contains("t.kind='international'"));
  });
  for (final brightness in Brightness.values) {
    testWidgets('archive fits narrow ${brightness.name} screen with large text', (tester) async {
      tester.view.physicalSize = const Size(320, 780); tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize); addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(MaterialApp(theme: brightness == Brightness.light ? OrtakSahaTheme.light : OrtakSahaTheme.dark, builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.8)), child: RepaintBoundary(key: key, child: child!)), home: HistoryArchivePage(repository: FakeHistory())));
      await tester.pumpAndSettle();
      expect(find.text('England • Germany'), findsOneWidget);
      await capture(tester, key, 'archive-${brightness.name}');
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Sezon kadroları')); await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('search ignores stale responses', (tester) async {
    final repo = FakeHistory(); repo.pending['old'] = Completer(); repo.pending['new'] = Completer();
    await tester.pumpWidget(MaterialApp(home: HistoryArchivePage(repository: repo))); await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'old'); await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField), 'new'); await tester.pump(const Duration(milliseconds: 350));
    repo.pending['new']!.complete([match('Newest')]); await tester.pumpAndSettle();
    repo.pending['old']!.complete([match('Stale')]); await tester.pumpAndSettle();
    expect(find.text('Newest • Germany'), findsOneWidget); expect(find.text('Stale • Germany'), findsNothing);
  });
  testWidgets('failed load can retry and empty results are explicit', (tester) async {
    final repo = FakeHistory()..fail = true;
    await tester.pumpWidget(MaterialApp(home: HistoryArchivePage(repository: repo))); await tester.pumpAndSettle();
    expect(find.text('Yeniden dene'), findsOneWidget);
    repo.fail = false; repo.rows = [];
    await tester.tap(find.text('Yeniden dene')); await tester.pumpAndSettle();
    expect(find.text('Bu aramada kayıt bulunamadı.'), findsOneWidget);
  });
  testWidgets('pagination continues with the actual offset', (tester) async {
    final repo = FakeHistory()..rows = List.generate(40, (i) => match('Team $i', id: i));
    await tester.pumpWidget(MaterialApp(home: HistoryArchivePage(repository: repo))); await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Daha fazla göster'), 600, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.text('Daha fazla göster')); await tester.pumpAndSettle();
    expect(repo.offsets, [0, 40]);
  });
  testWidgets('detail does not present partial goals as complete or invent minute', (tester) async {
    await tester.pumpWidget(MaterialApp(home: HistoryDetailPage(id: '1', squads: false, repository: FakeHistory()))); await tester.pumpAndSettle();
    expect(find.textContaining('Gol listesi eksik'), findsOneWidget);
    expect(find.textContaining('Dakika bilinmiyor'), findsOneWidget);
  });
  testWidgets('catalog-only selection stays disabled', (tester) async {
    await tester.pumpWidget(MaterialApp(home: HistorySelectionPage(repository: FakeHistory()))); await tester.pumpAndSettle();
    expect(tester.widget<ListTile>(find.byType(ListTile)).onTap, isNull);
    expect(find.textContaining('Yalnızca katalog kaydı'), findsOneWidget);
  });
}
