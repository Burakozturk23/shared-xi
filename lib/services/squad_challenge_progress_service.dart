import 'package:shared_preferences/shared_preferences.dart';

/// Squad Challenge progression (yıldız + unlock)
/// SharedPreferences ile lokal saklanır.
class SquadChallengeProgressService {
  SquadChallengeProgressService._();
  static final SquadChallengeProgressService instance =
      SquadChallengeProgressService._();

  static const _prefix = 'sc_stars_';
  static const _totalKey = 'sc_total_stars';

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  /// Tema için kaydedilmiş en yüksek yıldız (0-3)
  Future<int> getStars(String themeId) async {
    await init();
    return _prefs!.getInt('$_prefix$themeId') ?? 0;
  }

  /// Toplam yıldız
  Future<int> getTotalStars() async {
    await init();
    return _prefs!.getInt(_totalKey) ?? 0;
  }

  /// Yeni skordan yıldız hesapla ve kaydet (sadece daha yüksekse)
  /// Dönüş: yeni yıldız sayısı (0-3)
  Future<int> saveScore(String themeId, int totalScore) async {
    await init();

    int stars = 0;
    if (totalScore >= 95) {
      stars = 3;
    } else if (totalScore >= 80) {
      stars = 2;
    } else if (totalScore >= 60) {
      stars = 1;
    }

    final current = await getStars(themeId);
    if (stars > current) {
      // Farkı total'e ekle
      final total = await getTotalStars();
      await _prefs!.setInt(_totalKey, total + (stars - current));
      await _prefs!.setInt('$_prefix$themeId', stars);
    }

    return stars;
  }

  /// Tema kilitli mi?
  Future<bool> isUnlocked(int requiredStars) async {
    if (requiredStars <= 0) return true;
    final total = await getTotalStars();
    return total >= requiredStars;
  }

  /// Debug / reset
  Future<void> resetAll() async {
    await init();
    final keys = _prefs!.getKeys().where((k) => k.startsWith(_prefix) || k == _totalKey);
    for (final k in keys) {
      await _prefs!.remove(k);
    }
  }
}
