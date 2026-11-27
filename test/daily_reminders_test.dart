import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/app/app_preferences.dart';
import 'package:shared_xi/controllers/home_resources_controller.dart';
import 'package:shared_xi/models/daily_streak.dart';
import 'package:shared_xi/screens/app_home_page.dart';
import 'package:shared_xi/screens/app_settings_page.dart';
import 'package:shared_xi/services/daily_reminders.dart';
import 'package:shared_xi/theme/app_theme.dart';

import 'support/qa_capture.dart';

class FakeScheduler implements ReminderScheduler {
  bool grant = true;
  int asks = 0;
  final calls = <List<PlannedReminder>>[];
  @override
  Future<bool> requestPermission() async {
    asks++;
    return grant;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async =>
      calls.add(reminders);
}

/// Wednesday 28 Oct 2026, 12:00 Türkiye.
final wednesdayNoon = DateTime.utc(2026, 10, 28, 9);
DateTime tr(DateTime utc) => utc.add(const Duration(hours: 3));

void main() {
  setUpAll(loadQaFonts);
  group('plan', () {
    test('one reminder a day: 20:00, Sunday 19:00 Passa, Monday 10:00', () {
      final plan = planDailyReminders(
        now: wednesdayNoon,
        streak: const DailyStreak(streak: 5),
      );
      expect(plan.map((r) => (tr(r.at).weekday, tr(r.at).hour)), [
        (DateTime.wednesday, 20),
        (DateTime.thursday, 20),
        (DateTime.friday, 20),
        (DateTime.saturday, 20),
        (DateTime.sunday, 19),
        (DateTime.monday, 10),
        (DateTime.tuesday, 20),
      ]);
      expect(plan.first.title, 'Serin bugün bitiyor');
      expect(plan.first.body, contains('5 günlük serini'));
      expect(plan[1].title, 'Serini sürdür');
      expect(plan[4].title, 'Haftalık Passa bugün bitiyor');
      expect(plan[5].title, 'Haftalık Passa başladı');
      expect(plan.map((r) => r.id).toSet(), hasLength(7));
      for (final r in plan) {
        expect(tr(r.at).hour, inInclusiveRange(9, 21), reason: 'quiet hours');
      }
    });

    test('a completed day or a passed hour drops today', () {
      final played = planDailyReminders(
        now: wednesdayNoon,
        streak: const DailyStreak(streak: 5, playedToday: true),
      );
      expect(tr(played.first.at).weekday, DateTime.thursday);
      final late = planDailyReminders(now: DateTime.utc(2026, 10, 28, 18));
      expect(tr(late.first.at).weekday, DateTime.thursday);
      expect(late.first.title, 'Günün oyunları hazır');
      // The Passa reminders do not depend on the daily games.
      final sunday = planDailyReminders(
        now: DateTime.utc(2026, 11, 1, 6),
        streak: const DailyStreak(streak: 2, playedToday: true),
      );
      expect(sunday.first.title, 'Haftalık Passa bugün bitiyor');
    });
  });

  group('sync', () {
    late FakeScheduler fake;
    late AppPreferences prefs;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await AppPreferences.load();
      fake = FakeScheduler();
      DailyReminders.scheduler = fake;
      DailyReminders.clock = () => wednesdayNoon;
      DailyReminders.reset();
    });

    test('off by default; replans only when the plan changes', () async {
      await DailyReminders.sync(prefs);
      expect(fake.calls.single, isEmpty);
      expect(await DailyReminders.enable(prefs), isTrue);
      expect(prefs.notification('daily'), isTrue);
      expect(fake.calls.last, hasLength(7));
      await DailyReminders.sync(prefs);
      expect(fake.calls, hasLength(2));
      await DailyReminders.sync(
        prefs,
        streak: const DailyStreak(streak: 3, playedToday: true),
      );
      expect(fake.calls.last, hasLength(6));
      await DailyReminders.disable(prefs);
      expect(fake.calls.last, isEmpty);
    });

    test('a denied permission leaves reminders off', () async {
      fake.grant = false;
      expect(await DailyReminders.enable(prefs), isFalse);
      expect(prefs.notification('daily'), isFalse);
      expect(fake.calls.last, isEmpty);
    });

    testWidgets('settings switch asks for permission', (t) async {
      await t.pumpWidget(
        PreferencesScope(
          preferences: prefs,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: const NotificationPreferencesPage(),
          ),
        ),
      );
      await t.tap(find.text('Günlük oyun hatırlatıcısı'));
      await t.pumpAndSettle();
      expect(fake.asks, 1);
      expect(prefs.notification('daily'), isTrue);
      await t.tap(find.text('Günlük oyun hatırlatıcısı'));
      await t.pumpAndSettle();
      expect(prefs.notification('daily'), isFalse);
    });

    testWidgets('home offers reminders once, after the first daily game', (
      t,
    ) async {
      var streak = const DailyStreak(streak: 0);
      final c = HomeResourcesController(
        prepare: () async {},
        accounts: () => const Stream.empty(),
        currentAccount: () => (uid: 'test', linked: true),
        readEnergy: () async => {},
        watchWallet: () => const Stream.empty(),
        readStreak: () async => streak,
      )..account = (uid: 'test', linked: true);
      addTearDown(c.dispose);
      t.view.physicalSize = const Size(390, 900);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        PreferencesScope(
          preferences: prefs,
          child: MaterialApp(
            theme: AppTheme.darkTheme,
            home: Scaffold(
              body: AppHomePage(resources: c, loadResources: false),
            ),
          ),
        ),
      );
      await t.runAsync(c.refreshStreak);
      await t.pumpAndSettle();
      expect(find.text('Serini hatırlatalım mı?'), findsNothing);

      streak = const DailyStreak(streak: 1, playedToday: true);
      await t.runAsync(c.refreshStreak);
      await t.pumpAndSettle();
      expect(find.text('Serini hatırlatalım mı?'), findsOneWidget);
      await t.tap(find.text('Hatırlat'));
      // The offer was started from a real-async refresh; let it finish.
      await t.runAsync(() => Future<void>.delayed(Duration.zero));
      await t.pumpAndSettle();
      expect(fake.asks, 1);
      expect(prefs.notification('daily'), isTrue);
      expect(prefs.reminderOffered, isTrue);

      streak = const DailyStreak(streak: 2, playedToday: true);
      await t.runAsync(c.refreshStreak);
      await t.pumpAndSettle();
      expect(find.text('Serini hatırlatalım mı?'), findsNothing);
      await t.pumpWidget(const SizedBox.shrink());
    });
  });
}
