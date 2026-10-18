import '../models/daily_words.dart';
import 'daily_words_service.dart';

/// Official Lingo uses the immutable daily server pack. No local answer picker,
/// answer key, category switching or purchased letters remain on this path.
class FutbolLingoService extends DailyWordsService {
  FutbolLingoService({super.transport, super.signIn, super.currentUser});
  static String normalizeWord(String value) => dailyWordKey(value);
  static const minWordLength = 4;
  static const maxWordLength = 9;
}
