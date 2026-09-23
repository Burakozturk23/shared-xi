import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Device preferences only. Does not change Firebase identity or game progress.
class AppPreferences extends ChangeNotifier {
  AppPreferences._(this._store) {
    final stored = _store.getString('linkball.theme_mode');
    themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => ThemeMode.system,
    );
    languageCode = _store.getString('linkball.language') == 'en' ? 'en' : 'tr';
    sound = _store.getBool('linkball.sound') ?? true;
    haptics = _store.getBool('linkball.haptics') ?? true;
    onboardingComplete =
        (_store.getInt('linkball.onboarding_version') ?? 0) > 0;
  }

  final SharedPreferences _store;
  late ThemeMode themeMode;
  late String languageCode;
  late bool sound, haptics, onboardingComplete;
  static Future<AppPreferences> load() async =>
      AppPreferences._(await SharedPreferences.getInstance());

  Future<void> setLanguage(String code) async {
    if (code != 'tr' && code != 'en') throw ArgumentError.value(code);
    if (!await _store.setString('linkball.language', code)) {
      throw StateError('Dil kaydedilemedi.');
    }
    languageCode = code;
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    if (!await _store.setString('linkball.theme_mode', mode.name)) {
      throw StateError('Tema kaydedilemedi.');
    }
    themeMode = mode;
    notifyListeners();
  }

  Future<void> setSound(bool value) async {
    if (!await _store.setBool('linkball.sound', value)) {
      throw StateError('Ses tercihi kaydedilemedi.');
    }
    sound = value;
    notifyListeners();
  }

  Future<void> setHaptics(bool value) async {
    if (!await _store.setBool('linkball.haptics', value)) {
      throw StateError('Titreşim tercihi kaydedilemedi.');
    }
    haptics = value;
    notifyListeners();
  }

  Future<void> finishOnboarding() async {
    if (!await _store.setInt('linkball.onboarding_version', 31)) {
      throw StateError('Tanıtım tercihi kaydedilemedi.');
    }
    onboardingComplete = true;
    notifyListeners();
  }

  bool notification(String category) =>
      _store.getBool('linkball.notification.$category') ?? false;
  Future<void> setNotification(String category, bool value) async {
    if (!await _store.setBool('linkball.notification.$category', value)) {
      throw StateError('Tercih kaydedilemedi.');
    }
    notifyListeners();
  }
}

class PreferencesScope extends InheritedNotifier<AppPreferences> {
  const PreferencesScope({
    super.key,
    required AppPreferences preferences,
    required super.child,
  }) : super(notifier: preferences);
  static AppPreferences of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreferencesScope>()!.notifier!;
  static AppPreferences? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PreferencesScope>()?.notifier;
}
