import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../widgets/grid_criterion_label.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/game_ui.dart';
import '../widgets/hub_ui.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/online_ui.dart';
import '../services/game_error.dart';
import '../app/app_feedback.dart';
import '../app/game_audio.dart';
import '../app/route_appearance.dart';
import '../models/rewarded_ad_models.dart';
import '../services/pvp_service.dart';
import '../services/warm_up.dart';
import '../widgets/player_portrait.dart';
import '../widgets/bot_arena.dart';
import '../widgets/club_race_arena.dart';
import '../widgets/five_slot_reel.dart';
import '../widgets/manager_draft.dart';
import '../widgets/online_series.dart';
import '../widgets/friend_match_invite_button.dart';
import 'online_mode_catalog.dart';

class PvpPage extends StatefulWidget {
  const PvpPage({
    super.key,
    required this.mode,
    required this.playKind,
    this.joinCode,
    this.service,
  });
  final OnlinePlayMode mode;
  final String playKind;
  final String? joinCode;
  final PvpService? service;
  @override
  State<PvpPage> createState() => _PvpPageState();
}

class _PvpPageState extends State<PvpPage> with WidgetsBindingObserver {
  PitchColors get palette => PitchColors.of(context);
  Color get accent => palette.accent;
  late final PvpService service = widget.service ?? PvpService();
  Map<String, dynamic> data = {}, room = {};
  final code = TextEditingController(), query = TextEditingController();
  List<Map<String, dynamic>> results = [];
  Map<String, dynamic>? selected;
  String? target, criterion, error, feedback;
  // Online Çinko (cinkoRules 2): the connected open cells picked for a player.
  final Set<int> cinkoCells = {};
  String profile = 'standard', formation = '433';
  final Set<String> xi = {};
  double press = .5, tempo = .5, width = .5;
  bool busy = false,
      connected = true,
      foreground = true,
      joinedFromInvite = false,
      accountChanged = false;
  Timer? poller, ticker, typing, retryTimer;

  /// Quiet retries after a brief connection drop; reset by any good reply.
  int linkMisses = 0;
  static const maxLinkMisses = 3;
  // A name search is in flight / the last finished search found nothing.
  bool searching = false, noMatch = false;
  final clock = Stopwatch();
  int serverNow = 0, searchSerial = 0;
  bool get ranked => room.isNotEmpty
      ? room['playKind'] == 'ranked'
      : widget.playKind == 'ranked';
  String get mode => widget.mode.wireName;
  String get uid => '${room['myUid']}';
  bool get clubRace => ['club_club', 'club_country'].contains(mode);

  /// Club Manager draft (managerRules 3): snake picks, then plan and captain.
  bool get draftMode => mode == 'club_manager' && room['managerRules'] == 3;
  String? draftPick, draftPlan, draftCaptain;

  /// Draft results whose match was watched (or skipped): the result shows.
  final Set<String> playbackDone = {};
  String draftFilter = 'ALL';

  /// Random Five in rounds: a new five each round, one guess per player.
  bool get fiveRounds => mode == 'random_five' && room['fiveRules'] == 3;

  /// Loto as the bot plays it (lotoRules 3): own cards, players called one by one.
  bool get lotoCalls => mode == 'loto' && room['lotoRules'] == 3;
  bool get cinkoV2 => mode == 'cinko' && room['cinkoRules'] == 2;
  bool get done =>
      ['finished', 'cancelled', 'forfeit', 'expired'].contains(room['status']);

  /// Friend rooms opened as a three-game series (first to two wins).
  OnlineSeries get series => OnlineSeries(rewardMap(room['series']));
  String get rivalUid =>
      room['host'] == uid ? '${room['guest']}' : '${room['host']}';
  String get seriesLine {
    final s = series;
    final rival = rewardMap(room['names'])[rivalUid] ?? 'Rakip';
    return 'Üç maçlık seri · ${s.game}. maç · '
        'Sen ${s.winsOf(uid)} – ${s.winsOf(rivalUid)} $rival';
  }

  /// A series game ended and the next one is open: the screen moves there by
  /// itself after [seriesJumpLeft] ticks (a Club Manager match plays out
  /// first).
  int? seriesJumpLeft;
  static const seriesJumpDelay = 10;
  bool get seriesNext =>
      done &&
      series.active &&
      !series.over &&
      room['nextRoom'] != null &&
      ['finished', 'forfeit'].contains(room['status']) &&
      (rewardMap(room['simulation'])['rules'] != 3 ||
          playbackDone.contains('${room['id']}'));
  int get seriesJumpSeconds => seriesJumpLeft ?? seriesJumpDelay;
  Future<void> nextSeriesGame() async {
    seriesJumpLeft = null;
    setState(() {
      xi.clear();
      target = null;
      selected = null;
      cinkoCells.clear();
    });
    await enter('resume');
  }

  List<Map<String, dynamic>> rows(dynamic value) =>
      (value is List
              ? value
              : value is Map
              ? value.values.toList()
              : <dynamic>[])
          .map(rewardMap)
          .toList();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    load();
    // Isınma: the move and search functions start while the room loads.
    WarmUp.functions(const ['actPvp', 'searchPvp']);
    poller = Timer.periodic(const Duration(seconds: 6), (_) {
      if (room.isNotEmpty &&
          foreground &&
          connected &&
          !accountChanged &&
          !busy &&
          (!done ||
              room['playKind'] == 'friend' ||
              rewardMap(room['reward'])['status'] == 'pending'))
        action('poll');
    });
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && foreground && seriesNext) {
        seriesJumpLeft = math.max(0, seriesJumpSeconds - 1);
        if (!busy && connected && seriesJumpLeft == 0) {
          nextSeriesGame();
        } else {
          setState(() {});
        }
      }
      if (mounted && foreground && room.isNotEmpty && !done) setState(() {});
      if (mounted &&
          foreground &&
          connected &&
          !busy &&
          !done &&
          room.isNotEmpty &&
          DateTime.now().difference(lastPoll) >= fastPoll)
        action('poll');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    poller?.cancel();
    ticker?.cancel();
    typing?.cancel();
    retryTimer?.cancel();
    code.dispose();
    query.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    foreground = state == AppLifecycleState.resumed;
    if (foreground && connected && !busy && room.isNotEmpty && !done)
      action('poll');
  }

  Future<void> run(
    Future<Map<String, dynamic>> Function() task, {
    bool userAction = false,
  }) async {
    if (busy || accountChanged) return;
    setState(() {
      busy = true;
      error = null;
      // A background poll keeps the last answer's message readable.
      if (userAction) feedback = null;
    });
    try {
      final response = await task();
      if (!mounted) return;
      final seen = {for (final f in rows(room['found'])) '${f['id']}'};
      final rivalFinds = room.isEmpty
          ? const <Map<String, dynamic>>[]
          : rows(rewardMap(response['room'])['found'])
                .where((f) => !seen.contains('${f['id']}') && f['uid'] != uid)
                .toList();
      final before = rewardMap(room['owners']);
      final lotoCriteria = rows(room['criteria']);
      final rivalPlaced = room.isEmpty || mode != 'loto'
          ? const <String>[]
          : [
              for (final e in rewardMap(
                rewardMap(response['room'])['owners'],
              ).entries)
                if (!before.containsKey(e.key) &&
                    rewardMap(e.value)['uid'] != uid)
                  '${rewardMap(rewardMap(e.value)['player'])['name'] ?? '?'} → '
                      '${int.tryParse(e.key) != null && int.parse(e.key) < lotoCriteria.length ? GridCriterionLabel.text(lotoCriteria[int.parse(e.key)]) : ''}',
            ];
      setState(() {
        connected = true;
        linkMisses = 0;
        if (response.containsKey('availability')) data = response;
        if (response['room'] != null) {
          final next = rewardMap(response['room']);
          if (next['revision'] != room['revision']) cinkoCells.clear();
          if ('${next['pending']}' != '${room['pending']}') {
            swapAxes = false;
            final free = [
              for (final a in next['anchors'] as List? ?? const [])
                if (!rewardMap(next['owners']).containsKey('$a')) '$a',
            ];
            target = next['pending'] != null && free.length == 1
                ? free.first
                : null;
          }
          if (next['id'] != room['id'] || next['round'] != room['round']) {
            if (next['id'] == room['id'] && next['fiveRules'] == 3)
              feedback = null;
            searchSerial++;
            typing?.cancel();
            searching = noMatch = false;
            xi.clear();
            target = null;
            criterion = null;
            selected = null;
            results = [];
            query.clear();
          }
          _sounds(room, next);
          room = next;
          if (next['id'] != room['id']) {
            draftPick = draftPlan = draftCaptain = null;
            draftFilter = 'ALL';
          }
          // Draft: a selected player the rival just took drops.
          if (next['managerRules'] == 3 &&
              draftPick != null &&
              rewardMap(
                next['picks'],
              ).values.any((v) => (v as List? ?? const []).contains(draftPick)))
            draftPick = null;
          // Loto: a player the rival just placed can no longer be picked.
          if (mode == 'loto' &&
              selected != null &&
              rewardMap(room['used']).containsKey('${selected!['id']}'))
            selected = null;
          final squad = rewardMap(room['mySquad']);
          if (squad.isNotEmpty) {
            xi
              ..clear()
              ..addAll((squad['playerIds'] as List).map((id) => '$id'));
            formation = '${squad['formation']}';
            final t = rewardMap(squad['tactics']);
            press = (t['press'] as num).toDouble();
            tempo = (t['tempo'] as num).toDouble();
            width = (t['width'] as num).toDouble();
          }
          serverNow = (room['serverNow'] as num? ?? 0).toInt();
          clock
            ..reset()
            ..start();
        }
        final receipt = rewardMap(response['receipt']);
        if (receipt['correct'] == false)
          feedback = switch (mode) {
            'loto' => 'Bu futbolcu o hücreye uymuyor. 3 sn bekle.',
            'cinko' =>
              'Seçtiğin kutulardan hiçbiri uymadı · ${receipt['points'] ?? 0} puan.',
            'grid_reverse' =>
              'Bu kriter üç futbolcunun hepsine uymuyor. Sıra rakibe geçti.',
            'grid_classic' || 'grid_random' =>
              'Bu futbolcu iki kritere birden uymuyor. Sıra rakibe geçti.',
            'random_five' when receipt['round'] != null =>
              'Bu isim beş kulübün hiçbirine uymuyor · 0 puan. Beşli kapanınca yenisi gelir.',
            _ => 'Bu futbolcu kriteri karşılamıyor.',
          };
        if (receipt['correct'] == true)
          feedback = switch (mode) {
            'club_club' ||
            'club_country' => 'Doğru! +${receipt['points'] ?? 1} puan',
            'random_five' =>
              'Doğru! ${receipt['clubs'] ?? (room['fivePoints'] as List? ?? const []).indexOf(receipt['points'])} kulüp · +${receipt['points'] ?? 1} puan',
            'loto' => [
              'Doğru! +${receipt['points'] ?? 1} puan',
              for (final l in receipt['lines'] as List? ?? const [])
                '${lineName('$l')} tamamlandı',
            ].join(' · '),
            'grid_classic' || 'grid_random' => 'Doğru! Hücre senin.',
            'grid_reverse' => 'Doğru! Eksen senin.',
            'cinko' =>
              'Hamle tamam · ${(receipt['points'] as num? ?? 0) > 0 ? '+' : ''}${receipt['points'] ?? 0} puan',
            _ => feedback,
          };
        if (lotoCalls && receipt['submitted'] == true)
          feedback = 'Hamlen kaydedildi; çekiliş kapanınca sonuç açılır.';
        if (receipt['accepted'] == true && receipt['correct'] is bool) {
          AppFeedback.sfx(
            receipt['correct'] == true ? Sfx.answerCorrect : Sfx.answerWrong,
          );
        }
        if (receipt['accepted'] == true &&
            (receipt.containsKey('correct') ||
                receipt.containsKey('submitted'))) {
          selected = null;
          results = [];
          query.clear();
          if (gridMode) target = null;
        }
      });
      final notice =
          (clubRace || mode == 'random_five') && rivalFinds.isNotEmpty
          ? 'Rakip buldu: ${rivalFinds.map((f) => f['name']).join(', ')}'
          : rivalPlaced.isNotEmpty
          ? 'Rakip yerleştirdi: ${rivalPlaced.join(', ')}'
          : null;
      if (notice != null && !done)
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              content: Text(notice),
            ),
          );
    } catch (e) {
      if (mounted)
        setState(() {
          accountChanged =
              e is StateError && '${e.message}'.startsWith('Hesap değişti');
          final business =
              userAction &&
              room.isNotEmpty &&
              e is FirebaseFunctionsException &&
              [
                'invalid-argument',
                'failed-precondition',
                'already-exists',
                'aborted',
                'resource-exhausted',
              ].contains(e.code);
          // A brief drop (a lost socket, a slow reply) keeps the match on screen:
          // up to three quiet retries before the room counts as disconnected.
          final transient =
              !business &&
              !accountChanged &&
              connected &&
              room.isNotEmpty &&
              !done &&
              isTransientGameError(e) &&
              linkMisses < maxLinkMisses;
          if (business) {
            feedback = gameErrorMessage(e);
          } else if (transient) {
            linkMisses++;
            if (userAction)
              feedback = 'Bağlantı dalgalandı; hamlen kontrol ediliyor.';
            retryTimer?.cancel();
            retryTimer = Timer(Duration(seconds: linkMisses), () {
              if (mounted && connected && !busy && !accountChanged)
                action('poll');
            });
          } else {
            // Only a genuine loss of an active room plays the soft alert, once per drop.
            if (connected && room.isNotEmpty && !done && !accountChanged)
              AppFeedback.sfx(Sfx.connectionAlert);
            error = gameErrorMessage(e);
            connected = false;
          }
          if (accountChanged) {
            room = {};
            data = {};
            results = [];
            selected = null;
            searchSerial++;
          }
        });
      if (mounted && feedback != null && !_arena && userAction)
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(feedback!)));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  // Room snapshots repeat on every poll; event IDs keep each cue to one play.
  void _sounds(Map<String, dynamic> before, Map<String, dynamic> after) {
    final id = after['id'];
    final status = after['status'];
    if (id == null) return;
    if (status == 'ready' &&
        before['id'] == id &&
        before['status'] == 'waiting') {
      AppFeedback.sfx(Sfx.opponentJoin, eventId: 'pvp:$id:join');
    }
    if (status == 'playing')
      AppFeedback.sfx(Sfx.matchStart, eventId: 'pvp:$id:start');
    final pick = rewardMap(after['lastPick']);
    if (after['managerRules'] == 3 &&
        before['id'] == id &&
        pick.isNotEmpty &&
        '${rewardMap(before['lastPick'])['playerId']}' != '${pick['playerId']}')
      AppFeedback.sfx(Sfx.cardFlip, eventId: 'pvp:$id:pick:${after['pick']}');
    if (status == 'playing' &&
        after['fiveRules'] == 3 &&
        before['id'] == id &&
        before['round'] != null &&
        before['round'] != after['round'])
      AppFeedback.sfx(
        Sfx.coachRoulette,
        eventId: 'pvp:$id:five:${after['round']}',
      );
    if (['finished', 'forfeit'].contains(status) &&
        before['id'] == id &&
        before['status'] != status &&
        rewardMap(after['simulation'])['rules'] != 3) {
      AppFeedback.sfx(
        after['result'] == 'win' ? Sfx.champion : Sfx.whistle,
        eventId: 'pvp:$id:end',
      );
    }
  }

  // Waiting rooms keep a quiet menu theme; Loto and Random Five race the clock.
  MusicTrack get _matchTrack =>
      [OnlinePlayMode.loto, OnlinePlayMode.randomFive].contains(widget.mode)
      ? MusicTrack.rush
      : MusicTrack.competitive;
  bool get _inMatch =>
      room.isNotEmpty && !['waiting', 'ready'].contains(room['status']);
  Future<void> load() async {
    await run(() => service.load(mode));
    if (mounted &&
        connected &&
        !joinedFromInvite &&
        widget.joinCode != null &&
        data.isNotEmpty &&
        // An invite joins its room even when the last match's result is still
        // on screen; a match in progress is kept.
        (room.isEmpty || done) &&
        '${room['id'] ?? ''}'.toUpperCase() !=
            widget.joinCode!.trim().toUpperCase()) {
      joinedFromInvite = true;
      await enter('join', roomCode: widget.joinCode);
    }
  }

  Future<void> enter(String action, {String? roomCode}) async {
    if (action == 'join' && !validRoomCode(roomCode ?? '')) {
      setState(() => feedback = '8 karakterli geçerli oda kodunu gir.');
      return;
    }
    await run(
      () => service.enter(
        mode,
        widget.playKind,
        action,
        code: roomCode?.trim().toUpperCase(),
        profile: profile,
      ),
      userAction: true,
    );
  }

  DateTime lastPoll = DateTime.fromMillisecondsSinceEpoch(0);
  static const weakLinkText =
      'Bağlantı zayıf · yeniden deneniyor. Maç sunucuda sürüyor.';

  /// Sooner than the 6 s poller when the screen is waiting on the server:
  /// a finished countdown or match clock (2 s), the rival's turn in a
  /// turn-based Grid or Çinko, or a simultaneous race whose rival finds should
  /// show quickly (3 s). Otherwise effectively never (the 6 s poller runs).
  Duration get fastPoll {
    final status = room['status'];
    if (status == 'countdown' && seconds(room['startsAt']) == 0 ||
        status == 'playing' && seconds(room['endsAt']) == 0)
      return const Duration(seconds: 2);
    if (status != 'playing') return const Duration(days: 1);
    if ((gridMode || cinkoV2) && !myTurn) return const Duration(seconds: 3);
    if (draftMode) {
      final deadline =
          room[room['phase'] == 'plan' ? 'planDeadline' : 'turnDeadline'];
      if (seconds(deadline) == 0) return const Duration(seconds: 1);
      if (room['phase'] == 'draft' && !myTurn)
        return const Duration(seconds: 2);
      if (room['phase'] == 'plan' && room['myPlan'] != null)
        return const Duration(seconds: 2);
      return const Duration(seconds: 4);
    }
    if (fiveRounds) {
      if (room['roundClosed'] == true)
        return seconds(room['nextRoundAt']) == 0
            ? const Duration(seconds: 1)
            : const Duration(days: 1);
      return seconds(room['roundDeadline']) == 0 || room['myAnswer'] != null
          ? const Duration(seconds: 2)
          : const Duration(seconds: 3);
    }
    if (lotoCalls) {
      if (room['callClosed'] == true)
        return seconds(room['nextCallAt']) == 0
            ? const Duration(seconds: 1)
            : const Duration(days: 1);
      return seconds(room['callDeadline']) == 0 || room['myMove'] != null
          ? const Duration(seconds: 2)
          : const Duration(seconds: 3);
    }
    if (clubRace || mode == 'random_five' || mode == 'loto')
      return const Duration(seconds: 3);
    return const Duration(days: 1);
  }

  Future<void> action(String action, [Map<String, dynamic> extra = const {}]) {
    if (action == 'poll') lastPoll = DateTime.now();
    return run(
      () => service.act(room, action, extra),
      userAction: action != 'poll',
    );
  }

  /// Suggestions follow the typing: a search starts once the name has rested
  /// for [typingPause]. It never waits for a poll or move in flight; only the
  /// newest search may show its result.
  static const typingPause = Duration(milliseconds: 300);
  void typed(String _) {
    typing?.cancel();
    searchSerial++;
    if (mode == 'grid_reverse') {
      final text = query.text.trim();
      setState(() {
        results = text.isEmpty ? [] : criterionMatches(text);
        noMatch = text.isNotEmpty && results.isEmpty;
        final exact = results.where(
          (k) => _plain('${k['name']}') == _plain(text),
        );
        selected = exact.length == 1 ? exact.first : null;
        if (selected != null) results = [];
      });
      return;
    }
    final ready = query.text.trim().length >= 2;
    setState(() {
      selected = null;
      noMatch = false;
      searching = ready;
      if (!ready) results = [];
    });
    if (ready) typing = Timer(typingPause, search);
  }

  Future<void> search() async {
    typing?.cancel();
    if (mode == 'grid_reverse') return typed('');
    final text = query.text.trim();
    if (!connected || text.length < 2) return;
    final serial = ++searchSerial;
    setState(() => searching = true);
    try {
      final found = await service.search(mode, text, roomId: room['id']);
      if (mounted && serial == searchSerial)
        setState(() {
          results = found;
          searching = false;
          noMatch = found.isEmpty;
          // The exact name typed in full is taken without another tap.
          final exact = found.where(
            (p) => _plain('${p['name']}') == _plain(text),
          );
          selected = exact.length == 1 ? exact.first : null;
          if (selected != null) results = [];
        });
    } catch (e) {
      if (mounted && serial == searchSerial)
        setState(() {
          searching = false;
          feedback = gameErrorMessage(e);
        });
    }
  }

  static const _folds = {
    'a': 'àáâãäåā',
    'c': 'çćč',
    'd': 'đ',
    'e': 'èéêëēė',
    'g': 'ğ',
    'i': 'ìíîïı',
    'l': 'ł',
    'n': 'ñń',
    'o': 'òóôõöøō',
    's': 'şśšß',
    'u': 'ùúûüū',
    'y': 'ýÿ',
    'z': 'źżž',
  };

  /// Lower case without accents or punctuation: "José Sosa" == "jose sosa".
  static String _plain(String s) {
    final out = StringBuffer();
    for (final ch in s.toLowerCase().split('')) {
      final base = _folds.entries
          .where((e) => e.value.contains(ch))
          .map((e) => e.key)
          .firstOrNull;
      final c = base ?? ch;
      if (RegExp(r'[a-z0-9]').hasMatch(c)) out.write(c);
    }
    return '$out';
  }

  int seconds(dynamic deadline) =>
      (((deadline as num? ?? 0).toInt() -
                  serverNow -
                  clock.elapsedMilliseconds) /
              1000)
          .ceil()
          .clamp(0, 9999);
  // Loto and Club-Club / Club-Country: a wrong move locks and counts.
  int get locked => room['lockUntil'] == null ? 0 : seconds(room['lockUntil']);
  bool get outOfWrong =>
      room['maxWrong'] != null &&
      (rewardMap(room['wrongMoves'])[uid] as num? ?? 0) >=
          (room['maxWrong'] as num);

  List<Widget> wrongNotes() => [
    if (room['maxWrong'] != null)
      note(
        'Yanlış hamle: ${rewardMap(room['wrongMoves'])[uid] ?? 0} / '
        '${room['maxWrong']} · rakip '
        '${rewardMap(room['wrongMoves'])[room['host'] == uid ? room['guest'] : room['host']] ?? 0}. '
        'Her yanlış ${mode == 'loto' ? 3 : 2} sn kilitler; eşitlikte az yanlış kazanır.',
      ),
    if (locked > 0) note('Yanlış hamle: $locked sn bekle.'),
    if (outOfWrong)
      note('Yanlış hakkın doldu; bu maçta yeni hamle yapamazsın.'),
  ];
  // Grid (gridRules 2): wrong answers decide equal scores; Random pays rare answers.
  String axisName(String a) =>
      '${a.startsWith('r') ? 'Satır' : 'Sütun'} ${int.parse(a[1]) + 1}';
  Widget note(String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.bodyMedium?.copyWith(color: palette.muted),
    ),
  );
  Widget heading(String text) =>
      Text(text, style: Theme.of(context).textTheme.headlineSmall);
  Widget panel(List<Widget> children) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: PitchPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );
  Widget button(String text, VoidCallback? tap, {bool secondary = false}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: secondary
            ? OutlinedButton(
                onPressed: busy || !connected ? null : tap,
                child: Text(text, textAlign: TextAlign.center),
              )
            : FilledButton(
                onPressed: busy || !connected ? null : tap,
                child: Text(text, textAlign: TextAlign.center),
              ),
      );
  Widget choice(
    String label,
    String? value,
    List<Map<String, dynamic>> options,
    void Function(String) change, {
    bool enabled = true,
  }) => DropdownButtonFormField<String>(
    key: ValueKey('$label:$value'),
    initialValue: options.any((p) => p['id'] == value) ? value : null,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: options
        .map(
          (p) => DropdownMenuItem(
            value: '${p['id']}',
            child: Text(
              '${p['label'] ?? p['name']}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        )
        .toList(),
    onChanged: busy || !connected || !enabled
        ? null
        : (v) {
            if (v != null) change(v);
          },
  );

  /// Friend pair modes: the server lists only the options that make a playable
  /// pair with the other side's choice.
  List<Map<String, dynamic>> pairChoices() {
    final host = room['host'] == uid;
    final all = rows(
      data[!host && mode == 'club_country' ? 'countries' : 'clubs'],
    );
    final allowed = room['pairOptions'];
    if (allowed is! List) return all;
    final ids = allowed.map((e) => '$e').toSet();
    return all.where((p) => ids.contains('${p['id']}')).toList();
  }

  String joinOr(Iterable<Object?> names) {
    final text = names.join(' · ');
    return text.isEmpty ? '—' : text;
  }

  Widget setup() {
    final text = Theme.of(context).textTheme;
    final available =
        rewardMap(data['availability'])[ranked
            ? 'rankedEnabled'
            : 'friendEnabled'] ==
        true;
    final linked = data['linked'] == true;
    final history = rows(
      data['history'],
    ).where((r) => r['playKind'] == widget.playKind).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArenaCard(
          glow: palette.accent,
          child: Column(
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: palette.tint,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: palette.accent.withValues(alpha: .5),
                  ),
                ),
                child: Icon(widget.mode.icon, color: palette.accent, size: 34),
              ),
              const SizedBox(height: 12),
              Text(
                ranked ? 'Eşit koşullarda yarış' : 'Arkadaşınla karşılaş',
                textAlign: TextAlign.center,
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                widget.mode.subtitle,
                textAlign: TextAlign.center,
                style: text.bodyMedium?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 10),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 6,
                runSpacing: 6,
                children: [
                  ArenaPill(child: Text(ranked ? 'Dereceli' : 'Dostluk')),
                  ArenaPill(
                    child: Text(ranked ? 'Elo · Coin · XP' : 'Elo ve ödül yok'),
                  ),
                  const ArenaPill(child: Text('Sunucu doğrular')),
                ],
              ),
            ],
          ),
        ),
        if (modeRules() != null) ...[
          const SizedBox(height: 12),
          ArenaNote(icon: Icons.rule_rounded, text: modeRules()!),
        ],
        if (!available) ...[
          const SizedBox(height: 12),
          ArenaNote(
            icon: Icons.block_rounded,
            color: palette.error,
            text: ranked
                ? 'Bu modda dereceli eşleşme şu anda kapalı.'
                : 'Bu modda arkadaş odaları şu anda kapalı.',
          ),
        ],
        if (!linked) ...[
          const SizedBox(height: 12),
          ArenaNote(
            icon: Icons.link_rounded,
            color: hubAmber(context),
            text: 'Online maç için profilinden Google hesabını bağla.',
          ),
        ],
        const SizedBox(height: 16),
        if (data['activeId'] != null &&
            data['activePlayKind'] == widget.playKind) ...[
          ArenaPrimaryButton(
            label: 'Kayıtlı maça devam et',
            icon: Icons.play_arrow_rounded,
            onPressed: busy ? null : () => enter('resume'),
          ),
          const SizedBox(height: 10),
        ],
        if (data['activeId'] != null &&
            data['activePlayKind'] != widget.playKind) ...[
          const ArenaNote(
            text: 'Bu modda diğer eşleşme türünde kayıtlı bir maçın var.',
          ),
          const SizedBox(height: 8),
          ArenaSecondaryButton(
            label: 'Kayıtlı maç ekranını aç',
            icon: Icons.open_in_new_rounded,
            onPressed: () => Navigator.of(context).pushReplacement(
              LinkballRoute(
                modern: true,
                builder: (_) => PvpPage(
                  mode: widget.mode,
                  playKind: '${data['activePlayKind']}',
                  service: service,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
        ],
        if (!ranked) ...[
          const ArenaSection('Oda kur', icon: Icons.add_home_outlined),
          Wrap(
            spacing: 8,
            children: [
              for (final (id, label) in [
                ('standard', 'Tek maç'),
                ('series3', 'Üç maçlık seri'),
              ])
                ChoiceChip(
                  label: Text(label),
                  selected: profile == id,
                  onSelected: (_) => setState(() => profile = id),
                ),
            ],
          ),
          note(
            profile == 'series3'
                ? 'İlk 2 galibiyeti alan seriyi kazanır. Bir maç bitince '
                      'sıradaki maç kendiliğinden açılır; skor maçtan maça '
                      'taşınır ve her maçta başlayan taraf değişir.'
                : 'Tek maç oynanır; sonunda istersen rövanş isteyebilirsin.',
          ),
          const SizedBox(height: 10),
          ArenaPrimaryButton(
            label: 'Oda oluştur',
            icon: Icons.add_rounded,
            onPressed: available && linked && !busy
                ? () => enter('create')
                : null,
          ),
          const ArenaSection('Koda katıl', icon: Icons.vpn_key_outlined),
          RoomCodeField(
            controller: code,
            enabled: !busy && connected,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          ArenaSecondaryButton(
            label: 'Koda katıl',
            icon: Icons.login_rounded,
            onPressed: available && linked && validRoomCode(code.text) && !busy
                ? () => enter('join', roomCode: code.text.trim().toUpperCase())
                : null,
          ),
        ] else
          ArenaPrimaryButton(
            label: 'Rakip ara',
            icon: Icons.search_rounded,
            onPressed: available && linked && !busy
                ? () => enter('search')
                : null,
          ),
        if (history.isNotEmpty) ...[
          const ArenaSection('Son maçların', icon: Icons.history_rounded),
          for (final r in history)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Material(
                color: palette.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: palette.border),
                ),
                clipBehavior: Clip.antiAlias,
                child: ListTile(
                  onTap: () =>
                      run(() => service.act({...r, 'revision': 0}, 'poll')),
                  leading: Icon(
                    r['status'] == 'finished'
                        ? Icons.sports_score_rounded
                        : Icons.flag_outlined,
                    color: palette.accent,
                  ),
                  title: Text(
                    '${r['status'] == 'finished' ? 'Tamamlandı' : 'Sonlandırıldı'} · ${r['id']}',
                  ),
                  subtitle: Text(rewardMap(r['scores']).values.join(' – ')),
                  trailing: const Icon(Icons.chevron_right_rounded),
                ),
              ),
            ),
        ],
      ],
    );
  }

  Widget lobby() {
    final text = Theme.of(context).textTheme;
    final host = room['host'] == uid;
    final ready = rewardMap(room['ready']);
    final choices = rewardMap(room['choices']);
    final names = rewardMap(room['names']);
    final waiting = room['status'] == 'waiting';
    // Friend Club rooms: each side picks a club (Club-Country guest: a country).
    final pairRoom = !ranked && ['club_club', 'club_country'].contains(mode);
    final pickLabels = {
      for (final k in [...rows(data['clubs']), ...rows(data['countries'])])
        '${k['id']}': GridCriterionLabel.text(k),
    };
    final myPick = choices[host ? 'left' : 'right'];
    Widget seat(String? id, String fallback, {required bool mine}) {
      final tone = mine ? Arena.lime : hubAmber(context);
      final here = id != null && id != 'null';
      final isReady = here && ready[id] == true;
      return Expanded(
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: tone.withValues(alpha: here ? .14 : .04),
                border: Border.all(
                  color: tone.withValues(alpha: here ? .8 : .3),
                  width: 2,
                ),
              ),
              child: Icon(
                here ? Icons.person_rounded : Icons.hourglass_empty_rounded,
                color: here ? tone : palette.muted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              here ? '${names[id] ?? fallback}' : fallback,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            ArenaPill(
              color: isReady ? palette.success : palette.muted,
              child: Text(
                !here
                    ? 'Bekleniyor'
                    : isReady
                    ? 'Hazır'
                    : waiting
                    ? 'Odada'
                    : 'Hazırlanıyor',
              ),
            ),
            if (pairRoom && here) ...[
              const SizedBox(height: 6),
              Builder(
                builder: (context) {
                  final pick =
                      choices[id == '${room['host']}' ? 'left' : 'right'];
                  return Text(
                    pick == null ? 'Seçim yok' : pickLabels['$pick'] ?? '$pick',
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.labelMedium?.copyWith(
                      color: pick == null ? palette.muted : tone,
                      fontWeight: FontWeight.w800,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      );
    }

    final rivalId = host ? '${room['guest']}' : '${room['host']}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ArenaCard(
          glow: waiting ? palette.accent : Arena.lime,
          child: Column(
            children: [
              Text(
                waiting
                    ? ranked
                          ? 'Rakip aranıyor'
                          : 'Arkadaşını bekliyorsun'
                    : series.active && series.game > 1
                    ? '${series.game}. maça hazırlan'
                    : 'Maça hazırlan',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                waiting
                    ? ranked
                          ? room['botAt'] is num
                                ? '20 saniye içinde rakip bulunamazsa Linkball Botu ile oynarsın: '
                                      'Elo değişmez, ödül yarı (günde 3 maç).'
                                : '30 saniye içinde rakip bulunamazsa arama kapanır.'
                          : 'Kodu paylaş; arkadaşın aynı modu seçip koda katılsın.'
                    : 'İki oyuncu da hazır olduğunda beş saniyelik geri sayım başlar.',
                textAlign: TextAlign.center,
                style: text.bodySmall?.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  seat(uid, 'Sen', mine: true),
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: waiting
                        ? const SizedBox.square(
                            dimension: 28,
                            child: CircularProgressIndicator(strokeWidth: 3),
                          )
                        : Text(
                            'VS',
                            style: text.titleLarge?.copyWith(
                              fontWeight: FontWeight.w900,
                              color: palette.accent,
                            ),
                          ),
                  ),
                  seat(
                    rivalId == 'null' ? null : rivalId,
                    ranked ? 'Rakip' : 'Arkadaşın',
                    mine: false,
                  ),
                ],
              ),
            ],
          ),
        ),
        if (series.active) ...[
          const SizedBox(height: 12),
          OnlineSeriesStrip(
            series: series,
            uid: uid,
            rival: rivalId,
            names: names,
          ),
        ],
        if (!ranked) ...[
          const SizedBox(height: 12),
          OnlineRoomCode(code: '${room['id']}'),
          if (host && room['guest'] == null) ...[
            const SizedBox(height: 8),
            Center(
              child: FriendMatchInviteButton(
                mode: widget.mode,
                roomCode: '${room['id']}',
              ),
            ),
          ],
        ],
        if (room['status'] == 'ready') ...[
          if (!ranked && ['club_club', 'club_country'].contains(mode)) ...[
            const SizedBox(height: 12),
            ArenaCard(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  choice(
                    host || mode == 'club_club' ? 'Kulübünü seç' : 'Ülkeni seç',
                    choices[host ? 'left' : 'right'],
                    pairChoices(),
                    (v) => action('choose', {'choice': v}),
                  ),
                  const SizedBox(height: 8),
                  ArenaSecondaryButton(
                    label: 'Rastgele seç',
                    icon: Icons.casino_outlined,
                    onPressed: busy || pairChoices().isEmpty
                        ? null
                        : () {
                            final options = pairChoices();
                            final pick =
                                options[math.Random().nextInt(options.length)];
                            action('choose', {'choice': pick['id']});
                          },
                  ),
                  note(
                    room['pairOptions'] is List &&
                            choices[host ? 'right' : 'left'] != null
                        ? 'Yalnızca rakibinin seçimiyle en az 6 ortak futbolcusu olan '
                              'seçenekler listelenir (${(room['pairOptions'] as List).length}).'
                        : 'Eşleşmede en az 6 ortak futbolcu bulunmalı.',
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          ArenaPrimaryButton(
            label: ready[uid] == true
                ? 'Rakibin hazırlanıyor'
                : pairRoom && myPick == null
                ? 'Hazırım · ${host || mode == 'club_club' ? 'kulübün' : 'ülken'} rastgele seçilir'
                : 'Hazırım',
            icon: Icons.check_rounded,
            onPressed: ready[uid] == true || busy
                ? null
                : () => action('ready'),
          ),
        ],
        if (modeRules() != null) ...[
          const ArenaSection('Nasıl oynanır', icon: Icons.rule_rounded),
          ArenaNote(icon: Icons.info_outline_rounded, text: modeRules()!),
        ],
        const SizedBox(height: 12),
        ArenaSecondaryButton(
          label: ranked
              ? 'Aramayı iptal et'
              : series.active && series.game > 1
              ? 'Seriden çekil'
              : 'Odayı kapat',
          icon: Icons.close_rounded,
          color: palette.error,
          onPressed: busy
              ? null
              : series.active && series.game > 1 && !waiting
              ? leave
              : () => action('leave'),
        ),
      ],
    );
  }

  Widget hud() {
    final names = rewardMap(room['names']), scores = rewardMap(room['scores']);
    final turn = room['turnUid'];
    final turnMode = ['grid_classic', 'grid_reverse', 'cinko'].contains(mode);
    return panel([
      Wrap(
        spacing: 16,
        runSpacing: 8,
        children: names.entries
            .map(
              (e) => Text(
                '${e.value}: ${scores[e.key] ?? 0}',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
            .toList(),
      ),
      if (!done)
        note(
          room['status'] == 'countdown'
              ? 'Başlıyor: ${seconds(room['startsAt'])}'
              : turnMode
              ? '${turn == uid ? 'Senin sıran' : 'Rakibinin sırası'} · ${seconds(room['turnDeadline'])} sn'
              : '${seconds(room[mode == 'grid_random' ? 'roundDeadline' : 'endsAt'])} sn',
        ),
      if (!connected)
        note(
          'Bağlantı kesildi. Sunucudaki süre devam eder. Yeniden dene ile maçını kontrol et.',
        )
      else if (linkMisses > 0)
        note(weakLinkText),
      if (series.active) note(seriesLine),
    ]);
  }

  Widget board(int n, List<String> labels, {bool selectable = true}) =>
      LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
          final owners = rewardMap(room['owners']);
          final boardWidth = math.max(
            constraints.maxWidth,
            n * 112.0 * scale + (n - 1) * 6,
          );
          void detail(int i, String? ownerName) => showDialog<void>(
            context: context,
            builder: (_) => AlertDialog(
              title: Text('${i + 1}. hücre'),
              content: Text('${labels[i]}\n${ownerName ?? 'Boş hücre'}'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Kapat'),
                ),
              ],
            ),
          );
          final grid = GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: labels.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: n,
              crossAxisSpacing: 6,
              mainAxisSpacing: 6,
              mainAxisExtent: (n == 5 ? 112 : 132) * scale,
            ),
            itemBuilder: (context, i) {
              final owner = rewardMap(owners['$i']);
              final selectedCell = cinkoV2
                  ? cinkoCells.contains(i)
                  : target == '$i';
              final ownerName = rewardMap(room['names'])[owner['uid']];
              return Semantics(
                label: '${i + 1}. hücre, ${labels[i]}, ${ownerName ?? 'boş'}',
                selected: selectedCell,
                button: true,
                child: Material(
                  color: selectedCell ? palette.tint : palette.surface,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onLongPress: () => detail(i, ownerName?.toString()),
                    onTap: done || owner.isNotEmpty
                        ? () => detail(i, ownerName?.toString())
                        : () {
                            if (cinkoV2 &&
                                connected &&
                                !busy &&
                                room['turnUid'] == uid)
                              setState(
                                () => cinkoCells.contains(i)
                                    ? cinkoCells.remove(i)
                                    : cinkoCells.add(i),
                              );
                            else if (selectable && connected && !busy)
                              setState(() => target = '$i');
                            else
                              detail(i, ownerName?.toString());
                          },
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            owner.isNotEmpty
                                ? Icons.check_circle_outline
                                : selectedCell
                                ? Icons.radio_button_checked
                                : Icons.crop_square,
                            size: 20,
                            color: owner['uid'] == uid || selectedCell
                                ? accent
                                : palette.muted,
                          ),
                          const SizedBox(height: 4),
                          Flexible(
                            child: Text(
                              labels[i],
                              textAlign: TextAlign.center,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 5,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          if (ownerName != null)
                            Text(
                              '$ownerName',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (boardWidth > constraints.maxWidth)
                note(
                  'Tahtayı yatay kaydır. Tam hücre bilgisi için basılı tut.',
                ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(width: boardWidth, child: grid),
              ),
            ],
          );
        },
      );
  Widget chooser() => panel([
    if (['club_club', 'club_country', 'random_five'].contains(mode))
      ...wrongNotes(),
    if (room['fivePoints'] is List)
      note(
        'Puan: 1 kulüp 1, 2 kulüp 2, 3 kulüp 4, 4 kulüp 6, 5 kulüp 8 puan. '
        'Her futbolcuyu ilk yazan alır.',
      ),
    if (cinkoV2) ...cinkoNotes(),
    if (selected != null) ...[
      PlayerPortrait(
        playerId: int.tryParse('${selected!['id']}') ?? -1,
        size: 64,
        fallback: const Icon(Icons.person, size: 48),
      ),
      note('${selected!['name']}'),
    ],
    TextField(
      controller: query,
      onChanged: typed,
      onSubmitted: (_) => search(),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        labelText: 'Futbolcu ara',
        helperText: 'En az 2 harf yaz; öneriler kendiliğinden gelir.',
        suffixIcon: searching
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            : IconButton(
                tooltip: 'Ara',
                onPressed: !connected ? null : search,
                icon: const Icon(Icons.search),
              ),
      ),
    ),
    if (noMatch && results.isEmpty)
      note('Bu isimle futbolcu bulunamadı. Soyadını ya da kısa adını dene.'),
    ...results.map(
      (p) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text('${p['name']}'),
        subtitle: Text('${p['country']} · ${p['position']}'),
        selected: selected?['id'] == p['id'],
        onTap: () => setState(() {
          selected = p;
          results = [];
          query.text = '${p['name']}';
        }),
      ),
    ),
    button(
      'Cevabı gönder',
      selected == null ||
              room['submitted'] == true ||
              locked > 0 ||
              outOfWrong ||
              ['grid_classic', 'loto'].contains(mode) && target == null ||
              ['grid_classic', 'cinko'].contains(mode) &&
                  room['turnUid'] != uid ||
              cinkoV2 && cinkoCells.isEmpty
          ? null
          : () => action('answer', {
              'playerId': selected!['id'],
              if (cinkoV2) 'cells': cinkoCells.toList()..sort(),
              if (target != null) 'targetId': target,
              if (mode == 'grid_random') 'round': room['round'],
            }),
    ),
    if (room['submitted'] == true)
      note('Cevabın kilitlendi. Rakibinin cevabı tur kapanınca açılır.'),
    if (cinkoV2)
      button(
        'Pas · 0 puan',
        room['turnUid'] != uid ? null : () => action('pass'),
        secondary: true,
      ),
  ]);
  List<Widget> cinkoNotes() {
    final last = rewardMap(room['lastMove']);
    final who = last['uid'] == uid
        ? 'Sen'
        : '${rewardMap(room['names'])[last['uid']] ?? 'Rakip'}';
    return [
      note(
        'Oyuncuyu seç, tahtadan uyduğunu düşündüğün yan yana kutuları işaretle '
        '(çapraz sayılmaz). Doğru kutu +1, yanlış kutu −1. Her oyuncu maçta '
        'bir kez kullanılır.',
      ),
      if (room['secondBonus'] != null)
        note(
          'İlk başlamak avantaj olduğu için ikinci başlayan maça '
          '${room['secondBonus']} puanla başlar. Dört pas üst üste gelirse maç biter.',
        ),
      if (cinkoCells.isNotEmpty) note('Seçilen kutu: ${cinkoCells.length}'),
      if (last.isNotEmpty)
        note(
          last['pass'] == true
              ? '$who: ${last['timeout'] == true ? 'süre doldu' : 'pas'} · 0'
              : '$who: ${rewardMap(last['player'])['name']} · '
                    '${(last['correct'] as List? ?? []).length} doğru, '
                    '${(last['wrong'] as List? ?? []).length} yanlış · '
                    '${(last['points'] as num? ?? 0) > 0 ? '+' : ''}${last['points']}',
        ),
    ];
  }

  // Club Manager formation slots, in pitch order.
  static const managerSlots = {
    '433': {'GK': 1, 'DEF': 4, 'MID': 3, 'ATT': 3},
    '442': {'GK': 1, 'DEF': 4, 'MID': 4, 'ATT': 2},
    '352': {'GK': 1, 'DEF': 3, 'MID': 5, 'ATT': 2},
    '451': {'GK': 1, 'DEF': 4, 'MID': 5, 'ATT': 1},
  };
  static const positionNames = {
    'GK': 'Kaleci',
    'DEF': 'Defans',
    'MID': 'Orta saha',
    'ATT': 'Forvet',
  };

  /// Fills the empty slots with the best-rated players the budget still allows,
  /// keeping enough money for the cheapest players of the slots after them.
  void autoFill(List<Map<String, dynamic>> pool, num budget) {
    final need = Map<String, int>.from(managerSlots[formation]!);
    final chosen = pool.where((p) => xi.contains(p['id'])).toList();
    // Players that no longer fit the formation leave first.
    for (final p in [...chosen]) {
      final pos = '${p['position']}';
      if ((need[pos] ?? 0) > 0) {
        need[pos] = need[pos]! - 1;
      } else {
        chosen.remove(p);
      }
    }
    num spent = chosen.fold<num>(0, (n, p) => n + (p['cost'] as num));
    final open = [
      for (final e in need.entries)
        for (var i = 0; i < e.value; i++) e.key,
    ];
    num cheapest(String pos, Set<Object?> taken, int skip) {
      final costs =
          pool
              .where((p) => p['position'] == pos && !taken.contains(p['id']))
              .map((p) => p['cost'] as num)
              .toList()
            ..sort();
      return costs.length > skip ? costs[skip] : 999;
    }

    final taken = {for (final p in chosen) p['id']};
    for (var i = 0; i < open.length; i++) {
      final pos = open[i];
      // Money the later slots need at the least.
      num reserve(Object? without) {
        final count = <String, int>{};
        num sum = 0;
        for (final later in open.skip(i + 1)) {
          final n = count[later] = (count[later] ?? 0) + 1;
          sum += cheapest(later, {...taken, without}, n - 1);
        }
        return sum;
      }

      final options =
          pool
              .where((p) => p['position'] == pos && !taken.contains(p['id']))
              .toList()
            ..sort(
              (a, b) => (b['rating'] as num).compareTo(a['rating'] as num),
            );
      for (final p in options) {
        if (spent + (p['cost'] as num) + reserve(p['id']) <= budget) {
          taken.add(p['id']);
          chosen.add(p);
          spent += p['cost'] as num;
          break;
        }
      }
    }
    setState(() {
      xi
        ..clear()
        ..addAll(chosen.map((p) => '${p['id']}'));
    });
  }

  Widget play() {
    final criteria = rows(room['criteria']);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mode == 'cinko') ...[
          board(
            5,
            criteria.map((k) => '${k['label']}').toList(),
            selectable: false,
          ),
          const SizedBox(height: 14),
        ] else
          panel([
            for (var i = 0; i < criteria.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.sports_soccer_outlined, color: accent, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        GridCriterionLabel.text(criteria[i]),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                  ],
                ),
              ),
          ]),
        chooser(),
      ],
    );
  }

  Widget outcome() {
    // A draft match plays first; the result card waits for the final whistle.
    if (rewardMap(room['simulation'])['rules'] == 3 &&
        !playbackDone.contains('${room['id']}')) {
      final rival = room['host'] == uid
          ? '${room['guest']}'
          : '${room['host']}';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const ArenaSection('Maç başladı', icon: Icons.stadium_outlined),
          ManagerMatchPlayback(
            key: ValueKey('playback-${room['id']}'),
            simulation: rewardMap(room['simulation']),
            pool: rows(room['pool']),
            uid: uid,
            rival: rival,
            names: rewardMap(room['names']),
            picks: rewardMap(room['picks']),
            onFinished: () {
              final id = '${room['id']}';
              AppFeedback.sfx(
                room['result'] == 'win' ? Sfx.champion : Sfx.whistle,
                eventId: 'pvp:$id:end',
              );
              setState(() => playbackDone.add(id));
            },
          ),
        ],
      );
    }
    final reward = rewardMap(room['reward']);
    final names = rewardMap(room['names']), scores = rewardMap(room['scores']);
    final rival = room['host'] == uid ? '${room['guest']}' : '${room['host']}';
    final won = room['status'] == 'finished' && room['result'] == 'win';
    final set = series;
    final setOver = set.active && set.over;
    final verified = ranked && reward['status'] != 'pending';
    final elo = (reward['eloDelta'] as num? ?? 0).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: HubResultCard(
            tone: (setOver ? set.winner == uid : won)
                ? HubResultTone.win
                : HubResultTone.neutral,
            icon: setOver && set.winner == uid || !setOver && won
                ? Icons.emoji_events_rounded
                : room['status'] == 'finished'
                ? Icons.sports_score_rounded
                : Icons.flag_rounded,
            kicker: ranked
                ? 'Dereceli maç'
                : set.active
                ? 'Üç maçlık seri · ${set.game}. maç'
                : 'Dostluk maçı',
            title: setOver
                ? set.winner == uid
                      ? 'Seriyi kazandın'
                      : set.winner == rival
                      ? 'Seriyi kaybettin'
                      : 'Seri berabere'
                : room['status'] == 'finished'
                ? room['result'] == 'win'
                      ? 'Kazandın'
                      : room['result'] == 'loss'
                      ? 'Maç tamamlandı'
                      : 'Berabere'
                : room['status'] == 'forfeit'
                ? 'Maç hükmen sonuçlandı'
                : 'Maç iptal edildi',
            subtitle:
                '${set.active ? '${set.game}. maç: ' : ''}${names[uid] ?? 'Sen'} ${scores[uid] ?? 0} – ${scores[rival] ?? 0} ${names[rival] ?? 'Rakip'}',
            coins: verified ? (reward['coins'] as num?)?.toInt() : null,
            xp: verified ? (reward['xp'] as num?)?.toInt() : null,
            notes: [
              if ('${room['reason'] ?? ''}'.isNotEmpty) '${room['reason']}',
              if (verified) 'Elo ${elo > 0 ? '+' : ''}$elo',
              if (ranked && !verified) 'Sonuç ve ödül doğrulaması bekleniyor.',
              if (!ranked) 'Dostluk maçı · Elo ve ödül yok',
            ],
          ),
        ),
        if (set.active) ...[
          OnlineSeriesStrip(
            series: set,
            uid: uid,
            rival: rival,
            names: names,
            finishedGame: true,
          ),
          const SizedBox(height: 12),
          if (!setOver) ...[
            ArenaPrimaryButton(
              key: const ValueKey('series-next'),
              label: room['nextRoom'] == null
                  ? 'Sıradaki maç hazırlanıyor'
                  : '${set.game + 1}. maça geç · $seriesJumpSeconds sn',
              icon: Icons.skip_next_rounded,
              onPressed: busy || room['nextRoom'] == null
                  ? null
                  : nextSeriesGame,
            ),
            const SizedBox(height: 16),
          ],
        ],
        ...outcomeRecap(rival),
        const SizedBox(height: 16),
        if (!ranked &&
            !(set.active && !setOver) &&
            ['finished', 'forfeit'].contains(room['status'])) ...[
          ArenaPrimaryButton(
            label: room['nextRoom'] != null
                ? set.active
                      ? 'Yeni seri odasına geç'
                      : 'Rövanş odasına geç'
                : rewardMap(room['rematch'])[uid] == true
                ? 'Rakibinin onayı bekleniyor'
                : set.active
                ? 'Yeni seri iste'
                : 'Rövanş iste',
            icon: Icons.replay_rounded,
            onPressed:
                busy ||
                    room['nextRoom'] == null &&
                        rewardMap(room['rematch'])[uid] == true
                ? null
                : () async {
                    if (room['nextRoom'] != null)
                      await enter('resume');
                    else
                      await action('rematch');
                  },
          ),
          const SizedBox(height: 10),
        ],
        ArenaSecondaryButton(
          label: 'Yeniden oyna',
          icon: Icons.sports_esports_outlined,
          onPressed: () {
            setState(() {
              room = {};
              xi.clear();
              target = null;
              selected = null;
              cinkoCells.clear();
            });
            load();
          },
        ),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextButton.icon(
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Sonucu kopyala'),
              onPressed: () => Clipboard.setData(
                ClipboardData(
                  text:
                      '${widget.mode.title} · ${ranked ? 'Sıralamalı' : 'Arkadaş'}\n'
                      '${rewardMap(room['names']).entries.map((e) => '${e.value}: ${rewardMap(room['scores'])[e.key] ?? 0}').join(' — ')}\nMaç: ${room['id']}',
                ),
              ),
            ),
          ],
        ),
        ExpansionTile(
          title: const Text('Maç bilgisi'),
          children: [
            note(
              '${room['id']} · ${room['dataRevision']} · ${room['ruleVersion']}',
            ),
          ],
        ),
      ],
    );
  }

  /// The match recap under the result card: the final board, who found whom,
  /// or the Club Manager simulation.
  List<Widget> outcomeRecap(String rival) {
    final names = rewardMap(room['names']);
    final text = Theme.of(context).textTheme;
    final sim = rewardMap(room['simulation']);
    final found = rows(room['found']);
    return [
      if (fiveRounds)
        for (final r in rows(room['rounds'])) ...fiveRecap(r, rival),
      if (sim['rules'] == 3) ...managerResult(rival),
      if (sim.isNotEmpty && sim['rules'] != 3) ...[
        const ArenaSection('Maç simülasyonu', icon: Icons.stadium_outlined),
        ArenaCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Gol: ${rewardMap(sim['goals'])[uid] ?? 0} – ${rewardMap(sim['goals'])[rival] ?? 0}',
                textAlign: TextAlign.center,
                style: text.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),
              for (final side in [uid, rival])
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    '${side == uid ? 'Sen' : names[rival] ?? 'Rakip'} · güç '
                    '${(rewardMap(sim['powers'])[side] as num? ?? 0).toStringAsFixed(1)} · xG '
                    '${(rewardMap(sim['xg'])[side] as num? ?? 0).toStringAsFixed(2)}',
                    style: text.bodyMedium?.copyWith(
                      color: side == uid ? Arena.lime : hubAmber(context),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              if (sim['penalties'] != null)
                Text(
                  'Penaltılar: ${rewardMap(sim['penalties'])[uid] ?? 0} – '
                  '${rewardMap(sim['penalties'])[rival] ?? 0}',
                  textAlign: TextAlign.center,
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
            ],
          ),
        ),
      ],
      if (room['squads'] != null)
        ExpansionTile(
          title: const Text('Kilitlenen kadrolar ve taktikler'),
          children: [
            for (final e in rewardMap(room['squads']).entries) ...[
              note('${names[e.key]} · ${rewardMap(e.value)['formation']}'),
              note(
                [
                  for (final id
                      in (rewardMap(e.value)['playerIds'] as List? ?? []))
                    '${rows(room['pool']).where((p) => p['id'] == id).firstOrNull?['name'] ?? id}',
                ].join(', '),
              ),
              note(
                'Pres: ${rewardMap(rewardMap(e.value)['tactics'])['press']} · Tempo: ${rewardMap(rewardMap(e.value)['tactics'])['tempo']} · Genişlik: ${rewardMap(rewardMap(e.value)['tactics'])['width']}',
              ),
            ],
          ],
        ),
      if (mode == 'grid_classic' ||
          mode == 'grid_random' && room['randomBoard'] != null) ...[
        const ArenaSection('Son tahta', icon: Icons.grid_3x3_rounded),
        classicBoard(),
      ],
      if (mode == 'grid_reverse' && room['players'] is List) ...[
        const ArenaSection('Son tahta', icon: Icons.grid_3x3_rounded),
        reverseBoard(),
      ],
      if (lotoCalls && room['criteria'] is List) ...[
        const ArenaSection('Senin kartın', icon: Icons.grid_4x4_rounded),
        lotoCallBoard(rewardMap(room['myCard'])),
        ...lotoCallLines(),
        const SizedBox(height: 12),
        const ArenaSection('Rakibin kartı', icon: Icons.grid_4x4_rounded),
        lotoCallBoard(rewardMap(room['rivalCard'])),
      ] else if (mode == 'loto' && room['criteria'] is List) ...[
        const ArenaSection('Son tahta', icon: Icons.grid_4x4_rounded),
        lotoBoard(),
      ],
      if (cinkoV2 && room['criteria'] is List) ...[
        const ArenaSection('Son tahta', icon: Icons.grid_on_rounded),
        cinkoBoard(),
        ...cinkoMoves(),
      ],
      if (room['found'] is List) ...[
        for (final side in [uid, rival]) ...[
          ArenaSection(
            '${side == uid ? 'Senin buldukların' : '${names[rival] ?? 'Rakip'} buldu'} '
            '(${found.where((p) => p['uid'] == side).length})',
            icon: Icons.people_alt_outlined,
          ),
          if (found.every((p) => p['uid'] != side))
            ArenaNote(
              text: side == uid
                  ? 'Bu maçta isim bulamadın.'
                  : 'Rakip isim bulamadı.',
            ),
          for (final p in found.where((p) => p['uid'] == side))
            ClubRaceFoundTile(
              player: p,
              mine: side == uid,
              points: (p['points'] as num? ?? 1).toInt(),
              detail: p['clubs'] == null ? null : '${p['clubs']} kulüp',
            ),
        ],
      ],
      if (rows(room['missed']).isNotEmpty) ...[
        const SizedBox(height: 4),
        ArenaNote(
          icon: Icons.lightbulb_outline_rounded,
          color: hubAmber(context),
          text:
              'Kimsenin bulamadığı: ${rows(room['missed']).map((p) => p['clubs'] == null ? p['name'] : '${p['name']} (${p['clubs']})').join(' · ')}',
        ),
      ],
      if (room['accepted'] is Map)
        ExpansionTile(
          title: const Text('Her eksenin kabul edilen kriterleri'),
          children: [
            for (final e in rewardMap(room['accepted']).entries)
              ListTile(
                title: Text(axisName(e.key)),
                subtitle: Text(
                  joinOr((e.value as List? ?? const []).map((x) => '$x')),
                ),
              ),
          ],
        ),
      if (room['witness'] != null)
        ExpansionTile(
          title: const Text('Örnek doğru futbolcular'),
          children: rows(
            room['witness'],
          ).map((p) => ListTile(title: Text('${p['name']}'))).toList(),
        ),
      if (room['answers'] is List)
        ExpansionTile(
          title: const Text('Doğrulanmış cevaplar'),
          children: [
            for (final round in room['answers'] as List)
              ...rows(round).map((p) => ListTile(title: Text('${p['name']}'))),
          ],
        ),
    ];
  }

  Future<void> leave() async {
    if (busy) return;
    final yes = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Maçtan ayrıl?'),
        content: Text(
          room['status'] == 'ready' && series.active && series.game > 1
              ? 'Seriden çekilirsen bu maç hükmen rakibine yazılır ve seri biter.'
              : ['waiting', 'ready'].contains(room['status'])
              ? 'Oda veya eşleşme araman iptal edilir.'
              : 'Devam eden maçtan ayrılmak hükmen sonuca yol açar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Ayrıl'),
          ),
        ],
      ),
    );
    if (yes == true) await action('leave');
  }

  bool get gridMode =>
      ['grid_classic', 'grid_random', 'grid_reverse'].contains(mode);
  bool get myTurn => room['turnUid'] == uid;

  /// Grid Random: the drawn pair goes column-first instead of row-first.
  bool swapAxes = false;

  /// The race penalties (lock, wrong cap) belong to Club-Club / Club-Country.
  bool get penaltyMode =>
      clubRace || mode == 'loto' || mode == 'random_five' && !fiveRounds;
  int get raceLock => penaltyMode ? locked : 0;
  bool get raceOut => penaltyMode && outOfWrong;

  /// Why the arena cannot send now; null when a pick may go.
  String? get blockedReason {
    if (fiveRounds) {
      if (room['roundClosed'] == true) return 'Yeni beşli geliyor';
      if (room['myAnswer'] != null)
        return 'Tahminin kilitlendi · rakibini bekle';
      if (seconds(room['roundDeadline']) == 0)
        return 'Bu beşlinin süresi doldu';
      return null;
    }
    if (cinkoV2) {
      if (!myTurn) return 'Rakibin sırası';
      if (cinkoCells.isEmpty) return 'Önce bağlı kutuları seç';
      return null;
    }
    if (mode == 'grid_random') {
      if (!myTurn) return 'Rakibin sırası';
      final anchors = [for (final a in room['anchors'] as List? ?? []) '$a'];
      final taken = rewardMap(room['owners']).containsKey(target);
      if (room['pending'] != null)
        return target == null || taken || !anchors.contains(target)
            ? 'İkiliyi koyacağın çapayı seç'
            : null;
      return target == null || taken || anchors.contains(target)
          ? 'İkili çek ya da açık bir hücre seç'
          : null;
    }
    if (mode == 'grid_classic' || mode == 'grid_reverse') {
      if (!myTurn) return 'Rakibin sırası';
      if (target == null || rewardMap(room['owners']).containsKey(target))
        return mode == 'grid_classic'
            ? 'Önce boş bir hücre seç'
            : 'Önce bir satır ya da sütun seç';
    }
    return null;
  }

  /// Tap-to-send: a suggestion is the answer.
  void pick(Map<String, dynamic> p) {
    if (busy || raceLock > 0 || raceOut || blockedReason != null) return;
    setState(() => selected = p);
    sendPick();
  }

  void sendPick() {
    final p = selected;
    if (p == null || busy || raceLock > 0 || raceOut || blockedReason != null)
      return;
    action('answer', switch (mode) {
      'grid_classic' => {'playerId': p['id'], 'targetId': target},
      'grid_random' => {
        'playerId': p['id'],
        'targetId': target,
        if (room['pending'] != null) 'swap': swapAxes,
      },
      'grid_reverse' => {'targetId': target, 'criterionId': p['id']},
      'cinko' => {'playerId': p['id'], 'cells': cinkoCells.toList()..sort()},
      _ => {'playerId': p['id'], if (fiveRounds) 'round': room['round']},
    });
  }

  void pickTarget(String id) {
    if (!connected || busy || !myTurn) return;
    setState(() {
      target = id;
      feedback = null;
    });
  }

  /// Grid Reverse answers from the club and country list on the device.
  List<Map<String, dynamic>> criterionMatches(String text) {
    final q = _plain(text);
    final hits = [
      for (final k in [...rows(data['clubs']), ...rows(data['countries'])])
        if (_plain('${k['label']}').contains(q)) {...k, 'name': k['label']},
    ];
    hits.sort((a, b) {
      final x = _plain('${a['name']}').startsWith(q) ? 0 : 1;
      final y = _plain('${b['name']}').startsWith(q) ? 0 : 1;
      return x != y ? x - y : '${a['name']}'.compareTo('${b['name']}');
    });
    return hits.take(12).toList();
  }

  String _axisLabel(String a) =>
      '${a.startsWith('r') ? 'Satır' : 'Sütun'} ${int.parse(a.substring(1)) + 1}';

  /// Classic and the Random board: criteria around the board, players in the
  /// cells. On the Random board an axis is open once a pair is put on its
  /// anchor, and crossings nobody can fill any more are locked.
  Widget classicBoard() {
    final owners = rewardMap(room['owners']);
    List<Map<String, dynamic>?> line(String key) => [
      for (final k in room[key] as List? ?? const [])
        k == null ? null : rewardMap(k),
    ];
    final rowsK = line('rows'), colsK = line('cols');
    final anchors = [for (final a in room['anchors'] as List? ?? []) a as int];
    final dead = [for (final d in room['dead'] as List? ?? []) d as int];
    final pending = room['pending'] != null;
    Widget axis(Map<String, dynamic>? k, String name) => ArenaTile(
      compact: true,
      minHeight: 74,
      criterion: ArenaCriterion(k ?? {'label': '$name ?', 'type': 'unknown'}),
    );
    bool known(int i) =>
        rowsK.length > i ~/ 3 &&
        colsK.length > i % 3 &&
        rowsK[i ~/ 3] != null &&
        colsK[i % 3] != null;
    return ArenaGrid(
      top: [
        for (var i = 0; i < 3; i++)
          axis(colsK.elementAtOrNull(i), 'Sütun ${i + 1}'),
      ],
      left: [
        for (var i = 0; i < 3; i++)
          axis(rowsK.elementAtOrNull(i), 'Satır ${i + 1}'),
      ],
      cell: (i) {
        final o = rewardMap(owners['$i']);
        final mine = o['uid'] == uid;
        final anchor = anchors.contains(i);
        final isDead = dead.contains(i);
        final open =
            o.isEmpty &&
            myTurn &&
            connected &&
            !done &&
            (mode != 'grid_random' ||
                (anchor ? pending : !pending && known(i) && !isDead));
        final chosen = target == '$i' && o.isEmpty;
        return ArenaTile(
          key: ValueKey('online-cell-$i'),
          minHeight: 92,
          emptyPlus: open || chosen,
          semantics: known(i)
              ? '${GridCriterionLabel.text(rowsK[i ~/ 3]!)} × ${GridCriterionLabel.text(colsK[i % 3]!)}'
              : anchor
              ? 'Çapa'
              : null,
          player: o.isEmpty ? null : rewardMap(o['player']),
          state: chosen
              ? ArenaTileState.selected
              : o.isEmpty
              ? (open ? ArenaTileState.idle : ArenaTileState.locked)
              : mine
              ? ArenaTileState.mine
              : ArenaTileState.bot,
          tag: chosen
              ? 'SEÇİLİ'
              : o.isEmpty
              ? (anchor
                    ? 'ÇAPA'
                    : isDead
                    ? 'OYUNCU YOK'
                    : null)
              : mine
              ? 'SEN'
              : 'RAKİP',
          onTap: open ? () => pickTarget('$i') : null,
        );
      },
    );
  }

  /// Reverse: the nine players, the six axes around them to name.
  Widget reverseBoard() {
    final owners = rewardMap(room['owners']);
    final players = rows(room['players']);
    Widget axis(String a) {
      final o = rewardMap(owners[a]);
      if (o.isNotEmpty) {
        final k = rewardMap(o['criterion']);
        return ArenaTile(
          compact: true,
          minHeight: 74,
          state: o['uid'] == uid ? ArenaTileState.mine : ArenaTileState.bot,
          tag: o['uid'] == uid ? 'SEN' : 'RAKİP',
          criterion: ArenaCriterion(
            k.isNotEmpty ? k : {'id': o['criterionId'], 'label': '?'},
          ),
        );
      }
      return ArenaTile(
        key: ValueKey('online-axis-$a'),
        compact: true,
        minHeight: 74,
        state: target == a ? ArenaTileState.selected : ArenaTileState.idle,
        tag: target == a ? 'SEÇİLİ' : null,
        criterion: ArenaCriterion({
          'label': '${_axisLabel(a)} ?',
          'type': 'unknown',
        }),
        onTap: myTurn && connected && !done ? () => pickTarget(a) : null,
      );
    }

    return ArenaGrid(
      top: [
        for (final a in ['c0', 'c1', 'c2']) axis(a),
      ],
      left: [
        for (final a in ['r0', 'r1', 'r2']) axis(a),
      ],
      cell: (i) => ArenaTile(
        minHeight: 84,
        player: players.length > i ? players[i] : {'name': '—'},
      ),
    );
  }

  /// "r0" -> "Satır 1", "c2" -> "Sütun 3".
  static String lineName(String key) =>
      '${key.startsWith('r') ? 'Satır' : 'Sütun'} ${(int.tryParse(key.substring(1)) ?? 0) + 1}';

  /// Club Manager: the position whose players the list shows.
  String managerPos = 'GK';

  // Club Manager squad state shared by the arena pieces.
  List<Map<String, dynamic>> get _pool => rows(room['pool']);
  num get _budget => room['budget'] as num? ?? 120;
  num get _spent => _pool
      .where((p) => xi.contains(p['id']))
      .fold<num>(0, (n, p) => n + (p['cost'] as num));
  int _picked(String pos) =>
      _pool.where((p) => p['position'] == pos && xi.contains(p['id'])).length;
  bool get _fits =>
      managerSlots[formation]!.entries.every((e) => _picked(e.key) == e.value);
  bool get _editable => !busy && connected && room['submitted'] != true;

  /// Picks or drops a player; a full position moves the list to the next open one.
  void togglePlayer(Map<String, dynamic> p) {
    if (!_editable) return;
    final id = '${p['id']}';
    final pos = '${p['position']}';
    setState(() {
      if (xi.contains(id)) {
        xi.remove(id);
        return;
      }
      if (_picked(pos) >= (managerSlots[formation]![pos] ?? 0)) return;
      xi.add(id);
      if (_picked(pos) >= (managerSlots[formation]![pos] ?? 0)) {
        managerPos = managerSlots[formation]!.keys.firstWhere(
          (k) => _picked(k) < managerSlots[formation]![k]!,
          orElse: () => pos,
        );
      }
    });
  }

  /// Club Manager: budget and formation, the XI on a pitch, the pool by
  /// position, and the tactic.
  List<Widget> managerArena() {
    final text = Theme.of(context).textTheme;
    final pool = _pool;
    final budget = _budget, spent = _spent;
    final over = spent > budget;
    final slots = managerSlots[formation]!;
    final v2 = room['managerRules'] == 2;
    final chosen = [
      for (final p in pool)
        if (xi.contains(p['id'])) p,
    ];
    Widget slot(Map<String, dynamic>? p, String pos) => SizedBox(
      width: 64,
      child: Column(
        children: [
          if (p != null)
            InkWell(
              customBorder: const CircleBorder(),
              onTap: _editable ? () => togglePlayer(p) : null,
              child: ArenaPlayerAvatar(
                id: p['id'],
                name: '${p['name']}',
                size: 38,
                ring: Arena.lime,
              ),
            )
          else
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: palette.border, width: 1.5),
              ),
              child: Text(
                const {'GK': 'K', 'DEF': 'D', 'MID': 'O', 'ATT': 'F'}[pos]!,
                style: text.labelMedium?.copyWith(color: palette.muted),
              ),
            ),
          const SizedBox(height: 2),
          Text(
            p == null ? positionNames[pos]! : '${p['name']}'.split(' ').last,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: text.labelSmall?.copyWith(
              color: p == null ? palette.muted : palette.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
    final listed = pool.where((p) => p['position'] == managerPos).toList()
      ..sort((a, b) => (b['rating'] as num).compareTo(a['rating'] as num));
    return [
      ArenaCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 8,
              runSpacing: 2,
              children: [
                Text(
                  'Aynı bütçe, senin XI’in',
                  style: text.titleSmall?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(
                  over
                      ? '$spent / $budget · bütçe aşıldı'
                      : '$spent / $budget · kalan ${budget - spent}',
                  style: text.labelLarge?.copyWith(
                    color: over ? palette.error : Arena.lime,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: (spent / budget).clamp(0, 1).toDouble(),
                minHeight: 8,
                color: over ? palette.error : Arena.lime,
                backgroundColor: palette.border,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final f in managerSlots.keys)
                  ChoiceChip(
                    label: Text(f.split('').join('-')),
                    selected: formation == f,
                    onSelected: _editable
                        ? (_) => setState(() => formation = f)
                        : null,
                  ),
              ],
            ),
            if (_editable) ...[
              const SizedBox(height: 8),
              ArenaSecondaryButton(
                label: 'Boşları bütçeye göre doldur',
                icon: Icons.auto_fix_high_rounded,
                onPressed: () => autoFill(pool, budget),
              ),
            ],
          ],
        ),
      ),
      const SizedBox(height: 12),
      // The XI on a pitch, forwards at the top.
      Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: palette.success.withValues(alpha: .07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: palette.success.withValues(alpha: .3)),
        ),
        child: Column(
          children: [
            for (final pos in ['ATT', 'MID', 'DEF', 'GK'])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 2,
                  runSpacing: 4,
                  children: [
                    for (var n = 0; n < (slots[pos] ?? 0); n++)
                      slot(
                        chosen
                            .where((p) => p['position'] == pos)
                            .elementAtOrNull(n),
                        pos,
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
      const ArenaSection('Oyuncu havuzu', icon: Icons.groups_rounded),
      Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final pos in positionNames.keys)
            ChoiceChip(
              label: Text(
                '${positionNames[pos]} ${_picked(pos)}/${slots[pos]}',
              ),
              avatar: Icon(
                _picked(pos) == slots[pos]
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 16,
                color: _picked(pos) == slots[pos]
                    ? palette.success
                    : _picked(pos) > (slots[pos] ?? 0)
                    ? palette.error
                    : palette.muted,
              ),
              selected: managerPos == pos,
              onSelected: (_) => setState(() => managerPos = pos),
            ),
        ],
      ),
      const SizedBox(height: 8),
      for (final p in listed)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Builder(
            builder: (context) {
              final on = xi.contains(p['id']);
              final full = _picked(managerPos) >= (slots[managerPos] ?? 0);
              final star = (p['cost'] as num) >= 14;
              return Material(
                color: on ? palette.limeTint : palette.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: on ? Arena.lime : palette.border,
                    width: on ? 2 : 1,
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: _editable && (on || !full)
                      ? () => togglePlayer(p)
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Row(
                      children: [
                        ArenaPlayerAvatar(
                          id: p['id'],
                          name: '${p['name']}',
                          size: 38,
                          ring: star ? hubAmber(context) : null,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${star ? '★ ' : ''}${p['name']}',
                                style: text.titleSmall?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '${p['rating']} reyting · ${p['cost']} bütçe',
                                style: text.bodySmall?.copyWith(
                                  color: palette.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          on
                              ? Icons.check_circle_rounded
                              : full
                              ? Icons.block_rounded
                              : Icons.add_circle_outline_rounded,
                          color: on
                              ? Arena.lime
                              : full
                              ? palette.muted
                              : palette.accent,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      const ArenaSection('Taktik', icon: Icons.tune_rounded),
      ArenaCard(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              v2
                  ? 'Taktikler döngü gibi: yüksek pres tempoyu, tempo genişliği, '
                        'genişlik presi yener. Her şeyi yükseltmek avantaj getirmez; '
                        'rakibin taktiği maçtan sonra açılır.'
                  : 'Rakibin taktiği maçtan sonra açılır.',
              style: text.bodySmall?.copyWith(color: palette.muted),
            ),
            for (final t in [
              ('Pres', press),
              ('Tempo', tempo),
              ('Genişlik', width),
            ])
              Row(
                children: [
                  SizedBox(
                    width: 72,
                    child: Text(
                      t.$1,
                      style: text.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: t.$2,
                      divisions: 4,
                      label: '${(t.$2 * 100).round()}',
                      onChanged: !_editable
                          ? null
                          : (v) => setState(() {
                              if (t.$1 == 'Pres') {
                                press = v;
                              } else if (t.$1 == 'Tempo') {
                                tempo = v;
                              } else {
                                width = v;
                              }
                            }),
                    ),
                  ),
                  SizedBox(
                    width: 32,
                    child: Text(
                      '${(t.$2 * 100).round()}',
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    ];
  }

  /// Club Manager draft: this side's picks, links and possible formations.
  ({
    List<Map<String, dynamic>> players,
    List<Object?> links,
    Map<String, int>? slots,
    String label,
    int chemistry,
  })
  draftSide(String side) {
    final meta = {for (final p in rows(room['pool'])) '${p['id']}': p};
    final ids = [
      for (final id in rewardMap(room['picks'])[side] as List? ?? const [])
        '$id',
    ];
    final chem = rewardMap(rewardMap(room['chemistry'])[side]);
    final f = rewardMap(room['formations'])[side];
    final open = f is String
        ? [f]
        : [for (final x in f as List? ?? const []) '$x'];
    return (
      players: [
        for (final id in ids)
          if (meta[id] != null) meta[id]!,
      ],
      links: chem['pairs'] as List? ?? const [],
      slots: open.isEmpty ? null : managerFormations[open.first],
      label: f is String
          ? managerFormationLabel(f)
          : open.length == 4
          ? 'Diziliş açık'
          : open.map(managerFormationLabel).join(' / '),
      chemistry: (chem['score'] as num? ?? 0).toInt(),
    );
  }

  /// Links a pool player would bring to this side ("Inter", "Fransa"). Newer
  /// rooms send them from the server: only neighbours on the pitch link.
  List<String> draftLinks(String id, String side) {
    final preview = room['linkPreview'];
    if (side == uid && preview is Map) {
      return [for (final l in preview[id] as List? ?? const []) '$l'];
    }
    final mine = {
      for (final x in rewardMap(room['picks'])[side] as List? ?? const []) '$x',
    };
    return [
      for (final l in room['poolLinks'] as List? ?? const [])
        if (l is List &&
            l.length >= 5 &&
            l[3] != 'league' &&
            ('${l[0]}' == id && mine.contains('${l[1]}') ||
                '${l[1]}' == id && mine.contains('${l[0]}')))
          '${l[4]}'.isEmpty ? 'ülke' : '${l[4]}',
    ];
  }

  List<Widget> managerDraftArena(String rival) {
    final text = Theme.of(context).textTheme;
    final plan = room['phase'] == 'plan';
    final me = draftSide(uid), them = draftSide(rival);
    final picks = rewardMap(room['picks']);
    final owner = <String, String>{
      for (final side in [uid, rival])
        for (final id in picks[side] as List? ?? const [])
          '$id': side == uid ? 'me' : 'rival',
    };
    final legal = {for (final id in room['legal'] as List? ?? const []) '$id'};
    final last = rewardMap(room['lastPick']);
    final lastName = rows(
      room['pool'],
    ).where((p) => '${p['id']}' == '${last['playerId']}').firstOrNull?['name'];
    final anchors = rows(room['anchors']).map((a) => '${a['label']}').toList();
    final pool = [...rows(room['pool'])]
      ..sort((a, b) {
        final ga = owner.containsKey('${a['id']}') ? 1 : 0;
        final gb = owner.containsKey('${b['id']}') ? 1 : 0;
        if (ga != gb) return ga - gb;
        return ((b['rating'] as num? ?? 0) - (a['rating'] as num? ?? 0)).sign
            .toInt();
      });
    final shown = [
      for (final p in pool)
        if (draftFilter == 'ALL' || p['position'] == draftFilter) p,
    ];
    double unit(String pos) {
      final xs = [
        for (final p in me.players)
          if (p['position'] == pos) (p['rating'] as num).toDouble(),
      ];
      return xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
    }

    final team = me.players.isEmpty
        ? 0.0
        : me.players
                  .map((p) => (p['rating'] as num).toDouble())
                  .reduce((a, b) => a + b) /
              me.players.length;
    final captain =
        draftCaptain ??
        '${rewardMap(room['myPlan'])['captain'] ?? ([...me.players]..sort((a, b) => ((b['rating'] as num) - (a['rating'] as num)).sign.toInt())).firstOrNull?['id'] ?? ''}';
    final locked = room['myPlan'] != null;
    return [
      if (!plan)
        ArenaNote(
          icon: myTurn ? Icons.touch_app_rounded : Icons.hourglass_top_rounded,
          color: myTurn ? Arena.lime : null,
          text:
              'Seçim ${(room['pick'] as num? ?? 0).toInt() + 1}/${room['totalPicks'] ?? 22} · '
              '${myTurn ? 'Sıra sende: havuzdan bir futbolcuya dokun, sonra kadroya al.' : 'Rakip seçiyor…'}'
              '${lastName == null ? '' : '\nSon seçim: ${last['uid'] == uid ? 'Sen' : 'Rakip'} · $lastName${last['auto'] == true ? ' (süre doldu, otomatik)' : ''}'}',
        ),
      if (!plan && anchors.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ArenaNote(
            icon: Icons.hub_rounded,
            text:
                'Çapa kulüpler: ${anchors.join(', ')}. Aynı kulüpten ya da ülkeden oyuncuları birlikte almak uyum kazandırır.',
          ),
        ),
      const SizedBox(height: 10),
      ArenaSection(
        'Senin kadron · ${me.label}',
        icon: Icons.sports_soccer_rounded,
        trailing: Text(
          '${me.players.length}/11',
          textAlign: TextAlign.end,
          style: text.labelMedium?.copyWith(
            color: Arena.lime,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      ManagerPitch(
        key: const ValueKey('draft-pitch-me'),
        players: me.players,
        links: me.links,
        slots: me.slots,
        captain: plan ? captain : null,
        highlight: last['uid'] == uid ? '${last['playerId']}' : null,
      ),
      const SizedBox(height: 8),
      ManagerChemistryBar(
        score: me.chemistry,
        detail: '${me.links.length} bağ',
      ),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          'Rakibin kadrosu · ${them.players.length}/11 · uyum ${them.chemistry}',
          style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        children: [
          ManagerPitch(
            players: them.players,
            links: them.links,
            slots: them.slots,
            tone: hubAmber(context),
            height: 240,
            highlight: last['uid'] == rival ? '${last['playerId']}' : null,
          ),
        ],
      ),
      if (!plan) ...[
        ArenaSection(
          'Havuz · ${pool.where((p) => !owner.containsKey('${p['id']}')).length} kaldı',
          icon: Icons.people_alt_outlined,
        ),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final f in ['ALL', 'GK', 'DEF', 'MID', 'ATT'])
              ChoiceChip(
                key: ValueKey('draft-filter-$f'),
                label: Text(f == 'ALL' ? 'Tümü' : managerPositionNames[f]!),
                selected: draftFilter == f,
                onSelected: (_) => setState(() => draftFilter = f),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (final p in shown)
          ManagerPoolTile(
            player: p,
            owner: owner['${p['id']}'],
            legal: !myTurn || legal.contains('${p['id']}'),
            selected: draftPick == '${p['id']}',
            links: draftLinks('${p['id']}', uid),
            onTap: owner.containsKey('${p['id']}') || busy
                ? null
                : () => setState(
                    () => draftPick = draftPick == '${p['id']}'
                        ? null
                        : '${p['id']}',
                  ),
          ),
      ] else ...[
        ArenaSection('Oyun planı', icon: Icons.tune_rounded),
        for (final key in managerPlans.keys)
          ManagerPlanCard(
            plan: key,
            selected: (rewardMap(room['myPlan'])['plan'] ?? draftPlan) == key,
            unitRating: unit(managerPlans[key]!.unit),
            teamRating: team,
            onTap: locked || busy
                ? null
                : () => setState(() => draftPlan = key),
          ),
        ArenaSection('Kaptan · reytingi %10 artar', icon: Icons.star_rounded),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (final p in me.players)
              ChoiceChip(
                key: ValueKey('captain-${p['id']}'),
                label: Text(
                  '${managerShortName(p['name'])} ${(p['rating'] as num).round()}',
                ),
                selected: captain == '${p['id']}',
                onSelected: locked || busy
                    ? null
                    : (_) => setState(() => draftCaptain = '${p['id']}'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ArenaNote(
          icon: room['rivalPlanned'] == true
              ? Icons.lock_rounded
              : Icons.hourglass_top_rounded,
          text: room['rivalPlanned'] == true
              ? 'Rakip planını seçti; ikiniz de kilitleyince maç başlar.'
              : 'Rakip planını seçiyor…',
        ),
      ],
    ];
  }

  /// Draft: pick the selected player; plan: lock plan and captain.
  Widget managerDraftBar() {
    final plan = room['phase'] == 'plan';
    final legal = {for (final id in room['legal'] as List? ?? const []) '$id'};
    final name = rows(
      room['pool'],
    ).where((p) => '${p['id']}' == draftPick).firstOrNull?['name'];
    final me = draftSide(uid);
    final captain =
        draftCaptain ??
        '${([...me.players]..sort((a, b) => ((b['rating'] as num) - (a['rating'] as num)).sign.toInt())).firstOrNull?['id'] ?? ''}';
    final locked = room['myPlan'] != null;
    final (String label, VoidCallback? onPressed) = plan
        ? locked
              ? (
                  room['rivalPlanned'] == true
                      ? 'Plan kilitlendi · maç başlıyor'
                      : 'Plan kilitlendi · rakip bekleniyor',
                  null,
                )
              : draftPlan == null
              ? ('Önce bir oyun planı seç', null)
              : (
                  'Planı kilitle · ${seconds(room['planDeadline'])} sn',
                  busy || !connected
                      ? null
                      : () => action('plan', {
                          'plan': draftPlan,
                          'captain': captain,
                        }),
                )
        : !myTurn
        ? ('Rakip seçiyor · ${seconds(room['turnDeadline'])} sn', null)
        : draftPick == null
        ? (
            'Havuzdan bir futbolcu seç · ${seconds(room['turnDeadline'])} sn',
            null,
          )
        : !legal.contains(draftPick)
        ? ('Bu mevkide yerin dolu; başka mevki seç', null)
        : (
            'Kadroya al: $name',
            busy || !connected
                ? null
                : () => action('pick', {'playerId': draftPick}),
          );
    return Material(
      color: palette.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.border)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: ArenaPrimaryButton(
          key: const ValueKey('draft-action'),
          label: label,
          icon: plan
              ? Icons.lock_outline_rounded
              : Icons.person_add_alt_1_rounded,
          onPressed: onPressed,
        ),
      ),
    );
  }

  /// Club Manager draft result: the match as it happened, then both XIs.
  List<Widget> managerResult(String rival) {
    final sim = rewardMap(room['simulation']);
    final teams = rewardMap(sim['teams']);
    final me = draftSide(uid), them = draftSide(rival);
    return [
      const ArenaSection('Maç', icon: Icons.stadium_outlined),
      ManagerMatchPlayback(
        key: ValueKey('playback-${room['id']}'),
        simulation: sim,
        pool: rows(room['pool']),
        uid: uid,
        rival: rival,
        names: rewardMap(room['names']),
        picks: rewardMap(room['picks']),
        startFinished: true,
      ),
      const SizedBox(height: 12),
      ArenaSection(
        'Senin XI · ${managerFormationLabel(rewardMap(teams[uid])['formation'])}',
        icon: Icons.sports_soccer_rounded,
      ),
      ManagerPitch(
        players: me.players,
        links: me.links,
        slots: me.slots,
        captain: '${rewardMap(teams[uid])['captain']}',
        height: 260,
      ),
      const SizedBox(height: 12),
      ArenaSection(
        'Rakibin XI · ${managerFormationLabel(rewardMap(teams[rival])['formation'])}',
        icon: Icons.sports_soccer_rounded,
      ),
      ManagerPitch(
        players: them.players,
        links: them.links,
        slots: them.slots,
        captain: '${rewardMap(teams[rival])['captain']}',
        tone: hubAmber(context),
        height: 260,
      ),
    ];
  }

  /// Club Manager: the lock button, saying what is still missing.
  Widget managerBar() {
    final locked = room['submitted'] == true;
    final over = _spent > _budget;
    final label = locked
        ? (room['rivalLocked'] == true
              ? 'Kadro kilitlendi · maç başlıyor'
              : 'Kadro kilitlendi · rakip bekleniyor')
        : xi.length != 11
        ? '11 oyuncu seç (${xi.length}/11)'
        : over
        ? 'Bütçe aşıldı (${_spent - _budget} fazla)'
        : !_fits
        ? '${formation.split('').join('-')} dizilişine uymuyor'
        : 'XI ve taktiği kilitle';
    final ready = !locked && xi.length == 11 && !over && _fits && _editable;
    return Material(
      color: palette.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.border)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: ArenaPrimaryButton(
          label: label,
          icon: locked ? Icons.lock_rounded : Icons.lock_outline_rounded,
          onPressed: ready
              ? () => action('squad', {
                  'playerIds': xi.toList(),
                  'formation': formation,
                  'tactics': {'press': press, 'tempo': tempo, 'width': width},
                })
              : null,
        ),
      ),
    );
  }

  /// One answer of a closed five: the player with the clubs it covers, or
  /// a missing guess.
  Widget fiveAnswer(
    Map<String, dynamic> a,
    List<Map<String, dynamic>> clubs, {
    required bool mine,
  }) {
    if (a['id'] == null)
      return ArenaNote(
        icon: Icons.timer_off_outlined,
        text: mine
            ? 'Bu beşlide tahmin yapmadın · 0 puan'
            : 'Rakip bu beşlide tahmin yapmadı · 0 puan',
      );
    final ids = {for (final id in a['clubIds'] as List? ?? const []) '$id'};
    final names = [
      for (final k in clubs)
        if (ids.contains('${k['id']}')) GridCriterionLabel.text(k),
    ];
    return ClubRaceFoundTile(
      player: a,
      mine: mine,
      points: (a['points'] as num? ?? 0).toInt(),
      detail: names.isEmpty
          ? 'Beş kulübün hiçbirine uymadı'
          : '${names.length} kulüp · ${names.join(', ')}',
    );
  }

  /// A closed five: both answers and its best names.
  List<Widget> fiveRecap(Map<String, dynamic> r, String rival) {
    final clubs = rows(r['clubs']);
    final answers = rewardMap(r['answers']);
    final best = rows(r['best']);
    return [
      ArenaSection(
        'Beşli ${(r['round'] as num? ?? 0).toInt() + 1}',
        icon: Icons.casino_outlined,
        trailing: Text(
          clubs.map(GridCriterionLabel.text).join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.end,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: palette.muted),
        ),
      ),
      fiveAnswer(rewardMap(answers[uid]), clubs, mine: true),
      fiveAnswer(rewardMap(answers[rival]), clubs, mine: false),
      if (best.isNotEmpty)
        ArenaNote(
          icon: Icons.lightbulb_outline_rounded,
          color: hubAmber(context),
          text:
              'En iyi cevaplar: ${best.map((p) => '${p['name']} (${p['clubs']} kulüp)').join(' · ')}',
        ),
    ];
  }

  /// Random Five rounds: the fives so far, the current five (a new one spins
  /// in like a slot machine), this five's guesses and the earlier fives.
  List<Widget> fiveRoundsBoard(String rival) {
    final text = Theme.of(context).textTheme;
    final round = (room['round'] as num? ?? 0).toInt();
    final total = (room['totalRounds'] as num? ?? 5).toInt();
    final closed = room['roundClosed'] == true;
    final past = rows(room['rounds']);
    final clubs = rows(room['criteria']);
    final current = closed
        ? past.where((r) => r['round'] == round).firstOrNull
        : null;
    final answers = rewardMap(current?['answers']);
    final mine = closed ? rewardMap(answers[uid]) : rewardMap(room['myAnswer']);
    final theirs = rewardMap(answers[rival]);
    final rivalTone = hubAmber(context);
    final marks = <String, List<Color>>{};
    for (final (a, tone) in [(mine, Arena.lime), (theirs, rivalTone)])
      for (final id in a['clubIds'] as List? ?? const [])
        (marks['$id'] ??= []).add(tone);
    int pointsOf(int n, String side) =>
        (rewardMap(
                  rewardMap(
                    past.where((r) => r['round'] == n).firstOrNull?['answers'],
                  )[side],
                )['points']
                as num?)
            ?.toInt() ??
        0;
    Widget step(int n) {
      final done = past.any((r) => r['round'] == n);
      final now = n == round && !closed;
      return Expanded(
        child: Container(
          margin: EdgeInsets.only(left: n == 0 ? 0 : 6),
          padding: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: now ? palette.limeTint : palette.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: now ? Arena.lime.withValues(alpha: .6) : palette.border,
            ),
          ),
          child: Column(
            children: [
              Text(
                '${n + 1}',
                style: text.labelSmall?.copyWith(color: palette.muted),
              ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  done ? '+${pointsOf(n, uid)} · +${pointsOf(n, rival)}' : '–',
                  style: text.labelMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: done ? palette.text : palette.muted,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return [
      Row(children: [for (var n = 0; n < total; n++) step(n)]),
      const SizedBox(height: 4),
      Text(
        'Kutularda: senin puanın · rakibin puanı',
        textAlign: TextAlign.center,
        style: text.labelSmall?.copyWith(color: palette.muted),
      ),
      ArenaSection(
        'Beşli ${round + 1} / $total',
        icon: Icons.casino_outlined,
        trailing: Text(
          closed
              ? (room['nextRoundAt'] == null
                    ? 'Maç bitiyor'
                    : 'Yeni beşli ${seconds(room['nextRoundAt'])} sn')
              : '${seconds(room['roundDeadline'])} sn',
          textAlign: TextAlign.end,
          style: text.labelMedium?.copyWith(
            color: Arena.lime,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      FiveSlotReel(
        round: round,
        clubs: clubs,
        decoys: [
          ...rows(data['clubs']),
          for (final r in past) ...rows(r['clubs']),
        ],
        marks: marks,
      ),
      const SizedBox(height: 4),
      Text(
        'Puan: 1 kulüp +1 · 2 kulüp +2 · 3 kulüp +4 · 4 kulüp +6 · 5 kulüp +8',
        textAlign: TextAlign.center,
        style: text.labelSmall?.copyWith(color: palette.muted),
      ),
      const SizedBox(height: 8),
      if (closed && current != null)
        ...fiveRecap(current, rival).skip(1)
      else ...[
        if (mine.isEmpty)
          const ArenaNote(
            icon: Icons.bolt_rounded,
            text:
                'Bu beşli için tek tahmin hakkın var: en çok kulübünde oynamış futbolcuyu yaz.',
          )
        else
          fiveAnswer(mine, clubs, mine: true),
        ArenaNote(
          icon: room['rivalAnswered'] == true
              ? Icons.lock_rounded
              : Icons.hourglass_top_rounded,
          text: room['rivalAnswered'] == true
              ? 'Rakip tahminini yaptı; beşli kapanınca açılır.'
              : 'Rakip düşünüyor…',
        ),
      ],
      if (past.any((r) => r['round'] != round)) ...[
        const SizedBox(height: 4),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(
            'Önceki beşliler',
            style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
          ),
          children: [
            for (final r in past.reversed)
              if (r['round'] != round) ...fiveRecap(r, rival),
          ],
        ),
      ],
    ];
  }

  /// Random Five: the points table, the five clubs (names found for each) and
  /// the found players with the clubs they cover.
  List<Widget> fiveBoard() {
    final clubs = rows(room['criteria']);
    final found = rows(room['found']);
    final points = [for (final n in room['fivePoints'] as List? ?? const []) n];
    final labels = {
      for (final k in clubs) '${k['id']}': GridCriterionLabel.text(k),
    };
    final text = Theme.of(context).textTheme;
    int countFor(String id) => found
        .where((f) => (f['clubIds'] as List? ?? const []).contains(id))
        .length;
    return [
      if (points.length > 1)
        Row(
          children: [
            for (var n = 1; n < points.length; n++)
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(left: n == 1 ? 0 : 6),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: n >= 3 ? palette.limeTint : palette.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: n >= 3
                          ? Arena.lime.withValues(alpha: .5)
                          : palette.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          '$n kulüp',
                          style: text.labelSmall?.copyWith(
                            color: palette.muted,
                          ),
                        ),
                      ),
                      Text(
                        '+${points[n]}',
                        style: text.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: n >= 3 ? Arena.lime : palette.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      const ArenaSection('Bu maçın 5 kulübü', icon: Icons.shield_outlined),
      for (final k in clubs)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: ArenaCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                CriterionMark(
                  ArenaCriterion({...k, 'label': labels['${k['id']}']}),
                  size: 30,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${labels['${k['id']}']}',
                    style: text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                ArenaPill(
                  child: Text(
                    countFor('${k['id']}') == 0
                        ? 'Henüz yok'
                        : '${countFor('${k['id']}')} isim',
                  ),
                ),
              ],
            ),
          ),
        ),
      ArenaSection(
        'Bulunanlar (${found.length})',
        icon: Icons.people_alt_outlined,
      ),
      if (found.isEmpty)
        const ArenaNote(
          icon: Icons.bolt_rounded,
          text: 'Henüz kimse bulmadı. Çok kulüpte oynamış bir isimle başla.',
        ),
      for (final f in found.reversed)
        ClubRaceFoundTile(
          player: f,
          mine: f['uid'] == uid,
          points: (f['points'] as num? ?? 1).toInt(),
          detail:
              '${f['clubs'] ?? 1} kulüp · ${(f['clubIds'] as List? ?? const []).map((id) => labels['$id'] ?? '').where((x) => x.isNotEmpty).join(', ')}',
        ),
    ];
  }

  /// Çinko: the 5×5 board; open cells toggle on the player's turn.
  Widget cinkoBoard() {
    final owners = rewardMap(room['owners']);
    final criteria = rows(room['criteria']);
    final open = room['open'] is List
        ? {for (final i in room['open'] as List) (i as num).toInt()}
        : null;
    Widget cell(int i) {
      final o = rewardMap(owners['$i']);
      final mine = o['uid'] == uid;
      final k = i < criteria.length ? criteria[i] : <String, dynamic>{};
      final closed = o.isEmpty && open != null && !open.contains(i);
      final picked = cinkoCells.contains(i);
      final canTap =
          o.isEmpty && !closed && myTurn && connected && !busy && !done;
      return ArenaTile(
        key: ValueKey('online-cell-$i'),
        compact: true,
        minHeight: 76,
        criterion: ArenaCriterion({...k, 'label': GridCriterionLabel.text(k)}),
        player: o.isEmpty ? null : rewardMap(o['player']),
        state: picked
            ? ArenaTileState.selected
            : o.isNotEmpty
            ? (mine ? ArenaTileState.mine : ArenaTileState.bot)
            : closed || !myTurn
            ? ArenaTileState.locked
            : ArenaTileState.idle,
        tag: picked
            ? 'SEÇİLİ'
            : o.isNotEmpty
            ? (mine ? 'SEN' : 'RAKİP')
            : closed
            ? 'KAPALI'
            : null,
        onTap: canTap
            ? () => setState(
                () => picked ? cinkoCells.remove(i) : cinkoCells.add(i),
              )
            : null,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Large type gets wider cells and a sideways scroll instead of cramped names.
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        final narrow = constraints.maxWidth / 5 < 62 * scale;
        final width = narrow ? 5 * 66.0 * scale : constraints.maxWidth;
        final grid = SizedBox(
          width: width,
          child: Column(
            children: [
              for (var row = 0; row < 5; row++)
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var col = 0; col < 5; col++)
                        Expanded(child: cell(row * 5 + col)),
                    ],
                  ),
                ),
            ],
          ),
        );
        return narrow
            ? SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: grid,
              )
            : grid;
      },
    );
  }

  /// Çinko: the last moves of both players, newest first.
  List<Widget> cinkoMoves() {
    final moves = rows(room['moves']);
    if (moves.isEmpty) return const [];
    return [
      const ArenaSection('Son hamleler', icon: Icons.history_rounded),
      for (final m in moves)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(
                m['pass'] == true
                    ? Icons.redo_rounded
                    : (m['points'] as num? ?? 0) > 0
                    ? Icons.add_circle_outline_rounded
                    : Icons.remove_circle_outline_rounded,
                size: 18,
                color: m['uid'] == uid ? palette.accent : hubAmber(context),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${m['uid'] == uid ? 'Sen' : 'Rakip'} · '
                  '${m['pass'] == true ? (m['timeout'] == true ? 'süre doldu · pas' : 'pas') : '${rewardMap(m['player'])['name']} · ${(m['correct'] as List? ?? []).length} doğru, ${(m['wrong'] as List? ?? []).length} yanlış · ${(m['points'] as num? ?? 0) > 0 ? '+' : ''}${m['points'] ?? 0}'}',
                ),
              ),
            ],
          ),
        ),
    ];
  }

  /// Loto calls: the called player, what to do, and how the last call went.
  Widget lotoCallCard() {
    final text = Theme.of(context).textTheme;
    final p = rewardMap(room['callPlayer']);
    final call = (room['call'] as num? ?? 0).toInt();
    final closed = room['callClosed'] == true;
    final move = rewardMap(room['myMove']);
    final last = rewardMap(room['lastCall']);
    String result(Object? raw) {
      final x = rewardMap(raw);
      if (x['pass'] == true) return 'pas';
      if (x['timeout'] == true) return 'süre doldu';
      if (x['correct'] != true) return 'yanlış kutu';
      final lines = (x['lines'] as List? ?? const []).length;
      return 'doğru +1${lines == 0 ? '' : ' · çizgi +${lines * ((room['lineBonus'] as num? ?? 2).toInt())}'}';
    }

    return ArenaCard(
      glow: Arena.lime,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              ArenaPill(
                child: Text('${call + 1} / ${room['totalCalls'] ?? 16} OYUNCU'),
              ),
              ArenaPill(
                child: Text('Rakip ${room['rivalPlaced'] ?? 0}/16 kutu'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (p.isNotEmpty)
            Row(
              children: [
                ArenaPlayerAvatar(id: p['id'], name: '${p['name']}', size: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p['name']}',
                        key: const ValueKey('online-loto-call'),
                        style: text.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        closed
                            ? 'Çekiliş kapandı · sıradaki futbolcu geliyor'
                            : move['pass'] == true
                            ? 'Pas geçtin · rakip bekleniyor'
                            : move.isNotEmpty
                            ? 'Kartına koydun · rakip bekleniyor'
                            : 'Kartında uyduğu boş kutuya dokun ya da pas geç.',
                        style: text.bodyMedium?.copyWith(color: palette.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          if (last.isNotEmpty) ...[
            const SizedBox(height: 12),
            ArenaNote(
              icon: Icons.history_rounded,
              text:
                  'Son çekiliş · ${rewardMap(last['player'])['name'] ?? ''}: '
                  'Sen ${result(last['mine'])} · Rakip ${result(last['rival'])}',
            ),
          ],
        ],
      ),
    );
  }

  /// Loto calls: a side's own card; the viewer's live card takes the called player.
  Widget lotoCallBoard(Map<String, dynamic> card, {bool interactive = false}) {
    final criteria = rows(room['criteria']);
    final pending = rewardMap(room['myMove'])['cell'];
    final can =
        interactive &&
        !done &&
        connected &&
        !busy &&
        room['callClosed'] != true &&
        room['myMove'] == null &&
        room['callPlayer'] != null;
    Widget cell(int i) {
      final o = rewardMap(card['$i']);
      final k = i < criteria.length ? criteria[i] : <String, dynamic>{};
      final waiting = interactive && o.isEmpty && '$pending' == '$i';
      return ArenaTile(
        key: ValueKey('online-cell-$i'),
        compact: true,
        minHeight: 84,
        criterion: ArenaCriterion({...k, 'label': GridCriterionLabel.text(k)}),
        player: o.isNotEmpty
            ? rewardMap(o['player'])
            : waiting
            ? rewardMap(room['callPlayer'])
            : null,
        state: o.isEmpty
            ? (waiting ? ArenaTileState.selected : ArenaTileState.idle)
            : o['correct'] == true
            ? ArenaTileState.correct
            : ArenaTileState.wrong,
        tag: o.isEmpty
            ? (waiting ? 'BEKLİYOR' : null)
            : o['correct'] == true
            ? 'DOĞRU'
            : 'YANLIŞ',
        onTap: o.isEmpty && can
            ? () => action('answer', {'targetId': '$i', 'round': room['call']})
            : null,
      );
    }

    return Column(
      children: [
        for (var row = 0; row < 4; row++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var col = 0; col < 4; col++)
                  Expanded(child: cell(row * 4 + col)),
              ],
            ),
          ),
      ],
    );
  }

  /// Loto calls: the rows and columns each side completed with right cells.
  List<Widget> lotoCallLines() {
    final lines = rewardMap(room['lotoLines']);
    final pills = [
      for (final side in [uid, rivalUid])
        for (final key in lines[side] as List? ?? const [])
          ArenaPill(
            color: side == uid ? palette.accent : hubAmber(context),
            child: Text(
              '${lineName('$key')} · ${side == uid ? 'Sen' : 'Rakip'} +${room['lineBonus'] ?? 2}',
            ),
          ),
    ];
    if (pills.isEmpty) return const [];
    return [
      const SizedBox(height: 10),
      Wrap(spacing: 6, runSpacing: 6, children: pills),
    ];
  }

  /// Loto calls: what to do with the called player, pinned above the system bar.
  Widget lotoCallBar() {
    final text = Theme.of(context).textTheme;
    final closed = room['callClosed'] == true;
    final moved = room['myMove'] != null;
    final name = rewardMap(room['callPlayer'])['name'];
    final (String label, Color tone) = closed
        ? ('Çekiliş kapandı · sıradaki futbolcu geliyor', palette.muted)
        : moved
        ? ('Hamlen kaydedildi · rakip bekleniyor', palette.muted)
        : ('${name ?? 'Futbolcu'} · kartında uyduğu kutuya dokun', Arena.lime);
    return Material(
      color: palette.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.border)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              liveRegion: true,
              child: Text(
                label,
                style: text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: tone,
                ),
              ),
            ),
            if (!closed && !moved) ...[
              const SizedBox(height: 8),
              ArenaSecondaryButton(
                key: const ValueKey('online-loto-pass'),
                label: 'Pas geç',
                icon: Icons.redo_rounded,
                onPressed: busy || !connected
                    ? null
                    : () => action('pass', {'round': room['call']}),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Loto: place the picked player on the cell it fits; first come, first served.
  void lotoPlace(int i) {
    final p = selected;
    if (p == null || busy || raceLock > 0 || raceOut || !connected) return;
    if (rewardMap(room['owners']).containsKey('$i')) return;
    action('answer', {'playerId': p['id'], 'targetId': '$i'});
  }

  /// Loto: the players still to place, as a sideways strip in the bar.
  Widget lotoPlayers() {
    final used = rewardMap(room['used']);
    final text = Theme.of(context).textTheme;
    final left = [
      for (final p in rows(room['players']))
        if (!used.containsKey('${p['id']}')) p,
    ];
    return SizedBox(
      height: 44 * MediaQuery.textScalerOf(context).scale(14) / 14,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: left.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, n) {
          final p = left[n];
          final picked = selected?['id'] == p['id'];
          return Material(
            key: ValueKey('online-loto-player-${p['id']}'),
            color: picked ? palette.limeTint : palette.background,
            shape: StadiumBorder(
              side: BorderSide(
                color: picked ? Arena.lime : palette.border,
                width: picked ? 2 : 1,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: busy
                  ? null
                  : () => setState(() {
                      selected = picked ? null : p;
                      feedback = null;
                    }),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 12, 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ArenaPlayerAvatar(
                      id: p['id'],
                      name: '${p['name']}',
                      size: 28,
                      ring: picked ? Arena.lime : null,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${p['name']}',
                      style: text.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: picked ? Arena.lime : palette.text,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Loto: the 4×4 board of clubs, countries and leagues.
  Widget lotoBoard() {
    final owners = rewardMap(room['owners']);
    final criteria = rows(room['criteria']);
    final canPlace =
        selected != null &&
        raceLock == 0 &&
        !raceOut &&
        connected &&
        !busy &&
        !done;
    Widget cell(int i) {
      final o = rewardMap(owners['$i']);
      final mine = o['uid'] == uid;
      final k = i < criteria.length ? criteria[i] : <String, dynamic>{};
      return ArenaTile(
        key: ValueKey('online-cell-$i'),
        compact: true,
        minHeight: 84,
        criterion: ArenaCriterion({...k, 'label': GridCriterionLabel.text(k)}),
        player: o.isEmpty ? null : rewardMap(o['player']),
        state: o.isEmpty
            ? ArenaTileState.idle
            : mine
            ? ArenaTileState.mine
            : ArenaTileState.bot,
        tag: o.isEmpty
            ? null
            : mine
            ? 'SEN'
            : 'RAKİP',
        onTap: o.isEmpty && canPlace ? () => lotoPlace(i) : null,
      );
    }

    return Column(
      children: [
        for (var row = 0; row < 4; row++)
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var col = 0; col < 4; col++)
                  Expanded(child: cell(row * 4 + col)),
              ],
            ),
          ),
      ],
    );
  }

  /// Loto: what to do next, pinned above the system bar.
  Widget lotoBar() {
    final text = Theme.of(context).textTheme;
    final p = selected;
    final (String label, IconData icon, Color tone) = raceOut
        ? (
            'Yanlış hakkın doldu; yeni hamle yok',
            Icons.block_rounded,
            palette.error,
          )
        : raceLock > 0
        ? ('$raceLock sn bekle', Icons.hourglass_top_rounded, hubAmber(context))
        : p == null
        ? ('Önce bir futbolcu seç', Icons.touch_app_outlined, palette.muted)
        : (
            '${p['name']} · uyduğu boş hücreye dokun',
            Icons.grid_view_rounded,
            Arena.lime,
          );
    return Material(
      color: palette.surface,
      child: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: palette.border)),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!raceOut) ...[lotoPlayers(), const SizedBox(height: 10)],
            Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  if (p != null && raceLock == 0 && !raceOut) ...[
                    ArenaPlayerAvatar(
                      id: p['id'],
                      name: '${p['name']}',
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                  ] else ...[
                    Icon(icon, color: tone),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: Text(
                      label,
                      style: text.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: tone,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Random board: the drawn pair (or the draw button) above the board.
  List<Widget> randomPair() {
    final pair = rows(rewardMap(room['pending'])['criteria']);
    final freeAnchor = [
      for (final a in room['anchors'] as List? ?? const [])
        if (!rewardMap(room['owners']).containsKey('$a')) a,
    ].isNotEmpty;
    if (pair.length == 2) {
      final a = '${pair[0]['label']}', b = '${pair[1]['label']}';
      return [
        ClubRaceVersus(
          left: pair[0],
          right: pair[1],
          answerCount: null,
          task: myTurn
              ? 'Ortak futbolcuyu yaz ve boş bir çapaya yerleştir.'
              : 'Rakip bu ikiliyi oynuyor.',
          footnote: myTurn
              ? (swapAxes
                    ? '$b satır, $a sütun başlığı olur.'
                    : '$a satır, $b sütun başlığı olur.')
              : 'Doğru bilirse çapa onun olur; ikili satır ve sütun başlığına yerleşir.',
        ),
        if (myTurn)
          SwitchListTile(
            key: const ValueKey('online-swap'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Satır ↔ sütun yönünü çevir'),
            value: swapAxes,
            onChanged: busy ? null : (v) => setState(() => swapAxes = v),
          ),
        const SizedBox(height: 12),
      ];
    }
    if (!myTurn || !freeAnchor) return const [];
    return [
      ArenaPrimaryButton(
        label: 'Rastgele ikili çek',
        icon: Icons.casino_outlined,
        onPressed: busy || !connected ? null : () => action('draw'),
      ),
      const SizedBox(height: 12),
    ];
  }

  String? modeRules() => switch (mode) {
    'grid_classic' =>
      'Sırayla oynanır: boş bir hücre seç, satır ve sütuna uyan futbolcuyu yaz. '
          'Her hamleden sonra sıra rakibe geçer. Aynı çizgide (yatay, dikey ya da '
          'çapraz) 3 hücre alan kazanır; tahta dolarsa çok hücre alan, eşitlikte az yanlış yapan.',
    'grid_random' =>
      'Sırayla oynanır: sıran gelince rastgele kulüp ikilisi çek, ortak futbolcuyu yaz ve '
          'boş bir çapaya yerleştir; ikili o satırın ve sütunun başlığı olur. Ya da '
          'başlıkları açılmış boş bir hücreyi doldur. Her hamleden sonra sıra rakibe geçer; '
          'yanlış cevapta ya da süre dolunca çekilen ikili düşer. Aynı çizgide 3 hücre alan '
          'kazanır; üç çapa da bir çizgidir.',
    'grid_reverse' =>
      'Sırayla oynanır: bir satır ya da sütun seç, üç futbolcunun ortak kulübünü '
          'ya da milli takımını yaz. Her hamleden sonra sıra rakibe geçer; 4 ekseni ilk alan kazanır.',
    'club_manager' when draftMode =>
      'Draft: 36 kişilik havuzdan sırayla futbolcu seçersiniz (1-2-2-1 yılan sırası, '
          'seçim başına 15 sn; süre dolarsa en iyi uygun oyuncu seçilir). Senin aldığını rakip '
          'alamaz. Diziliş seçimlerinden çıkar: 4-3-3, 4-4-2, 3-5-2 ya da 4-5-1. Aynı kulüpte '
          'ya da milli takımda oynamış oyuncular uyum kazandırır (sahadaki çizgiler); çapa '
          'kulüplerin oyuncularını birlikte almak güçlüdür. Sonra 25 sn içinde gizli oyun '
          'planını ve kaptanını seç: Hücum Topa sahip olmayı, Topa sahip olma Kontrayı, Kontra '
          'Hücumu yener; kaptanın reytingi %10 artar. Maç dakika dakika oynanır; berabere '
          'biterse penaltılar.',
    'club_manager' =>
      'İkiniz aynı havuzdan, aynı bütçeyle 11 kişilik kadro kurarsınız. Yıldızlar (★) '
          'bütçenin tamamına sığmaz; kimin için harcayacağını seç. İki taraf da kilitleyince '
          'maç oynanır; süre dolduğunda yalnız sen kilitlediysen hükmen kazanırsın. Kadro '
          'bütçesi oyun içindir, Coin harcanmaz.',
    'random_five' when fiveRounds =>
      'Her turda yeni bir beşli gelir; ikiniz aynı anda, beşli başına tek tahmin yaparsınız. '
          'Beş kulüpten en çoğunda oynamış futbolcuyu yaz: 1 kulüp +1, 2 kulüp +2, 3 kulüp +4, '
          '4 kulüp +6, 5 kulüp +8 puan; hiçbirine uymazsa 0. Tahminler beşli kapanınca açılır '
          '(ikiniz de yazınca ya da ${((room['answerMs'] as num? ?? 25000) / 1000).round()} sn dolunca). '
          'Bir futbolcuyu maçta bir kez yazabilirsin. ${room['totalRounds'] ?? 5} beşlinin sonunda '
          'çok puan alan kazanır; eşitlikte daha çok beşlide puan alan, o da eşitse daha hızlı cevaplayan.',
    'random_five' =>
      'İkiniz aynı anda oynarsınız: bu beş kulüpten en çoğunda oynamış futbolcuları yaz. '
          'Her ismi ilk yazan alır; kaç kulübe uyarsa o kadar değerlidir (tablo yukarıda). '
          'Hiçbir kulübe uymayan isim 2 sn kilitler; maçta en fazla ${room['maxWrong'] ?? 10} yanlış hakkın var. '
          'Süre bitince çok puan alan kazanır.',
    'cinko' =>
      'Sırayla oynanır: yan yana ya da üst üste bağlı açık kutuları seç (çapraz sayılmaz), '
          'sonra bir futbolcu yaz. Doğru kutu +1, yanlış kutu −1; uyan kutular senin olur, '
          'uymayanlar açık kalır. Her futbolcu maçta bir kez kullanılır. '
          '${room['secondBonus'] == null ? '' : 'İlk başlamak avantaj olduğu için ikinci başlayan maça ${room['secondBonus']} puanla başlar. '}'
          'Dört pas üst üste gelirse ya da açık kutu kalmazsa maç biter; çok puan alan kazanır.',
    'loto' when lotoCalls =>
      'Bot maçındaki gibi: ikinizin de kendi kartı var, tahtanın 16 futbolcusu aynı sırayla tek tek gelir. '
          'Her futbolcu için ${((room['callMs'] as num? ?? 15000) / 1000).round()} sn: kartında uyduğu boş kutuya koy ya da pas geç. '
          'İkiniz de oynayınca çekiliş kapanır ve iki sonuç da açılır: doğru kutu +1, kartında tamamen doğru '
          'bir satır ya da sütun +${room['lineBonus'] ?? 2}. Yanlış kutu dolu kalır. Eşitlikte az yanlış, '
          'o da eşitse doğruları daha hızlı veren kazanır.',
    'loto' =>
      'Alttaki şeritten futbolcuyu seç, sonra uyduğu boş hücreye dokun: kulüp, milli takım ya da lig. '
          'İki oyuncu aynı anda oynar; hücreyi ilk dolduran alır. Yanlış hamle 3 sn kilitler, '
          'maçta en fazla ${room['maxWrong'] ?? 8} yanlış hakkın var. Her futbolcunun tek bir doğru '
          'yerleşimle tahtayı tamamlayan yeri var; kalanlar boş hücrelere uymazsa maç biter.'
          '${room['lineBonus'] == null ? '' : ' Bingo: bir satırın ya da sütunun son boş hücresini dolduran +${room['lineBonus']} puan alır (ikisini birden tamamlarsa iki kez).'}',
    'club_club' =>
      'İkiniz aynı anda oynarsınız: iki kulüpte de oynamış futbolcuları yaz. Her ismi ilk '
          'yazan +1 alır; yanlış isim 2 sn kilitler, maçta en fazla 10 yanlış hakkın var. '
          'Bütün ortak futbolcular bulununca ya da süre bitince çok puan alan kazanır.',
    'club_country' =>
      'İkiniz aynı anda oynarsınız: kulüpte oynamış ve o ülkenin vatandaşı futbolcuları yaz. '
          'Her ismi ilk yazan +1 alır; yanlış isim 2 sn kilitler, maçta en fazla 10 yanlış '
          'hakkın var. Bütün ortak futbolcular bulununca ya da süre bitince çok puan alan kazanır.',
    _ => null,
  };

  /// Live arena for Club-Club, Club-Country and the three online Grids:
  /// score and clock, the board or pair, and an input bar over the keyboard.
  Widget liveArena() {
    final names = rewardMap(room['names']), scores = rewardMap(room['scores']);
    final wrong = rewardMap(
      room[gridMode
          ? 'gridWrong'
          : lotoCalls
          ? 'wrongCells'
          : 'wrongMoves'],
    );
    final rival = uid == '${room['host']}'
        ? '${room['guest']}'
        : '${room['host']}';
    final criteria = rows(room['criteria']);
    final found = rows(room['found']);
    final count = (room['answerCount'] as num?)?.toInt();
    final countdown = room['status'] == 'countdown';
    final turnBased = gridMode || cinkoV2;
    final (clockKey, total) = switch (mode) {
      'club_manager' when draftMode && room['phase'] == 'plan' => (
        'planDeadline',
        25,
      ),
      'club_manager' when draftMode => (
        'turnDeadline',
        room['pick'] == 0 ? 20 : 15,
      ),
      'random_five' when fiveRounds && room['roundClosed'] == true => (
        'nextRoundAt',
        ((room['revealMs'] as num? ?? 4000) / 1000).round(),
      ),
      'random_five' when fiveRounds => (
        'roundDeadline',
        ((room['answerMs'] as num? ?? 25000) / 1000).round(),
      ),
      'loto' when lotoCalls && room['callClosed'] == true => ('nextCallAt', 2),
      'loto' when lotoCalls => (
        'callDeadline',
        ((room['callMs'] as num? ?? 15000) / 1000).round(),
      ),
      'grid_classic' ||
      'grid_reverse' ||
      'grid_random' ||
      'cinko' => ('turnDeadline', 45),
      _ => (
        'endsAt',
        (((room['endsAt'] as num? ?? 0) - (room['startsAt'] as num? ?? 0)) /
                1000)
            .round(),
      ),
    };
    final manager = mode == 'club_manager';
    ClubRaceSide side(String id, String fallback) => ClubRaceSide(
      name: '${names[id] ?? fallback}',
      score: (scores[id] as num? ?? 0).toInt(),
      wrong: (wrong[id] as num? ?? 0).toInt(),
      caption: draftMode
          ? 'Uyum ${rewardMap(rewardMap(room['chemistry'])[id])['score'] ?? 0}'
          : fiveRounds
          ? (room['roundClosed'] == true
                ? 'Beşli açıldı'
                : (id == uid
                      ? room['myAnswer'] != null
                      : room['rivalAnswered'] == true)
                ? 'Tahmin yaptı'
                : 'Düşünüyor')
          : lotoCalls
          ? (room['callClosed'] == true
                ? 'Yanlış kutu ${(wrong[id] as num? ?? 0).toInt()}'
                : (id == uid
                      ? room['myMove'] != null
                      : room['rivalMoved'] == true)
                ? 'Oynadı'
                : 'Düşünüyor')
          : cinkoV2
          ? 'Kutu ${rewardMap(room['owners']).values.where((o) => rewardMap(o)['uid'] == id).length}'
                '${room['secondBonusUid'] == id ? ' · +${room['secondBonus'] ?? 1} ikinci başlama' : ''}'
          : manager
          ? ((id == uid
                    ? room['submitted'] == true
                    : room['rivalLocked'] == true)
                ? 'Kilitledi'
                : 'Kuruyor')
          : null,
      display: !manager
          ? null
          : draftMode
          ? '${(rewardMap(room['picks'])[id] as List? ?? const []).length}/11'
          : id == uid
          ? '${xi.length}/11'
          : room['rivalLocked'] == true
          ? '✓'
          : '…',
    );
    final rules = modeRules();
    return Column(
      children: [
        ArenaHeader(
          title: widget.mode.title,
          subtitle: ranked
              ? 'Rastgele eşleşme'
              : series.active
              ? 'Seri ${series.game}. maç · Sen ${series.winsOf(uid)} – ${series.winsOf(rivalUid)}'
              : 'Arkadaş maçı · Oda ${room['id'] ?? ''}',
          tag: 'CANLI 1v1',
          actions: [
            ArenaIconButton(
              tooltip: 'Yenile',
              icon: Icons.refresh_rounded,
              onPressed: busy || accountChanged ? null : () => action('poll'),
            ),
          ],
        ),
        Divider(height: 1, color: palette.border),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            children: [
              if (error != null)
                GameErrorPanel(
                  message: error!,
                  accountChanged: accountChanged,
                  onRetry: busy || accountChanged ? null : () => action('poll'),
                ),
              if (feedback != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Semantics(
                    liveRegion: true,
                    child: ArenaNote(
                      text: feedback!,
                      icon: feedback!.startsWith('Doğru')
                          ? Icons.check_circle_rounded
                          : Icons.info_outline_rounded,
                      color: feedback!.startsWith('Doğru')
                          ? palette.success
                          : null,
                    ),
                  ),
                ),
              ClubRaceScoreCard(
                me: side(uid, 'Sen'),
                rival: side(rival, 'Rakip'),
                maxWrong:
                    gridMode || cinkoV2 || manager || fiveRounds || lotoCalls
                    ? null
                    : (room['maxWrong'] as num? ?? 10).toInt(),
                secondsLeft: seconds(room[clockKey]),
                totalSeconds: total,
                countdown: countdown ? seconds(room['startsAt']) : null,
                status: countdown
                    ? null
                    : turnBased
                    ? (myTurn ? 'SIRA SENDE' : 'RAKİPTE')
                    : draftMode
                    ? (room['phase'] == 'plan'
                          ? (room['myPlan'] != null ? 'BEKLENİYOR' : 'PLAN SEÇ')
                          : myTurn
                          ? 'SIRA SENDE'
                          : 'RAKİP SEÇİYOR')
                    : manager
                    ? (room['submitted'] == true ? 'KİLİTLENDİ' : 'KADRO KUR')
                    : fiveRounds
                    ? (room['roundClosed'] == true
                          ? (room['nextRoundAt'] == null
                                ? 'SON BEŞLİ'
                                : 'YENİ BEŞLİ')
                          : room['myAnswer'] != null
                          ? 'BEKLENİYOR'
                          : 'BEŞLİ ${(room['round'] as num? ?? 0).toInt() + 1}/${room['totalRounds'] ?? 5}')
                    : lotoCalls
                    ? (room['callClosed'] == true
                          ? (room['nextCallAt'] == null
                                ? 'SON OYUNCU'
                                : 'SIRADAKİ')
                          : room['myMove'] != null
                          ? 'BEKLENİYOR'
                          : 'OYUNCU ${(room['call'] as num? ?? 0).toInt() + 1}/${room['totalCalls'] ?? 16}')
                    : null,
                myTurn: turnBased || draftMode && room['phase'] == 'draft'
                    ? myTurn
                    : null,
              ),
              if (!connected)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: ArenaNote(
                    icon: Icons.wifi_off_rounded,
                    color: palette.error,
                    text:
                        'Bağlantı kesildi. Sunucudaki süre devam eder; yenile ile maçını kontrol et.',
                  ),
                )
              else if (linkMisses > 0)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: ArenaNote(
                    icon: Icons.network_check_rounded,
                    text: weakLinkText,
                  ),
                ),
              const SizedBox(height: 12),
              if (countdown)
                const ArenaNote(
                  icon: Icons.timer_outlined,
                  text: 'Hazır ol: ikiniz aynı anda başlayacaksınız.',
                )
              else if (mode == 'grid_classic')
                classicBoard()
              else if (mode == 'grid_reverse')
                reverseBoard()
              else if (mode == 'grid_random') ...[
                ...randomPair(),
                classicBoard(),
              ] else if (draftMode) ...[
                ...managerDraftArena(rival),
              ] else if (manager) ...[
                ...managerArena(),
              ] else if (fiveRounds) ...[
                ...fiveRoundsBoard(rival),
              ] else if (mode == 'random_five') ...[
                ...fiveBoard(),
              ] else if (cinkoV2) ...[
                cinkoBoard(),
                const SizedBox(height: 8),
                if (myTurn) ...[
                  Text(
                    cinkoCells.isEmpty
                        ? 'Bağlı kutulara dokun, sonra futbolcuyu yaz.'
                        : '${cinkoCells.length} kutu seçili · doğrular +1, yanlışlar −1',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: cinkoCells.isEmpty ? palette.muted : Arena.lime,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ArenaSecondaryButton(
                    label: 'Pas geç',
                    icon: Icons.redo_rounded,
                    onPressed: busy || !connected ? null : () => action('pass'),
                  ),
                ],
                ...cinkoMoves(),
              ] else if (lotoCalls) ...[
                lotoCallCard(),
                const SizedBox(height: 12),
                ArenaSection(
                  'Senin kartın · ${rewardMap(room['myCard']).length}/16',
                  icon: Icons.grid_4x4_rounded,
                ),
                lotoCallBoard(rewardMap(room['myCard']), interactive: true),
                ...lotoCallLines(),
              ] else if (mode == 'loto') ...[
                ArenaSection(
                  'Loto tahtası · ${rewardMap(room['owners']).length}/16',
                  icon: Icons.grid_4x4_rounded,
                ),
                lotoBoard(),
                if (rewardMap(room['lotoLines']).isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final e in rewardMap(room['lotoLines']).entries)
                        ArenaPill(
                          color: e.value == uid
                              ? palette.accent
                              : hubAmber(context),
                          child: Text(
                            '${lineName(e.key)} · ${e.value == uid ? 'Sen' : 'Rakip'} +${room['lineBonus'] ?? 2}',
                          ),
                        ),
                    ],
                  ),
                ],
              ] else ...[
                if (criteria.length == 2)
                  ClubRaceVersus(
                    left: criteria[0],
                    right: criteria[1],
                    answerCount: count,
                  ),
                ArenaSection(
                  'Bulunan ${found.length}${count == null ? '' : ' / $count'}',
                  icon: Icons.people_alt_outlined,
                  trailing: count == null
                      ? null
                      : Text(
                          '${(count - found.length).clamp(0, count)} kalan',
                          textAlign: TextAlign.end,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Arena.lime,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                ),
                if (found.isEmpty)
                  const ArenaNote(
                    icon: Icons.bolt_rounded,
                    text: 'Henüz kimse bulmadı. İlk ismi yazan puanı alır.',
                  ),
                for (final f in found)
                  ClubRaceFoundTile(player: f, mine: f['uid'] == uid),
              ],
              if (rules != null && !countdown) ...[
                const SizedBox(height: 12),
                ArenaNote(icon: Icons.rule_rounded, text: rules),
              ],
              if (series.active)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: ArenaPill(
                      key: const ValueKey('series-pill'),
                      dot: palette.accent,
                      child: Text(seriesLine),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              ArenaSecondaryButton(
                label: 'Maçtan ayrıl (hükmen yenilgi)',
                icon: Icons.logout_rounded,
                color: palette.error,
                onPressed: busy ? null : leave,
              ),
            ],
          ),
        ),
        if (!countdown && draftMode)
          managerDraftBar()
        else if (!countdown && manager)
          managerBar()
        else if (!countdown && lotoCalls)
          lotoCallBar()
        else if (!countdown && mode == 'loto')
          lotoBar()
        else if (!countdown)
          ClubRaceInputBar(
            controller: query,
            onChanged: typed,
            onSubmitted: (_) => selected != null ? sendPick() : search(),
            results: results,
            onPick: pick,
            onSend: sendPick,
            selected: selected,
            searching: searching,
            noMatch: noMatch,
            lockSeconds: raceLock,
            outOfWrong: raceOut,
            sending: busy,
            blocked: blockedReason,
            label: mode == 'grid_reverse'
                ? 'Kulüp veya ülke ara'
                : 'Futbolcu ara',
            hint: mode == 'grid_reverse'
                ? 'Ortak kulüp ya da milli takım; dokun, gitsin'
                : 'En az 2 harf; öneriye dokun, gitsin',
          ),
      ],
    );
  }

  bool get _arena =>
      (clubRace ||
          gridMode ||
          mode == 'loto' ||
          cinkoV2 ||
          mode == 'random_five' ||
          mode == 'club_manager') &&
      !done &&
      ['countdown', 'playing'].contains(room['status']) &&
      !accountChanged;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: room.isEmpty || done || !connected || accountChanged,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) leave();
    },
    child: MusicScene(
      track: _inMatch ? _matchTrack : MusicTrack.menu,
      quiet: !_inMatch,
      child: _arena
          ? Scaffold(
              body: SafeArea(child: GameContent(child: liveArena())),
            )
          : Scaffold(
              body: SafeArea(
                child: GameContent(
                  child: Column(
                    children: [
                      ArenaHeader(
                        title: widget.mode.title,
                        subtitle: room.isEmpty
                            ? (ranked ? 'Dereceli eşleşme' : 'Arkadaş maçı')
                            : done
                            ? 'Maç sonucu · ${ranked ? 'Dereceli' : 'Arkadaş maçı'}'
                            : ranked
                            ? 'Rastgele eşleşme'
                            : series.active
                            ? 'Üç maçlık seri · ${series.game}. maç'
                            : 'Arkadaş maçı · Oda ${room['id'] ?? ''}',
                        tag: room.isEmpty
                            ? 'ONLINE'
                            : done
                            ? 'SONUÇ'
                            : 'LOBİ',
                        actions: [
                          ArenaIconButton(
                            tooltip: 'Yenile',
                            icon: Icons.refresh_rounded,
                            onPressed: busy || accountChanged
                                ? null
                                : () {
                                    if (room.isEmpty)
                                      load();
                                    else
                                      action('poll');
                                  },
                          ),
                        ],
                      ),
                      Divider(height: 1, color: palette.border),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            if (busy && data.isEmpty && room.isEmpty)
                              const LinearProgressIndicator(),
                            if (error != null)
                              GameErrorPanel(
                                message: error!,
                                accountChanged: accountChanged,
                                onRetry: busy || accountChanged
                                    ? null
                                    : () {
                                        if (room.isEmpty)
                                          load();
                                        else
                                          action('poll');
                                      },
                              ),
                            if (feedback != null)
                              panel([
                                Semantics(
                                  liveRegion: true,
                                  child: note(feedback!),
                                ),
                              ]),
                            if (room.isEmpty &&
                                data.isNotEmpty &&
                                error == null)
                              setup(),
                            if (room.isNotEmpty) ...[
                              if (![
                                    'waiting',
                                    'ready',
                                  ].contains(room['status']) &&
                                  !done)
                                hud(),
                              if (['waiting', 'ready'].contains(room['status']))
                                lobby()
                              else if (done)
                                outcome()
                              else if (room['status'] == 'countdown')
                                panel([
                                  heading('Hazır ol'),
                                  note('Aynı anda başlayacaksınız.'),
                                ])
                              else
                                play(),
                              if (!done &&
                                  ![
                                    'waiting',
                                    'ready',
                                  ].contains(room['status']))
                                button('Maçtan ayrıl', leave, secondary: true),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    ),
  );
}
