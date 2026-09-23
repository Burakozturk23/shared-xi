import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/app/app_preferences.dart';
import 'package:shared_xi/app/app_feedback.dart';
import 'package:shared_xi/models/achievement_models.dart';
import 'package:shared_xi/models/economy_models.dart';
import 'package:shared_xi/models/mission_models.dart';
import 'package:shared_xi/models/progression_models.dart';
import 'package:shared_xi/models/premium_models.dart';
import 'package:shared_xi/models/premium_billing_models.dart';
import 'package:shared_xi/screens/progression_center_page.dart';
import 'package:shared_xi/screens/achievements_page.dart';
import 'package:shared_xi/screens/privacy_account_page.dart';
import 'package:shared_xi/screens/premium_page.dart';
import 'package:shared_xi/screens/app_settings_page.dart';
import 'package:shared_xi/services/experience/progress_gateway.dart';
import 'package:shared_xi/services/experience/badges_gateway.dart';
import 'package:shared_xi/services/experience/account_gateway.dart';
import 'package:shared_xi/services/experience/pro_gateway.dart';
import 'package:shared_xi/services/account_deletion_service.dart';
import 'package:shared_xi/theme/ortak_saha_theme.dart';

ProgressionProfile progress({bool claimed = false}) =>
    ProgressionProfile.fromMap({
      'lifetimeXp': 740,
      'level': {'level': 4, 'currentXp': 40, 'nextLevelXp': 200},
      'season': {
        'id': 'season',
        'title': 'Yeni Sezon',
        'level': 3,
        'xp': 240,
        'currentXp': 40,
        'nextLevelXp': 100,
        'endsOn': '2026-10-01',
      },
      'dailyReward': {
        'enabled': true,
        'canClaim': !claimed,
        'dateKey': '2026-09-23',
        'currentStreak': 3,
        'bestStreak': 7,
        'nextDayIndex': 4,
        'scheduleCoins': [10, 15, 20, 25, 30, 35, 50],
        'rewardCoins': 75,
        'xpReward': 10,
        'multiplier': 3,
      },
    });
MissionProfile missionFixture({bool claimed = false}) =>
    MissionProfile.fromMap({
      'dateKey': '2026-09-23',
      'dailyClaimLimit': 3,
      'daily': [
        {
          'id': 'play',
          'kind': 'daily',
          'title': 'Sahaya çık',
          'description': 'Bir maç tamamla.',
          'progress': 1,
          'target': 1,
          'claimable': !claimed,
          'claimed': claimed,
          'rewardCoins': 20,
        },
      ],
      'general': [],
    });

class ProgressFake extends ProgressGateway {
  bool fail = false;
  int claims = 0;
  Completer<MissionClaimResult>? pending;
  @override
  bool get connected => true;
  @override
  Future<ProgressionProfile> progression() async {
    if (fail) throw StateError('secret');
    return progress();
  }

  @override
  Future<MissionProfile> missions() async => missionFixture();
  @override
  Future<MissionClaimResult> claimMission(String id) async {
    claims++;
    return pending!.future;
  }
}

class BadgeFake extends BadgesGateway {
  int claims = 0;
  @override
  bool get connected => true;
  @override
  Future<BadgeSnapshot> load() async => BadgeSnapshot(
    {
      'first_whistle': const AchievementProgress(
        id: 'first_whistle',
        value: 1,
        rawValue: 1,
        target: 1,
        unlocked: true,
      ),
    },
    {},
    {'first_whistle': 25},
  );
  @override
  Future<EconomyClaimResult> claim(String id) async {
    claims++;
    return const EconomyClaimResult(
      granted: true,
      alreadyClaimed: false,
      amount: 25,
      coins: 125,
    );
  }
}

class TestUser implements User {
  @override
  String get uid => 'test-user';
  @override
  String get displayName => 'Saha Kaptanı';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class AccountFake extends AccountGateway {
  int deletions = 0;
  Completer<AccountDeletionResult>? pending;
  @override
  User get user => TestUser();
  @override
  bool get connected => true;
  @override
  Future<AccountDeletionResult> delete() async {
    deletions++;
    return pending!.future;
  }
}

const monthly = PremiumBillingProduct(
  plan: PremiumPlan.monthly,
  productId: 'linkball_pro_monthly',
  title: 'Monthly',
  description: 'Aylık Pro üyeliği',
  price: '₺49,99',
  currencyCode: 'TRY',
  rawPrice: 49.99,
);
const yearly = PremiumBillingProduct(
  plan: PremiumPlan.yearly,
  productId: 'linkball_pro_yearly',
  title: 'Yearly',
  description: 'Yıllık Pro üyeliği',
  price: '₺499,99',
  currencyCode: 'TRY',
  rawPrice: 499.99,
);

class ProFake extends ProGateway {
  bool failStatus = false;
  int buys = 0;
  final updates = StreamController<List<PurchaseDetails>>.broadcast();
  @override
  bool get connected => true;
  @override
  void record(String event, {String productId = '', bool restored = false}) {}
  @override
  Future<PremiumEntitlement> status() async {
    if (failStatus) throw StateError('private');
    return const PremiumEntitlement.inactive();
  }

  @override
  Future<PremiumBillingCatalog> catalog() async => const PremiumBillingCatalog(
    storeAvailable: true,
    products: [monthly, yearly],
    missingProductIds: {},
  );
  @override
  Stream<List<PurchaseDetails>> get purchases => updates.stream;
  @override
  Future<bool> buy(PremiumPlan plan) async {
    buys++;
    return true;
  }
}

Future<GlobalKey> open(
  WidgetTester t,
  Widget page, {
  AppPreferences? prefs,
  bool dark = true,
  bool large = false,
}) async {
  prefs ??= await AppPreferences.load();
  t.view.physicalSize = Size(large ? 320 : 390, 844);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.resetPhysicalSize);
  addTearDown(t.view.resetDevicePixelRatio);
  final key = GlobalKey();
  await t.pumpWidget(
    PreferencesScope(
      preferences: prefs,
      child: MaterialApp(
        theme: dark ? OrtakSahaTheme.dark : OrtakSahaTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(large ? 1.8 : 1)),
          child: child!,
        ),
        home: RepaintBoundary(key: key, child: page),
      ),
    ),
  );
  await t.pumpAndSettle();
  return key;
}

Future<void> reveal(WidgetTester t, Finder f) async {
  await t.scrollUntilVisible(
    f,
    250,
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
    final f = File('.dart_tool/experience_qa/$name.png');
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AppFeedback.preferences = null;
  });
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
    'preferences persist and feedback respects independent switches',
    () async {
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
      final p = await AppPreferences.load();
      AppFeedback.preferences = p;
      await p.setLanguage('en');
      await p.setSound(false);
      await p.setHaptics(false);
      await AppFeedback.answer(correct: true);
      expect(calls, isEmpty);
      await p.setHaptics(true);
      await AppFeedback.answer(correct: false);
      expect(calls.map((e) => e.method), ['HapticFeedback.vibrate']);
      calls.clear();
      await p.setHaptics(false);
      await p.setSound(true);
      await AppFeedback.answer(correct: true);
      expect(calls.map((e) => e.method), ['SystemSound.play']);
      final reloaded = await AppPreferences.load();
      expect(reloaded.languageCode, 'en');
      expect(reloaded.haptics, isFalse);
      expect(reloaded.sound, isTrue);
    },
  );
  testWidgets('language selection changes actual settings copy', (t) async {
    final p = await AppPreferences.load();
    await open(t, const AppSettingsPage(), prefs: p);
    await reveal(t, find.text('Menü dili'));
    await t.tap(find.text('Menü dili'));
    await t.pumpAndSettle();
    await t.tap(find.text('English'));
    await t.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(p.languageCode, 'en');
    expect(find.text('Menu language'), findsOneWidget);
  });
  testWidgets('mission claim locks duplicate taps and uses server result', (
    t,
  ) async {
    final g = ProgressFake()..pending = Completer<MissionClaimResult>();
    await open(t, ProgressionCenterPage(gateway: g));
    await reveal(t, find.text('Ödülü al'));
    await t.tap(find.text('Ödülü al'));
    await t.pump();
    expect(
      t
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Ödülü al'))
          .onPressed,
      isNull,
    );
    expect(g.claims, 1);
    g.pending!.complete(
      MissionClaimResult(
        granted: true,
        alreadyClaimed: false,
        amount: 20,
        walletCoins: 120,
        missionId: 'play',
        periodKey: '2026-09-23',
        profile: missionFixture(claimed: true),
      ),
    );
    await t.pumpAndSettle();
    expect(find.text('Ödül alındı'), findsOneWidget);
    expect(find.text('+20 Link Coin'), findsWidgets);
  });
  testWidgets('refresh failure keeps progress with a retry notice', (t) async {
    final g = ProgressFake();
    await open(t, ProgressionCenterPage(gateway: g));
    g.fail = true;
    await t.tap(find.byTooltip('Yenile'));
    await t.pumpAndSettle();
    expect(find.text('Yenilenemedi'), findsOneWidget);
    expect(find.text('Seviye 4'), findsOneWidget);
    expect(find.textContaining('secret'), findsNothing);
  });
  testWidgets(
    'badge claim disappears from claimable filter after acknowledgement',
    (t) async {
      final g = BadgeFake();
      await open(t, AchievementsPage(gateway: g));
      await reveal(t, find.text('Ödülü hazır'));
      await t.tap(find.text('Ödülü hazır'));
      await t.pumpAndSettle();
      await reveal(t, find.text('Ödülü al'));
      await t.tap(find.text('Ödülü al'));
      await t.pumpAndSettle();
      expect(g.claims, 1);
      expect(find.text('Ödülü al'), findsNothing);
      expect(find.text('Bu filtrede rozet yok'), findsOneWidget);
    },
  );
  testWidgets(
    'delete needs phrase and locks navigation while request is pending',
    (t) async {
      final g = AccountFake()..pending = Completer<AccountDeletionResult>();
      await open(t, PrivacyAccountPage(gateway: g));
      await reveal(t, find.text('Hesabımı ve verilerimi sil'));
      await t.tap(find.text('Hesabımı ve verilerimi sil'));
      await t.pumpAndSettle();
      await reveal(t, find.text('Kalıcı olarak sil'));
      expect(
        t
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Kalıcı olarak sil'),
            )
            .onPressed,
        isNull,
      );
      expect(g.deletions, 0);
      await t.enterText(find.byType(TextField), 'SİL');
      t.testTextInput.hide();
      await t.pumpAndSettle();
      await reveal(t, find.text('Kalıcı olarak sil'));
      await t.tap(find.text('Kalıcı olarak sil'));
      await t.pump();
      expect(g.deletions, 1);
      expect(t.widget<PopScope>(find.byType(PopScope).last).canPop, isFalse);
      g.pending!.completeError(StateError('secret-path'));
      await t.pumpAndSettle();
      expect(find.textContaining('secret-path'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('Pro cannot buy while entitlement lookup failed', (t) async {
    final g = ProFake()..failStatus = true;
    addTearDown(g.updates.close);
    await open(t, PremiumPage(gateway: g));
    await reveal(t, find.text('Üyelik bilgisi alınamadı'));
    expect(find.text('Google Play ile devam et'), findsNothing);
    expect(g.buys, 0);
    expect(t.takeException(), isNull);
  });
  testWidgets(
    'pending Pro purchase locks both plans and cancellation unlocks',
    (t) async {
      final g = ProFake();
      addTearDown(g.updates.close);
      await open(t, PremiumPage(gateway: g));
      await reveal(t, find.byKey(const ValueKey(PremiumPlan.monthly)));
      await t.tap(
        find.descendant(
          of: find.byKey(const ValueKey(PremiumPlan.monthly)),
          matching: find.byType(FilledButton),
        ),
      );
      await t.pumpAndSettle();
      expect(g.buys, 1);
      expect(find.text('Google Play ile devam et'), findsNothing);
      g.updates.add([
        PurchaseDetails(
          productID: 'linkball_pro_monthly',
          verificationData: PurchaseVerificationData(
            localVerificationData: '',
            serverVerificationData: '',
            source: 'google_play',
          ),
          transactionDate: null,
          status: PurchaseStatus.canceled,
        ),
      ]);
      await t.pumpAndSettle();
      await reveal(t, find.byKey(const ValueKey(PremiumPlan.monthly)));
      expect(
        t
            .widget<FilledButton>(
              find
                  .widgetWithText(FilledButton, 'Google Play ile devam et')
                  .first,
            )
            .onPressed,
        isNotNull,
      );
      expect(t.takeException(), isNull);
    },
  );
  for (final dark in [true, false]) {
    for (final large in [false, true]) {
      testWidgets('experience layouts dark=$dark large=$large', (t) async {
        final pro = ProFake();
        addTearDown(pro.updates.close);
        for (final (name, page) in <(String, Widget)>[
          ('progress', ProgressionCenterPage(gateway: ProgressFake())),
          ('badges', AchievementsPage(gateway: BadgeFake())),
          ('privacy', PrivacyAccountPage(gateway: AccountFake())),
          ('pro', PremiumPage(gateway: pro)),
          ('settings', const AppSettingsPage()),
        ]) {
          final key = await open(t, page, dark: dark, large: large);
          expect(t.takeException(), isNull, reason: '$name initial');
          await capture(
            t,
            key,
            '$name-${dark ? 'dark' : 'light'}-${large ? 'large' : 'normal'}',
          );
          for (var i = 0; i < 4; i++) {
            await t.drag(find.byType(ListView).first, const Offset(0, -650));
            await t.pumpAndSettle();
            expect(t.takeException(), isNull, reason: '$name scroll $i');
          }
          if (name == 'pro')
            await capture(
              t,
              key,
              'pro-plans-${dark ? 'dark' : 'light'}-${large ? 'large' : 'normal'}',
            );
        }
      });
    }
  }
}
