import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/app/app_feedback.dart';
import 'package:shared_xi/app/app_preferences.dart';
import 'package:shared_xi/screens/app_settings_page.dart';
import 'package:shared_xi/screens/sign_in_page.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';

Future<GlobalKey> open(
  WidgetTester t,
  AppPreferences prefs,
  Widget page, {
  bool large = false,
  bool landscape = false,
}) async {
  t.view.physicalSize = landscape
      ? const Size(640, 320)
      : Size(large ? 320 : 390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final key = GlobalKey();
  await t.pumpWidget(
    PreferencesScope(
      preferences: prefs,
      child: ListenableBuilder(
        listenable: prefs,
        builder: (context, _) => RepaintBoundary(
          key: key,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: OrtakSahaTheme.light,
            darkTheme: OrtakSahaTheme.dark,
            themeMode: prefs.themeMode,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(large ? 1.8 : 1)),
              child: child!,
            ),
            home: page,
          ),
        ),
      ),
    ),
  );
  await t.pumpAndSettle();
  return key;
}

Future<void> reveal(WidgetTester t, Finder target) async {
  await t.scrollUntilVisible(
    target,
    180,
    scrollable: find
        .byWidgetPredicate(
          (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
        )
        .first,
    maxScrolls: 50,
  );
  await t.pumpAndSettle();
}

Future<void> capture(WidgetTester t, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('UPDATE_FIVE_SCREENSHOTS')) return;
  await t.runAsync(() async {
    final image =
        await (key.currentContext!.findRenderObject() as RenderRepaintBoundary)
            .toImage(pixelRatio: 1.5);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('.dart_tool/settings_qa/$name.png');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppFeedback.preferences = null;
  });
  tearDown(() => AppFeedback.preferences = null);
  setUpAll(() async {
    for (final (family, path) in [
      ('Satoshi', 'assets/fonts/Satoshi-Variable.ttf'),
      ('Inter', 'assets/fonts/Inter-Body-Variable.ttf'),
      ('MaterialIcons', 'fonts/MaterialIcons-Regular.otf'),
    ]) {
      await (FontLoader(family)..addFont(rootBundle.load(path))).load();
    }
  });

  test(
    'strength persists, handles old values and respects global mute',
    () async {
      SharedPreferences.setMockInitialValues({
        'linkball.haptic_strength': 'unknown',
      });
      final prefs = await AppPreferences.load();
      expect(prefs.hapticStrength, HapticStrength.standard);
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            calls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      AppFeedback.preferences = prefs;
      for (final pair in [
        (HapticStrength.gentle, 'HapticFeedbackType.selectionClick'),
        (HapticStrength.standard, 'HapticFeedbackType.lightImpact'),
        (HapticStrength.strong, 'HapticFeedbackType.heavyImpact'),
      ]) {
        await prefs.setHapticStrength(pair.$1);
        calls.clear();
        await AppFeedback.previewHaptics(prefs);
        expect(calls.single.method, 'HapticFeedback.vibrate');
        expect(calls.single.arguments, pair.$2);
        expect((await AppPreferences.load()).hapticStrength, pair.$1);
      }
      await prefs.setHaptics(false);
      calls.clear();
      await AppFeedback.previewHaptics(prefs);
      await AppFeedback.selection();
      expect(calls, isEmpty);
      await AppFeedback.previewSound(prefs);
      expect(calls.single.method, 'SystemSound.play');
      await prefs.setSound(false);
      calls.clear();
      await AppFeedback.previewSound(prefs);
      await AppFeedback.answer(correct: true);
      expect(calls, isEmpty);
    },
  );

  testWidgets(
    'separate previews and switches persist without changing each other',
    (t) async {
      final prefs = await AppPreferences.load();
      await open(t, prefs, const AppSettingsPage());
      final calls = <MethodCall>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'SystemSound.play' ||
                call.method == 'HapticFeedback.vibrate')
              calls.add(call);
            return null;
          });
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      final sound = find.byKey(const ValueKey('preview-sound'));
      await reveal(t, sound);
      await t.tap(sound);
      await t.pumpAndSettle();
      expect(calls.map((c) => c.method), ['SystemSound.play']);
      final soundSwitch = find.byType(Switch).first;
      await reveal(t, soundSwitch);
      await t.tap(soundSwitch);
      await t.pumpAndSettle();
      expect(prefs.sound, isFalse);
      expect(prefs.haptics, isTrue);
      expect(t.widget<OutlinedButton>(sound).onPressed, isNull);
      calls.clear();
      final haptics = find.byKey(const ValueKey('preview-haptics'));
      await reveal(t, haptics);
      await t.tap(haptics);
      await t.pumpAndSettle();
      expect(calls.map((c) => c.method), ['HapticFeedback.vibrate']);
      await reveal(t, find.text('Titreşim gücü'));
      await t.tap(find.text('Titreşim gücü'));
      await t.pumpAndSettle();
      await t.tap(find.text('Güçlü'));
      await t.pumpAndSettle();
      expect(prefs.hapticStrength, HapticStrength.strong);
      final saved = await AppPreferences.load();
      expect(saved.hapticStrength, HapticStrength.strong);
      expect(saved.sound, isFalse);
      expect(saved.haptics, isTrue);
      // Music has its own switch and volume; effects volume is disabled while effects are off.
      final music = find.byKey(const ValueKey('music-switch'));
      await reveal(t, music);
      expect(
        t
            .widget<Slider>(
              find.descendant(
                of: find.byKey(const ValueKey('sfx-volume')),
                matching: find.byType(Slider),
              ),
            )
            .onChanged,
        isNull,
      );
      await t.tap(music);
      await t.pumpAndSettle();
      expect(prefs.music, isFalse);
      expect((await AppPreferences.load()).music, isFalse);
      expect(
        t
            .widget<Slider>(
              find.descendant(
                of: find.byKey(const ValueKey('music-volume')),
                matching: find.byType(Slider),
              ),
            )
            .onChanged,
        isNull,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'language changes account copy; canceled selections preserve preferences',
    (t) async {
      final prefs = await AppPreferences.load();
      await open(t, prefs, const AppSettingsPage());
      await reveal(t, find.text('Tema'));
      await t.tap(find.text('Tema'));
      await t.pumpAndSettle();
      await t.binding.handlePopRoute();
      await t.pumpAndSettle();
      expect(prefs.themeMode, ThemeMode.system);
      await t.tap(find.text('Menü dili'));
      await t.pumpAndSettle();
      await t.tap(find.text('English'));
      await t.pumpAndSettle();
      expect(find.text('Settings'), findsOneWidget);
      expect((await AppPreferences.load()).languageCode, 'en');
      await open(t, prefs, const LinkballSignInPage(allowSkip: false));
      expect(find.text('Linkball account'), findsOneWidget);
      await reveal(t, find.text('Continue with Google'));
      expect(find.text('Skip for now'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );

  for (final dark in [true, false]) {
    for (final large in [false, true]) {
      testWidgets('settings and account readable dark=$dark large=$large', (
        t,
      ) async {
        final prefs = await AppPreferences.load();
        await prefs.setTheme(dark ? ThemeMode.dark : ThemeMode.light);
        final suffix =
            '${dark ? 'dark' : 'light'}-${large ? 'large' : 'normal'}';
        var key = await open(t, prefs, const AppSettingsPage(), large: large);
        expect(t.takeException(), isNull);
        await capture(t, key, 'general-$suffix');
        await reveal(t, find.text('Menü dili'));
        await t.tap(find.text('Menü dili'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await capture(t, key, 'language-$suffix');
        await t.binding.handlePopRoute();
        await t.pumpAndSettle();
        await reveal(t, find.byKey(const ValueKey('preview-haptics')));
        expect(t.takeException(), isNull);
        await capture(t, key, 'feedback-$suffix');
        await reveal(t, find.text('Oyunları tanı'));
        expect(t.takeException(), isNull);
        key = await open(
          t,
          prefs,
          const LinkballSignInPage(allowSkip: false),
          large: large,
        );
        expect(t.takeException(), isNull);
        await capture(t, key, 'account-$suffix');
        await reveal(t, find.text('Google ile devam et'));
        expect(t.takeException(), isNull);
        await capture(t, key, 'account-action-$suffix');
      });
    }
  }

  testWidgets('language sheet remains scrollable on a short landscape screen', (
    t,
  ) async {
    final prefs = await AppPreferences.load();
    await open(t, prefs, const AppSettingsPage(), landscape: true, large: true);
    await reveal(t, find.text('Menü dili'));
    await t.tap(find.text('Menü dili'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('English'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await t.tap(find.text('English'));
    await t.pumpAndSettle();
    expect(prefs.languageCode, 'en');
    expect(t.takeException(), isNull);
  });
}
