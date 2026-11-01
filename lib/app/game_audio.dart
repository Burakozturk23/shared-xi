import 'dart:async';
import 'dart:collection';

import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'app_preferences.dart';

/// Five shared tracks from the 25 Oct 2026 audio pack (M1–M5).
///
/// [mp3Lufs] / [oggLufs] are the measured integrated loudness (EBU R128) of
/// each cut. The MP3 masters run up to 7 dB hotter than the Ogg loops, so
/// without a per-cut gain Apple and web players heard the rival and final
/// themes harsh and the story theme faint.
enum MusicTrack {
  menu('neon_tribun_v2_5', -17.1, -20.1),
  story('kupa_ani_v6_story', -22.5, -22.3),
  puzzle('tactical_focus_v2', -17.5, -19.4),
  rush('final_whistle_rush_v2', -14.7, -20.6),
  competitive('neon_pas_v3', -13.6, -20.6);

  const MusicTrack(this.file, this.mp3Lufs, this.oggLufs);
  final String file;
  final double mp3Lufs, oggLufs;

  /// Every cut is brought to this level before the player's volume applies.
  static const targetLufs = -20.0;

  static bool get _mp3 => kIsWeb ||
      defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS;

  /// Android/desktop loop the Ogg Vorbis cut; Apple and web use the MP3 cut.
  String get asset => _mp3 ? 'audio/music/$file.mp3' : 'audio/music/${file}_loop.ogg';

  /// Linear gain that brings the cut this platform plays to [targetLufs].
  double get gain => gainFor(mp3: _mp3);
  double gainFor({required bool mp3}) => math.pow(10, (targetLufs - (mp3 ? mp3Lufs : oggLufs)) / 20).toDouble();
}

/// The 23 effects in the pack. Asset names match `assets/audio/sfx/<file>.wav`.
/// [ms] is the measured length of each file.
enum Sfx {
  achievement('achievement', 1400),
  answerCorrect('answer_correct', 360),
  answerWrong('answer_wrong', 800),
  cardFlip('card_flip', 280),
  cardSwipe('card_swipe', 450),
  champion('champion', 2680),
  coachRoulette('coach_roulette_short', 1350),
  coinReward('coin_reward', 630),
  connectionAlert('connection_alert_soft', 1050),
  countdown('countdown', 180),
  goal('goal', 2000),
  hintReveal('hint_reveal_soft', 750),
  levelUp('level_up', 1360),
  matchStart('match_start', 1200),
  opponentJoin('online_opponent_join', 1100),
  perfectCombo('perfect_combo', 1100),
  roundTransition('round_transition', 950),
  slotLock('slot_lock', 320),
  softConfirm('soft_confirm', 330),
  streak('streak', 570),
  uiTap('ui_tap', 100),
  whistle('whistle', 530),
  xpReward('xp_reward', 840);

  const Sfx(this.file, this.ms);
  final String file;
  final int ms;

  /// Stingers long enough that cutting them midway is audible.
  bool get long => ms >= 1300;
  String get asset => 'audio/sfx/$file.wav';

  /// Outcome stingers duck the current music instead of fighting it.
  bool get outcome => this == champion || this == whistle || this == achievement || this == levelUp;
}

/// Platform seam: production uses audioplayers, tests use a recorder.
abstract class AudioBackend {
  Future<void> playMusic(String asset, double volume);
  Future<void> setMusicVolume(double volume);
  Future<void> pauseMusic();
  Future<void> resumeMusic();
  Future<void> stopMusic();
  /// [sfx] lets the backend keep long stingers playing (see [VoicePool]).
  Future<void> playSfx(String asset, double volume, {Sfx? sfx});
  Future<void> dispose();
}

/// Picks the voice for a new effect: a voice that has finished first; when all
/// three are busy, the one ending soonest among those not playing a long
/// stinger (a champion or goal sound is cut only if every voice holds one).
class VoicePool {
  VoicePool(this.size, {DateTime Function()? clock}) : _clock = clock ?? DateTime.now;
  final int size;
  final DateTime Function() _clock;
  late final List<DateTime> _until = List.filled(size, DateTime.fromMillisecondsSinceEpoch(0));
  late final List<bool> _long = List.filled(size, false);
  int take(Sfx? sfx) {
    final now = _clock();
    var pick = -1;
    for (var i = 0; i < size; i++) {
      if (!_until[i].isAfter(now)) {
        pick = i; break;
      }
    }
    if (pick < 0) {
      for (final longOk in [false, true]) {
        for (var i = 0; i < size; i++) {
          if (!longOk && _long[i]) continue;
          if (pick < 0 || _until[i].isBefore(_until[pick])) pick = i;
        }
        if (pick >= 0) break;
      }
    }
    _until[pick] = now.add(Duration(milliseconds: sfx?.ms ?? 1000));
    _long[pick] = sfx?.long ?? false;
    return pick;
  }
}

class AudioplayersBackend implements AudioBackend {
  AudioplayersBackend() {
    final android = defaultTargetPlatform == TargetPlatform.android && !kIsWeb;
    _music = AudioPlayer(playerId: 'linkball-music');
    _sfx = List.generate(GameAudio.maxVoices, (i) => AudioPlayer(playerId: 'linkball-sfx-$i'));
    unawaited(_guard(() async {
      // iOS ambient respects the silent switch; Android music takes focus so
      // calls and other media pause it, while effects never steal focus.
      await _music.setAudioContext(AudioContext(
        android: const AudioContextAndroid(contentType: AndroidContentType.music,
          usageType: AndroidUsageType.game, audioFocus: AndroidAudioFocus.gain),
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient)));
      await _music.setReleaseMode(ReleaseMode.loop);
      for (final player in _sfx) {
        await player.setAudioContext(AudioContext(
          android: const AudioContextAndroid(contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.game, audioFocus: AndroidAudioFocus.none),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient)));
        if (android) await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
      }
      await AudioCache.instance.loadAll(Sfx.values.map((s) => s.asset).toList());
    }));
  }
  late final AudioPlayer _music;
  late final List<AudioPlayer> _sfx;
  final VoicePool _voices = VoicePool(GameAudio.maxVoices);
  // Audio is optional: unsupported platforms and missing codecs stay silent.
  static Future<void> _guard(Future<void> Function() task) async {
    try { await task(); } catch (error) { debugPrint('[GameAudio] $error'); }
  }
  @override
  Future<void> playMusic(String asset, double volume) => _guard(() async {
    await _music.stop(); await _music.setVolume(volume); await _music.play(AssetSource(asset), volume: volume);
  });
  @override
  Future<void> setMusicVolume(double volume) => _guard(() => _music.setVolume(volume));
  @override
  Future<void> pauseMusic() => _guard(_music.pause);
  @override
  Future<void> resumeMusic() => _guard(_music.resume);
  @override
  Future<void> stopMusic() => _guard(_music.stop);
  @override
  Future<void> playSfx(String asset, double volume, {Sfx? sfx}) => _guard(() async {
    // A fixed pool of three voices, never a fourth layer; long stingers are kept.
    final player = _sfx[_voices.take(sfx)];
    await player.stop(); await player.play(AssetSource(asset), volume: volume);
  });
  @override
  Future<void> dispose() => _guard(() async {
    await _music.dispose(); for (final p in _sfx) { await p.dispose(); }
  });
}

class _Scene {
  _Scene(this.track, this.quiet);
  MusicTrack track;
  bool quiet;
}

/// App-wide audio owner: one background track, a three-voice effect pool and
/// the pack's rules (fade, no restart on rebuild, throttle, event dedupe,
/// background/ad pause and separate music/effect preferences).
class GameAudio with WidgetsBindingObserver {
  GameAudio({required this.preferences, required AudioBackend backend, DateTime Function()? clock})
      : _backend = backend, _clock = clock ?? DateTime.now {
    preferences.addListener(_preferencesChanged);
    _musicOn = preferences.music;
  }

  static GameAudio? instance;
  static const maxVoices = 3;
  static const throttle = Duration(milliseconds: 120);
  static const fade = Duration(milliseconds: 700);
  static const _fadeSteps = 7;

  final AppPreferences preferences;
  final AudioBackend _backend;
  final DateTime Function() _clock;
  final List<_Scene> _scenes = [];
  final Map<Sfx, DateTime> _lastPlayed = {};
  final LinkedHashSet<String> _events = LinkedHashSet();
  final Set<String> _suspensions = {};
  // _playing is the target; _loaded is what the backend actually holds. They
  // differ only while a fade is between tracks.
  MusicTrack? _playing, _loaded;
  bool _started = false, _foreground = true, _paused = false, _musicOn = true;
  int _generation = 0;
  Timer? _duckTimer;
  bool _ducked = false;
  // The volume last sent to the backend: fades start from what is really heard.
  double _heard = 0;
  bool _webUnlockArmed = false;

  MusicTrack get track => _scenes.isEmpty ? MusicTrack.menu : _scenes.last.track;
  bool get _quiet => _scenes.isNotEmpty && _scenes.last.quiet;
  @visibleForTesting
  MusicTrack? get playing => _playing;

  double get _volume {
    var v = preferences.musicVolume * track.gain;
    if (_quiet) v *= .5;
    if (_ducked) v *= .35;
    return v.clamp(0.0, 1.0);
  }

  Future<void> _setVolume(double v) {
    _heard = v; return _backend.setMusicVolume(v);
  }
  bool get _audible => _started && _foreground && _suspensions.isEmpty && preferences.music;

  /// Starts the menu theme after the first frame; later calls are no-ops.
  void start() {
    if (_started) return;
    _started = true; WidgetsBinding.instance.addObserver(this); _apply();
    if (kIsWeb) _armWebUnlock();
  }

  // 7. Browsers block sound until the first gesture, and the first play()
  // fails silently. The first tap anywhere restarts the current track once.
  void _armWebUnlock() {
    if (_webUnlockArmed) return;
    _webUnlockArmed = true;
    GestureBinding.instance.pointerRouter.addGlobalRoute(_webUnlock);
  }
  void _webUnlock(PointerEvent event) {
    if (event is! PointerDownEvent) return;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(_webUnlock);
    _webUnlockArmed = false;
    retryMusic();
  }

  /// Plays the current track again from the start at its level (web unlock).
  @visibleForTesting
  void retryMusic() {
    final loaded = _loaded;
    if (loaded == null || !_audible || _paused) return;
    _generation++;
    unawaited(_backend.playMusic(loaded.asset, _volume).then((_) => _heard = _volume));
  }

  Object enter(MusicTrack track, {bool quiet = false}) {
    final scene = _Scene(track, quiet); _scenes.add(scene); _apply(); return scene;
  }
  void update(Object token, MusicTrack track, {bool quiet = false}) {
    if (token is! _Scene || (token.track == track && token.quiet == quiet)) return;
    token..track = track..quiet = quiet; _apply();
  }
  void leave(Object token) {
    if (_scenes.remove(token)) _apply();
  }

  /// Rewarded ads and other full-screen media pause the music until released.
  void suspend(String reason) {
    if (_suspensions.add(reason)) _apply();
  }
  void release(String reason) {
    if (_suspensions.remove(reason)) _apply();
  }

  /// Plays an effect. [eventId] makes a re-delivered online/server event silent.
  void play(Sfx sfx, {String? eventId, bool force = false}) {
    if (!force && !preferences.sound) return;
    if (eventId != null) {
      if (!_events.add(eventId)) return;
      if (_events.length > 256) _events.remove(_events.first);
    }
    final now = _clock(); final last = _lastPlayed[sfx];
    if (!force && last != null && now.difference(last) < throttle) return;
    _lastPlayed[sfx] = now;
    if (sfx.outcome) _duck();
    unawaited(_backend.playSfx(sfx.asset, preferences.sfxVolume, sfx: sfx));
  }

  void _duck() {
    _ducked = true; _duckTimer?.cancel();
    if (_playing != null && !_paused) unawaited(_setVolume(_volume));
    _duckTimer = Timer(const Duration(milliseconds: 1600), () {
      _ducked = false; if (_playing != null && !_paused) unawaited(_setVolume(_volume));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground; _apply();
  }

  void _preferencesChanged() {
    if (_musicOn != preferences.music) {
      _musicOn = preferences.music;
      if (!_musicOn) {
        _generation++; _playing = null; _loaded = null; _paused = false; unawaited(_backend.stopMusic());
      }
      _apply();
    } else if (_playing != null && !_paused) {
      unawaited(_setVolume(_volume));
    }
  }

  void _apply() {
    if (!_started) return;
    if (!_audible) {
      if (_playing != null && !_paused) {
        // Cancel any fade; resuming must continue the track that is really loaded.
        _paused = true; _generation++; _playing = _loaded; unawaited(_backend.pauseMusic());
      }
      return;
    }
    if (_playing == track && _loaded == track) {
      if (_paused) { _paused = false; unawaited(_backend.resumeMusic()); }
      unawaited(_setVolume(_volume));
      return;
    }
    unawaited(_switch(track));
  }

  // Fade the old track out, then the new one in. A newer switch cancels this one.
  Future<void> _switch(MusicTrack next) async {
    final generation = ++_generation; final wasPaused = _paused;
    _playing = next; _paused = false;
    if (_loaded != null && !wasPaused) {
      final from = _heard;
      for (var i = _fadeSteps - 1; i >= 0; i--) {
        await Future<void>.delayed(fade ~/ (_fadeSteps * 2));
        if (generation != _generation) return;
        await _setVolume(from * i / _fadeSteps);
      }
    }
    if (generation != _generation) return;
    await _backend.playMusic(next.asset, 0);
    _heard = 0; _loaded = next;
    for (var i = 1; i <= _fadeSteps; i++) {
      await Future<void>.delayed(fade ~/ (_fadeSteps * 2));
      if (generation != _generation) return;
      await _setVolume(_volume * i / _fadeSteps);
    }
  }

  Future<void> dispose() async {
    _generation++; _duckTimer?.cancel(); preferences.removeListener(_preferencesChanged);
    if (_webUnlockArmed) GestureBinding.instance.pointerRouter.removeGlobalRoute(_webUnlock);
    if (_started) WidgetsBinding.instance.removeObserver(this);
    await _backend.dispose();
  }
}

/// Selects the background track while this subtree is mounted. Inner scenes
/// win; leaving restores the outer track. Rebuilds never restart the music,
/// and the same track across nested routes (e.g. Story chapters) keeps playing.
class MusicScene extends StatefulWidget {
  const MusicScene({super.key, required this.track, this.quiet = false, required this.child});
  final MusicTrack track;
  final bool quiet;
  final Widget child;
  @override
  State<MusicScene> createState() => _MusicSceneState();
}

class _MusicSceneState extends State<MusicScene> {
  Object? _token;
  @override
  void initState() {
    super.initState();
    _token = GameAudio.instance?.enter(widget.track, quiet: widget.quiet);
  }
  @override
  void didUpdateWidget(MusicScene old) {
    super.didUpdateWidget(old);
    final token = _token;
    if (token != null) GameAudio.instance?.update(token, widget.track, quiet: widget.quiet);
  }
  @override
  void dispose() {
    final token = _token;
    if (token != null) GameAudio.instance?.leave(token);
    super.dispose();
  }
  @override
  Widget build(BuildContext context) => widget.child;
}
