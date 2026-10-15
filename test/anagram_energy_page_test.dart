import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/controllers/anagram_controller.dart';
import 'package:shared_xi/screens/anagram_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';
import 'anagram_energy_test.dart' show FakeAdmission;
import 'anagram_test.dart' show MemoryAnagramStore, testAnagramCatalog;

void main() {
  testWidgets('expired paid series hides play and requires an explicit new series', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final energy = FakeAdmission();
    final game = AnagramController(catalog: testAnagramCatalog(),
      store: MemoryAnagramStore(), random: Random(7), energyAccess: energy);
    addTearDown(game.dispose);
    await tester.pumpWidget(MaterialApp(theme: OrtakSahaTheme.dark,
      builder: (context, child) => MediaQuery(data: MediaQuery.of(context).copyWith(
        textScaler: TextScaler.linear(1.8)), child: child!),
      home: AnagramPage(controller: game)));
    await tester.pumpAndSettle();
    expect(energy.charges, 1);
    expect(find.text('8 soruluk seri açıldı · Bu seride ek enerji harcanmaz.'), findsOneWidget);
    energy.time += 86400001;
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('anagram-answer')), findsNothing);
    expect(find.text('Devam edilebilir oturum yok.'), findsOneWidget);
    await tester.tap(find.text('Tekrar dene')); await tester.pumpAndSettle();
    expect(energy.charges, 1);
    await tester.ensureVisible(find.text('Yeni 8 futbolcuyla başla'));
    await tester.tap(find.text('Yeni 8 futbolcuyla başla')); await tester.pumpAndSettle();
    await tester.tap(find.text('Vazgeç')); await tester.pumpAndSettle();
    expect(energy.charges, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
