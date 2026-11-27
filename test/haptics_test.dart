import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/app/app_feedback.dart';
import 'package:shared_xi/app/app_preferences.dart';
import 'package:shared_xi/app/game_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> pulses;
  var now = DateTime(2026, 11, 7, 12);

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    pulses = [];
    now = now.add(const Duration(minutes: 1));
    AppFeedback.clock = () => now;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'HapticFeedback.vibrate') {
            pulses.add('${call.arguments}'.split('.').last);
          }
          return null;
        });
    final p = await AppPreferences.load();
    await p.setSound(false);
    await p.setHaptics(true);
    AppFeedback.preferences = p;
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    AppFeedback.preferences = null;
    AppFeedback.clock = DateTime.now;
  });

  test(
    'every strength: right is one pulse, wrong is two short pulses',
    () async {
      for (final (strength, pulse) in const [
        (HapticStrength.gentle, 'selectionClick'),
        (HapticStrength.standard, 'lightImpact'),
        (HapticStrength.strong, 'heavyImpact'),
      ]) {
        await AppFeedback.preferences!.setHapticStrength(strength);
        pulses.clear();
        await AppFeedback.answer(correct: true);
        expect(pulses, [pulse], reason: '$strength correct');
        pulses.clear();
        now = now.add(const Duration(seconds: 1));
        await AppFeedback.answer(correct: false);
        expect(pulses, [pulse, pulse], reason: '$strength wrong');
        now = now.add(const Duration(seconds: 1));
      }
    },
  );

  test(
    'a reward in the same event as the answer does not buzz twice',
    () async {
      await AppFeedback.answer(correct: true);
      await AppFeedback.reward(Sfx.coinReward);
      await AppFeedback.earned(coins: 10, xp: 10);
      expect(pulses, ['lightImpact']);
      // A reward on its own (later) still buzzes.
      now = now.add(const Duration(seconds: 2));
      await AppFeedback.reward(Sfx.coinReward);
      expect(pulses, ['lightImpact', 'lightImpact']);
    },
  );

  test('haptics off: answer, reward, earned and taps stay silent', () async {
    await AppFeedback.preferences!.setHaptics(false);
    await AppFeedback.answer(correct: false);
    await AppFeedback.reward(Sfx.coinReward);
    await AppFeedback.earned(coins: 5);
    await AppFeedback.selection();
    expect(pulses, isEmpty);
  });

  test('answerFrom reads the session counters a mode returns', () async {
    expect(
      AppFeedback.answerFrom({'id': 's', 'wrong': 0}, {'id': 's', 'wrong': 1}),
      isFalse,
    );
    now = now.add(const Duration(seconds: 1));
    expect(
      AppFeedback.answerFrom(
        {'id': 's', 'found': false},
        {'id': 's', 'found': true},
      ),
      isTrue,
    );
    now = now.add(const Duration(seconds: 1));
    expect(
      AppFeedback.answerFrom({'id': 's', 'lives': 3}, {'id': 's', 'lives': 2}),
      isFalse,
    );
    // A hint or a new session is not an answer.
    expect(
      AppFeedback.answerFrom(
        {'id': 's', 'wrong': 1, 'hints': 0},
        {'id': 's', 'wrong': 1, 'hints': 1},
      ),
      isNull,
    );
    expect(
      AppFeedback.answerFrom({'id': 'a', 'score': 1}, {'id': 'b', 'score': 5}),
      isNull,
    );
    await Future<void>.delayed(const Duration(milliseconds: 200));
    // Wrong (2 pulses) + found (1) + lost a life (2); the hint and new session add none.
    expect(pulses, List.filled(5, 'lightImpact'));
  });
}
