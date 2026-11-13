import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/app/app_preferences.dart';
import 'package:shared_xi/config/privacy_config.dart';
import 'package:shared_xi/screens/app_home_page.dart';
import 'package:shared_xi/screens/entry_gate_page.dart';
import 'package:shared_xi/services/auth_service.dart';

class GateUser implements User {
  @override
  String get uid => 'gate-user';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<AppPreferences> mount(WidgetTester t, Widget child) async {
  final prefs = await AppPreferences.load();
  addTearDown(prefs.dispose);
  t.view.physicalSize = const Size(390, 900);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  await t.pumpWidget(
    PreferencesScope(
      preferences: prefs,
      child: MaterialApp(home: Scaffold(body: child)),
    ),
  );
  await t.pumpAndSettle();
  return prefs;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('guest play is one tap and remembers the answer', (t) async {
    var done = 0;
    final prefs = await mount(t, EntryGatePage(onDone: () => done++));
    expect(find.text('Sahada iz bırak.'), findsOneWidget);
    expect(find.text('Misafir olarak oyna'), findsOneWidget);
    await t.tap(find.byKey(const ValueKey('entry-guest')));
    await t.pumpAndSettle();
    expect(done, 1);
    expect(prefs.entryGateComplete, isTrue);
    expect(t.takeException(), isNull);
  });

  testWidgets('Google: cancel stays, failure explains, success finishes', (
    t,
  ) async {
    var done = 0;
    var mode = 'cancel';
    Future<LinkballGoogleSignInResult?> signIn() async {
      if (mode == 'cancel') return null;
      if (mode == 'fail') throw StateError('network');
      return LinkballGoogleSignInResult(
        user: GateUser(),
        switchedToExistingGoogleAccount: true,
      );
    }

    final prefs = await mount(
      t,
      EntryGatePage(onDone: () => done++, signIn: signIn),
    );
    await t.tap(find.byKey(const ValueKey('entry-google')));
    await t.pumpAndSettle();
    expect(done, 0);
    expect(find.text('Google ile devam et'), findsOneWidget);
    mode = 'fail';
    await t.tap(find.byKey(const ValueKey('entry-google')));
    await t.pumpAndSettle();
    expect(
      find.textContaining('Google ile giriş tamamlanamadı'),
      findsOneWidget,
    );
    expect(done, 0);
    mode = 'ok';
    await t.tap(find.byKey(const ValueKey('entry-google')));
    await t.pump();
    expect(
      find.textContaining('misafir olarak oynadıkların ona eklenmedi'),
      findsOneWidget,
    );
    await t.pumpAndSettle();
    expect(done, 1);
    expect(prefs.entryGateComplete, isTrue);
  });

  testWidgets('privacy link shows the policy address', (t) async {
    await mount(t, EntryGatePage(onDone: () {}));
    await t.ensureVisible(find.text('Gizlilik Politikası'));
    await t.tap(find.text('Gizlilik Politikası'));
    await t.pumpAndSettle();
    expect(find.text(PrivacyConfig.privacyPolicyUrl), findsOneWidget);
  });

  testWidgets(
    'home account card: shown without an account, hidden for a week after "Sonra"',
    (t) async {
      final prefs = await mount(t, const AccountLinkCard(linked: false));
      expect(find.text('Profilini koru, hesabını bağla'), findsOneWidget);
      await t.tap(find.text('Sonra'));
      await t.pumpAndSettle();
      expect(find.text('Profilini koru, hesabını bağla'), findsNothing);
      expect(
        prefs.accountCardSnoozedUntil,
        greaterThan(
          DateTime.now().add(const Duration(days: 6)).millisecondsSinceEpoch,
        ),
      );
      await t.pumpWidget(
        PreferencesScope(
          preferences: prefs,
          child: const MaterialApp(
            home: Scaffold(body: AccountLinkCard(linked: true)),
          ),
        ),
      );
      expect(find.text('Profilini koru, hesabını bağla'), findsNothing);
    },
  );
}
