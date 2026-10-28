import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_xi/screens/online_hub_page.dart';
import 'package:shared_xi/screens/sign_in_page.dart';
import 'package:shared_xi/theme/app_theme.dart';

import 'support/qa_capture.dart';

final _boundary = GlobalKey();

Future<void> _open(WidgetTester t, Widget page, {bool light = false}) async {
  t.view.physicalSize = const Size(390, 1400);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    MaterialApp(
      theme: light ? AppTheme.lightTheme : AppTheme.darkTheme,
      home: RepaintBoundary(
        key: _boundary,
        child: Scaffold(body: page),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  setUpAll(loadQaFonts);
  for (final light in [false, true]) {
    testWidgets('guest online hub explains the account gate and offers '
        'sign-in plus an offline path light=$light', (t) async {
      await _open(
        t,
        const OnlineHubPage(persistentAccount: false),
        light: light,
      );
      expect(find.text('Online için kalıcı hesap gerekli'), findsOneWidget);
      await captureQa(t, _boundary, 'online-guest-${light ? 'light' : 'dark'}');
      await t.scrollUntilVisible(find.text('Şimdilik botla oyna'), 200);
      expect(find.text('Şimdilik botla oyna'), findsOneWidget);
      await t.scrollUntilVisible(find.text('Google ile Giriş Yap'), -200);
      expect(
        find.text('Online oyunlar için Google hesabını bağla.'),
        findsNothing,
      );
      // The play actions stay visible; they route through the account gate.
      expect(find.text('Hemen Eşleş'), findsOneWidget);
      await t.tap(find.text('Google ile Giriş Yap'));
      await t.pumpAndSettle();
      final signIn = t.widget<LinkballSignInPage>(
        find.byType(LinkballSignInPage),
      );
      expect(signIn.allowSkip, isFalse);
      expect(t.takeException(), isNull);
    });
  }

  testWidgets('linked online hub hides the guest gate', (t) async {
    await _open(
      t,
      OnlineHubPage(
        persistentAccount: true,
        invites: Stream.value(const []),
        me: Stream.value(null),
        friends: Stream.value(const []),
        incoming: Stream.value(const []),
      ),
    );
    expect(find.text('Online için kalıcı hesap gerekli'), findsNothing);
    expect(find.text('Google ile Giriş Yap'), findsNothing);
    expect(find.text('Şimdilik botla oyna'), findsNothing);
    expect(find.text('Hemen Eşleş'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
}
