import 'package:shared_preferences/shared_preferences.dart';

class HighScoreService {
  static const String _defaultKey = "high_score";

  static Future<int> getHighScore({String key = _defaultKey}) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key) ?? 0;
  }

  static Future<void> saveHighScore(int score, {String key = _defaultKey}) async {
    final prefs = await SharedPreferences.getInstance();

    final currentHighScore = prefs.getInt(key) ?? 0;

    if (score > currentHighScore) {
      await prefs.setInt(key, score);
    }
  }
}