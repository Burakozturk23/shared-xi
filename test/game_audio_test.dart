import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_xi/app/app_feedback.dart';
import 'package:shared_xi/app/app_preferences.dart';
import 'package:shared_xi/app/game_audio.dart';

class AudioLog implements AudioBackend {
  final calls = <String>[];
  final volumes = <double>[];
  @override
  Future<void> playMusic(String asset, double volume) async =>
      calls.add('music:$asset');
  @override
  Future<void> setMusicVolume(double volume) async => volumes.add(volume);
  @override
  Future<void> pauseMusic() async => calls.add('pause');
  @override
  Future<void> resumeMusic() async => calls.add('resume');
  @override
  Future<void> stopMusic() async => calls.add('stop');
  @override
  Future<void> playSfx(String asset, double volume, {Sfx? sfx}) async =>
      calls.add('sfx:$asset@$volume');
  @override
  Future<void> dispose() async {}
  List<String> get music => calls.where((c) => c.startsWith('music:')).toList();
  List<String> get sfx => calls.where((c) => c.startsWith('sfx:')).toList();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppPreferences prefs;
  late AudioLog log;
  late GameAudio audio;
  var now = DateTime(2026, 10, 27);
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await AppPreferences.load();
    log = AudioLog();
    audio = GameAudio(preferences: prefs, backend: log, clock: () => now);
    GameAudio.instance = audio;
  });
  tearDown(() async {
    GameAudio.instance = null;
    await audio.dispose();
  });
  const settle = Duration(seconds: 2);

  testWidgets(
    'one background track: inner scenes win, same track never restarts',
    (t) async {
      audio.start();
      await t.pump(settle);
      expect(log.music, ['music:${MusicTrack.menu.asset}']);
      final puzzle = audio.enter(MusicTrack.puzzle);
      await t.pump(settle);
      final nested = audio.enter(MusicTrack.puzzle);
      await t.pump(settle);
      audio.leave(nested);
      await t.pump(settle);
      expect(log.music, [
        'music:${MusicTrack.menu.asset}',
        'music:${MusicTrack.puzzle.asset}',
      ]);
      audio.update(puzzle, MusicTrack.rush);
      await t.pump(settle);
      audio.leave(puzzle);
      await t.pump(settle);
      expect(log.music.skip(2), [
        'music:${MusicTrack.rush.asset}',
        'music:${MusicTrack.menu.asset}',
      ]);
      expect(
        MusicTrack.values
            .map((m) => m.asset)
            .every((a) => a.endsWith('_loop.ogg')),
        isTrue,
      );
    },
  );

  testWidgets(
    'tracks play at one level; quiet lobbies lower; music switch stops and restarts',
    (t) async {
      audio.start();
      await t.pump(settle);
      final story = audio.enter(MusicTrack.story);
      await t.pump(settle);
      // The story cut is the quietest: it gets a gain instead of a cut (-22.3 -> -20 LUFS).
      expect(log.volumes.last, closeTo(.27 * MusicTrack.story.gain, .001));
      expect(MusicTrack.story.gain, greaterThan(1));
      audio.update(story, MusicTrack.menu, quiet: true);
      await t.pump(settle);
      expect(log.volumes.last, closeTo(.27 * MusicTrack.menu.gain * .5, .001));
      await prefs.setMusic(false);
      await t.pump(settle);
      expect(log.calls.last, 'stop');
      final before = log.music.length;
      audio.enter(MusicTrack.competitive);
      await t.pump(settle);
      expect(log.music.length, before);
      await prefs.setMusic(true);
      await t.pump(settle);
      expect(log.music.last, 'music:${MusicTrack.competitive.asset}');
      await prefs.setMusicVolume(.5);
      await t.pump();
      expect(log.volumes.last, closeTo(.5 * MusicTrack.competitive.gain, .001));
    },
  );

  test(
    'every cut lands on the same loudness; the hot MP3 masters are turned down',
    () {
      for (final track in MusicTrack.values) {
        for (final mp3 in [true, false]) {
          final lufs = mp3 ? track.mp3Lufs : track.oggLufs;
          final level =
              lufs + 20 * math.log(track.gainFor(mp3: mp3)) / math.ln10;
          expect(
            level,
            closeTo(MusicTrack.targetLufs, .01),
            reason: track.file,
          );
        }
      }
      // neon_pas_v3.mp3 measured -13.6 LUFS (peak -1.8 dBFS): about 6.4 dB down.
      expect(MusicTrack.competitive.gainFor(mp3: true), closeTo(.479, .005));
      expect(MusicTrack.story.gainFor(mp3: true), greaterThan(1));
    },
  );

  testWidgets('a track change fades out from the level actually heard', (
    t,
  ) async {
    audio.start();
    await t.pump(settle);
    final story = audio.enter(MusicTrack.story);
    await t.pump(settle);
    final heard = log.volumes.last;
    log.volumes.clear();
    audio.leave(story);
    await t.pump(settle);
    // The first fade-out step is just below the story level, never a jump up
    // to the raw music volume.
    expect(log.volumes.first, closeTo(heard * 6 / 7, .001));
    expect(log.volumes.first, lessThan(heard));
  });

  test(
    'the voice pool keeps a long stinger and cuts the oldest short effect',
    () {
      var clock = DateTime(2026, 11, 1);
      final pool = VoicePool(3, clock: () => clock);
      expect(pool.take(Sfx.champion), 0);
      expect(pool.take(Sfx.uiTap), 1);
      expect(pool.take(Sfx.answerCorrect), 2);
      clock = clock.add(const Duration(milliseconds: 50));
      // All busy: the champion voice (2.7 s) is kept; the short one ending first goes.
      expect(pool.take(Sfx.coinReward), 1);
      expect(pool.take(Sfx.cardFlip), 2);
      clock = clock.add(const Duration(seconds: 3));
      expect(pool.take(Sfx.goal), 0);
    },
  );

  testWidgets('web unlock replays the current track at its level', (t) async {
    audio.start();
    await t.pump(settle);
    final before = log.music.length;
    audio.retryMusic();
    await t.pump();
    expect(log.music.length, before + 1);
    expect(log.music.last, 'music:${MusicTrack.menu.asset}');
  });

  testWidgets('a grant plays its coin or streak cue, then the XP cue', (
    t,
  ) async {
    await AppFeedback.earned(coins: 15, xp: 15);
    await t.pump(AppFeedback.xpDelay);
    expect(log.sfx, [
      'sfx:audio/sfx/coin_reward.wav@0.55',
      'sfx:audio/sfx/xp_reward.wav@0.55',
    ]);
    now = now.add(const Duration(seconds: 1));
    log.calls.clear();
    await AppFeedback.earned(coins: 20, xp: 25, streak: true);
    await t.pump(AppFeedback.xpDelay);
    expect(log.sfx, [
      'sfx:audio/sfx/streak.wav@0.55',
      'sfx:audio/sfx/xp_reward.wav@0.55',
    ]);
    now = now.add(const Duration(seconds: 1));
    log.calls.clear();
    await AppFeedback.earned(coins: 20, xp: 25, levelUp: true);
    await t.pump(AppFeedback.xpDelay);
    expect(log.sfx, ['sfx:audio/sfx/level_up.wav@0.55']);
    await t.pump(settle); // the level-up cue ducks the music for 1.6 s
  });

  testWidgets(
    'background and rewarded ads pause music and resume the same track',
    (t) async {
      audio.start();
      await t.pump(settle);
      audio.didChangeAppLifecycleState(AppLifecycleState.paused);
      audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await t.pump(settle);
      audio.suspend('rewarded_ad');
      audio.suspend('rewarded_ad');
      audio.release('rewarded_ad');
      await t.pump(settle);
      expect(log.calls.where((c) => !c.startsWith('music')), [
        'pause',
        'resume',
        'pause',
        'resume',
      ]);
      expect(log.music, ['music:${MusicTrack.menu.asset}']);
    },
  );

  testWidgets(
    'backgrounding mid-fade resumes the loaded track, then finishes the switch',
    (t) async {
      audio.start();
      await t.pump(settle);
      audio.enter(MusicTrack.rush);
      await t.pump(const Duration(milliseconds: 100));
      audio.didChangeAppLifecycleState(AppLifecycleState.paused);
      await t.pump(settle);
      expect(log.music, ['music:${MusicTrack.menu.asset}']);
      audio.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await t.pump(settle);
      expect(log.music, [
        'music:${MusicTrack.menu.asset}',
        'music:${MusicTrack.rush.asset}',
      ]);
      expect(log.calls.contains('resume'), isFalse);
    },
  );

  test(
    'effects respect the switch, volume, 120 ms throttle and online event IDs',
    () async {
      audio.play(Sfx.answerCorrect);
      audio.play(Sfx.answerCorrect);
      now = now.add(const Duration(milliseconds: 121));
      audio.play(Sfx.answerCorrect);
      audio.play(Sfx.opponentJoin, eventId: 'room:1:join');
      now = now.add(const Duration(seconds: 1));
      audio.play(Sfx.opponentJoin, eventId: 'room:1:join');
      expect(log.sfx, [
        'sfx:audio/sfx/answer_correct.wav@0.55',
        'sfx:audio/sfx/answer_correct.wav@0.55',
        'sfx:audio/sfx/online_opponent_join.wav@0.55',
      ]);
      await prefs.setSfxVolume(2);
      expect(prefs.sfxVolume, 1);
      await prefs.setSound(false);
      now = now.add(const Duration(seconds: 1));
      audio.play(Sfx.coinReward);
      expect(log.sfx.length, 3);
    },
  );

  testWidgets(
    'MusicScene rebuilds and nested routes keep the playing story track',
    (t) async {
      audio.start();
      await t.pump(settle);
      final key = GlobalKey<NavigatorState>();
      await t.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          home: const MusicScene(
            track: MusicTrack.story,
            child: Text('Hikâye'),
          ),
        ),
      );
      await t.pump(settle);
      await t.pumpWidget(
        MaterialApp(
          navigatorKey: key,
          home: const MusicScene(
            track: MusicTrack.story,
            child: Text('Hikâye yeniden'),
          ),
        ),
      );
      key.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) =>
              const MusicScene(track: MusicTrack.story, child: Text('Bölüm 2')),
        ),
      );
      await t.pumpAndSettle();
      await t.pump(settle);
      key.currentState!.pop();
      await t.pumpAndSettle();
      await t.pump(settle);
      expect(log.music, [
        'music:${MusicTrack.menu.asset}',
        'music:${MusicTrack.story.asset}',
      ]);
      await t.pumpWidget(const SizedBox());
      await t.pump(settle);
      expect(log.music.last, 'music:${MusicTrack.menu.asset}');
    },
  );

  test(
    'old sound choice migrates without loss; new volumes default and persist',
    () async {
      SharedPreferences.setMockInitialValues({'linkball.sound': false});
      final old = await AppPreferences.load();
      expect(old.sound, isFalse);
      expect(old.music, isFalse);
      expect(old.musicVolume, AppPreferences.defaultMusicVolume);
      expect(old.sfxVolume, AppPreferences.defaultSfxVolume);
      await old.setMusic(true);
      await old.setMusicVolume(.4);
      final reloaded = await AppPreferences.load();
      expect(reloaded.sound, isFalse);
      expect(reloaded.music, isTrue);
      expect(reloaded.musicVolume, .4);
    },
  );

  test('every pack asset ships and is declared once in pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, contains('- assets/audio/music/'));
    expect(pubspec, contains('- assets/audio/sfx/'));
    for (final track in MusicTrack.values) {
      for (final file in ['${track.file}.mp3', '${track.file}_loop.ogg']) {
        expect(
          File('assets/audio/music/$file').lengthSync(),
          greaterThan(100000),
          reason: file,
        );
      }
    }
    expect(Sfx.values.length, 23);
    for (final sfx in Sfx.values) {
      expect(
        File('assets/${sfx.asset}').lengthSync(),
        greaterThan(1000),
        reason: sfx.file,
      );
    }
  });
}
