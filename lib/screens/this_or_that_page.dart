import 'choice_page.dart';

class ThisOrThatPage extends ChoicePage {
  const ThisOrThatPage({super.key, String bracketId = 'prime_battles_32'})
      : super(mode: 'this_or_that', initialTheme: bracketId);
}
