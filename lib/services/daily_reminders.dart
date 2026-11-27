import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import '../app/app_preferences.dart';
import '../models/daily_streak.dart';

/// One planned local notification. [at] is UTC.
@immutable
class PlannedReminder {
  const PlannedReminder({
    required this.id,
    required this.at,
    required this.title,
    required this.body,
  });
  final int id;
  final DateTime at;
  final String title, body;

  @override
  bool operator ==(Object other) =>
      other is PlannedReminder &&
      other.id == id &&
      other.at == at &&
      other.title == title &&
      other.body == body;
  @override
  int get hashCode => Object.hash(id, at, title, body);
}

/// Türkiye has no DST: the daily reset and every reminder use UTC+3.
const _istanbul = Duration(hours: 3);

/// Opt-in plan for the next [days] Türkiye days, at most one per day and
/// never in the 22:00–09:00 quiet hours:
/// Monday 10:00 the weekly Passa opens, Sunday 19:00 it closes, other days
/// 20:00 the daily games. Today's 20:00 reminder is dropped once a daily
/// game has been completed.
List<PlannedReminder> planDailyReminders({
  required DateTime now,
  DailyStreak? streak,
  int days = 7,
}) {
  final local = now.toUtc().add(_istanbul);
  final today = DateTime.utc(local.year, local.month, local.day);
  final alive = streak?.streak ?? 0;
  final out = <PlannedReminder>[];
  for (var i = 0; i < days; i++) {
    final day = today.add(Duration(days: i));
    final (hour, title, body) = switch (day.weekday) {
      DateTime.monday => (
        10,
        'Haftalık Passa başladı',
        '240 saniye, 29 harf. Bu haftanın tek resmî hakkı seni bekliyor.',
      ),
      DateTime.sunday => (
        19,
        'Haftalık Passa bugün bitiyor',
        'Bu haftanın Passa’sı gece yarısı kapanıyor.',
      ),
      _ when i == 0 && streak?.playedToday == true => (0, '', ''),
      _ when i == 0 && alive > 0 => (
        20,
        'Serin bugün bitiyor',
        '$alive günlük serini korumak için bir günlük oyun bitirmen yeter.',
      ),
      _ when alive > 0 => (
        20,
        'Serini sürdür',
        'Günlük oyunlardan birini bitir, serin devam etsin.',
      ),
      _ => (
        20,
        'Günün oyunları hazır',
        'Altı günlük oyundan birini bitir, serini başlat.',
      ),
    };
    if (hour == 0) continue;
    assert(hour >= 9 && hour < 22, 'quiet hours');
    final at = day.add(Duration(hours: hour)).subtract(_istanbul);
    if (!at.isAfter(now.toUtc())) continue;
    out.add(PlannedReminder(id: 7100 + i, at: at, title: title, body: body));
  }
  return out;
}

abstract interface class ReminderScheduler {
  /// Asks the OS for permission; true when notifications may be shown.
  Future<bool> requestPermission();

  /// Cancels every pending reminder, then schedules [reminders].
  Future<void> replaceAll(List<PlannedReminder> reminders);
}

class LocalReminderScheduler implements ReminderScheduler {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  static bool get _supported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        // Permission is asked only after the player opts in.
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestSoundPermission: false,
          requestBadgePermission: false,
        ),
      ),
    );
    _ready = true;
  }

  @override
  Future<bool> requestPermission() async {
    if (!_supported) return false;
    await _init();
    if (Platform.isAndroid) {
      return await _plugin
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >()
              ?.requestNotificationsPermission() ??
          false;
    }
    return await _plugin
            .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin
            >()
            ?.requestPermissions(alert: true, sound: true) ??
        false;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    if (!_supported) return;
    await _init();
    await _plugin.cancelAll();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'daily_games',
        'Günlük oyunlar',
        channelDescription: 'Günlük seri ve haftalık Passa hatırlatmaları',
      ),
      iOS: DarwinNotificationDetails(),
    );
    for (final r in reminders) {
      await _plugin.zonedSchedule(
        id: r.id,
        scheduledDate: tz.TZDateTime.from(r.at, tz.UTC),
        notificationDetails: details,
        // Inexact is enough for a reminder and needs no alarm permission.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        title: r.title,
        body: r.body,
      );
    }
  }
}

/// Keeps the device's reminders in step with the `daily` notification
/// preference and the latest server streak.
class DailyReminders {
  DailyReminders._();

  static ReminderScheduler scheduler = LocalReminderScheduler();
  static DateTime Function() clock = DateTime.now;
  static DailyStreak? _streak;
  static List<PlannedReminder>? _applied;

  /// Replans; a no-op when nothing changed. Never throws: a reminder failure
  /// must not break the screen that asked for it.
  static Future<void> sync(AppPreferences prefs, {DailyStreak? streak}) async {
    if (streak != null) _streak = streak;
    final plan = prefs.notification('daily')
        ? planDailyReminders(now: clock(), streak: _streak)
        : const <PlannedReminder>[];
    if (_applied != null && listEquals(_applied, plan)) return;
    try {
      await scheduler.replaceAll(plan);
      _applied = plan;
    } catch (e) {
      debugPrint('Daily reminders not scheduled: $e');
    }
  }

  /// Turns the reminders on after the OS grants permission; returns whether
  /// they are on.
  static Future<bool> enable(AppPreferences prefs) async {
    var granted = false;
    try {
      granted = await scheduler.requestPermission();
    } catch (e) {
      debugPrint('Notification permission failed: $e');
    }
    await prefs.setNotification('daily', granted);
    await sync(prefs);
    return granted;
  }

  static Future<void> disable(AppPreferences prefs) async {
    await prefs.setNotification('daily', false);
    await sync(prefs);
  }

  @visibleForTesting
  static void reset() {
    _streak = null;
    _applied = null;
  }
}
