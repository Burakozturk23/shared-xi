import 'dart:async';
import 'dart:collection';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'app_preferences.dart';

/// Five shared tracks from the 25 Oct 2026 audio pack (M1–M5).
enum MusicTrack {
  menu('neon_tribun_v2_5'),
  story('kupa_ani_v6_story'),
  puzzle('tactical_focus_v2'),
  rush('final_whistle_rush_v2'),
  competitive('neon_pas_v3');

  const MusicTrack(this.file);
  final String file;

  /// Android/desktop loop the Ogg Vorbis cut; Apple and web use the MP3 cut.
  String get asset {
    final apple = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.macOS);
    return kIsWeb || apple ? 'audio/music/$file.mp3' : 'audio/music/${file}_loop.ogg';
  }
}

/// The 23 effects in the pack. Asset names match `assets/audio/sfx/<file>.wav`.
enum Sfx {
  achievement('achievement'),
  answerCorrect('answer_correct'),
  answerWrong('answer_wrong'),
  cardFlip('card_flip'),
  cardSwipe('card_swipe'),
  champion('champion'),
  coachRoulette('coach_roulette_short'),
  coinReward('coin_reward'),
  connectionAlert('connection_alert_soft'),
  countdown('countdown'),
  goal('goal'),
  hintReveal('hint_reveal_soft'),
  levelUp('level_up'),
  matchStart('match_start'),
  opponentJoin('online_opponent_join'),
  perfectCombo('perfect_combo'),
  roundTransition('round_transition'),
  slotLock('slot_lock'),
  softConfirm('soft_confirm'),
  streak('streak'),
  uiTap('ui_tap'),
  whistle('whistle'),
  xpReward('xp_reward');

  const Sfx(this.file);
  final String file;
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
  Future<void> playSfx(String asset, double volume);
  Future<void> dispose();
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
  int _next = 0;
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
  Future<void> playSfx(String asset, double volume) => _guard(() async {
    // A fixed pool of three voices: the oldest effect is cut, never a fourth layer.
    final player = _sfx[_next]; _next = (_next + 1) % _sfx.length;
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
  static const _storyLevel = 0.20 / 0.27;

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

  MusicTrack get track => _scenes.isEmpty ? MusicTrack.menu : _scenes.last.track;
  bool get _quiet => _scenes.isNotEmpty && _scenes.last.quiet;
  @visibleForTesting
  MusicTrack? get playing => _playing;

  double get _volume {
    var v = preferences.musicVolume;
    if (track == MusicTrack.story) v *= _storyLevel;
    if (_quiet) v *= .5;
    if (_ducked) v *= .35;
    return v.clamp(0.0, 1.0);
  }
  bool get _audible => _started && _foreground && _suspensions.isEmpty && preferences.music;

  /// Starts the menu theme after the first frame; later calls are no-ops.
  void start() {
    if (_started) return;
    _started = true; WidgetsBinding.instance.addObserver(this); _apply();
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
    unawaited(_backend.playSfx(sfx.asset, preferences.sfxVolume));
  }

  void _duck() {
    _ducked = true; _duckTimer?.cancel();
    if (_playing != null && !_paused) unawaited(_backend.setMusicVolume(_volume));
    _duckTimer = Timer(const Duration(milliseconds: 1600), () {
      _ducked = false; if (_playing != null && !_paused) unawaited(_backend.setMusicVolume(_volume));
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
      unawaited(_backend.setMusicVolume(_volume));
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
      unawaited(_backend.setMusicVolume(_volume));
      return;
    }
    unawaited(_switch(track));
  }

  // Fade the old track out, then the new one in. A newer switch cancels this one.
  Future<void> _switch(MusicTrack next) async {
    final generation = ++_generation; final wasPaused = _paused;
    _playing = next; _paused = false;
    if (_loaded != null && !wasPaused) {
      final from = preferences.musicVolume;
      for (var i = _fadeSteps - 1; i >= 0; i--) {
        await Future<void>.delayed(fade ~/ (_fadeSteps * 2));
        if (generation != _generation) return;
        await _backend.setMusicVolume(from * i / _fadeSteps);
      }
    }
    if (generation != _generation) return;
    await _backend.playMusic(next.asset, 0);
    _loaded = next;
    for (var i = 1; i <= _fadeSteps; i++) {
      await Future<void>.delayed(fade ~/ (_fadeSteps * 2));
      if (generation != _generation) return;
      await _backend.setMusicVolume(_volume * i / _fadeSteps);
    }
  }

  Future<void> dispose() async {
    _generation++; _duckTimer?.cancel(); preferences.removeListener(_preferencesChanged);
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
