import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum HapticStrength { gentle, standard, strong }

/// Device preferences only. Does not change Firebase identity or game progress.
class AppPreferences extends ChangeNotifier {
  AppPreferences._(this._store) {
    final stored = _store.getString('linkball.theme_mode');
    themeMode = ThemeMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => ThemeMode.system,
    );
    languageCode = _store.getString('linkball.language') == 'en' ? 'en' : 'tr';
    // `linkball.sound` keeps meaning game effects. Music is new: an install that
    // had silenced sound starts with music off too, so nothing becomes louder.
    sound = _store.getBool('linkball.sound') ?? true;
    music = _store.getBool('linkball.music') ?? sound;
    musicVolume = _volume('linkball.music_volume', defaultMusicVolume);
    sfxVolume = _volume('linkball.sfx_volume', defaultSfxVolume);
    haptics = _store.getBool('linkball.haptics') ?? true;
    hapticStrength = HapticStrength.values.firstWhere(
      (value) => value.name == _store.getString('linkball.haptic_strength'),
      orElse: () => HapticStrength.standard,
    );
    onboardingComplete =
        (_store.getInt('linkball.onboarding_version') ?? 0) > 0;
  }

  final SharedPreferences _store;
  late ThemeMode themeMode;
  late String languageCode;
  late HapticStrength hapticStrength;
  late bool sound, music, haptics, onboardingComplete;
  late double musicVolume, sfxVolume;
  static const defaultMusicVolume = .27, defaultSfxVolume = .55;
  double _volume(String key, double fallback) {
    final value = _store.getDouble(key);
    return value == null || !value.isFinite ? fallback : value.clamp(0.0, 1.0);
  }

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

  Future<void> setMusic(bool value) async {
    if (!await _store.setBool('linkball.music', value)) {
      throw StateError('Müzik tercihi kaydedilemedi.');
    }
    music = value;
    notifyListeners();
  }

  Future<void> setMusicVolume(double value) async {
    final v = value.clamp(0.0, 1.0);
    if (!await _store.setDouble('linkball.music_volume', v)) {
      throw StateError('Müzik seviyesi kaydedilemedi.');
    }
    musicVolume = v;
    notifyListeners();
  }

  Future<void> setSfxVolume(double value) async {
    final v = value.clamp(0.0, 1.0);
    if (!await _store.setDouble('linkball.sfx_volume', v)) {
      throw StateError('Efekt seviyesi kaydedilemedi.');
    }
    sfxVolume = v;
    notifyListeners();
  }

  Future<void> setHaptics(bool value) async {
    if (!await _store.setBool('linkball.haptics', value)) {
      throw StateError('Titreşim tercihi kaydedilemedi.');
    }
    haptics = value;
    notifyListeners();
  }

  Future<void> setHapticStrength(HapticStrength value) async {
    if (!await _store.setString('linkball.haptic_strength', value.name)) {
      throw StateError('Titreşim tercihi kaydedilemedi.');
    }
    hapticStrength = value;
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

  /// The one-time reminder offer after the first daily game was answered.
  bool get reminderOffered =>
      _store.getBool('linkball.notification.offered') ?? false;
  Future<void> markReminderOffered() async {
    await _store.setBool('linkball.notification.offered', true);
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
