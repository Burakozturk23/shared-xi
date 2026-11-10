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
  Timer? poller, ticker, typing;
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
  bool get cinkoV2 => mode == 'cinko' && room['cinkoRules'] == 2;
  bool get done =>
      ['finished', 'cancelled', 'forfeit', 'expired'].contains(room['status']);
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
      if (mounted && foreground && room.isNotEmpty && !done) setState(() {});
      // Turn-based Grids: while the rival plays, ask every 3 s instead of 6 s
      // so the turn comes back without a wait.
      if (mounted &&
          foreground &&
          connected &&
          !busy &&
          !done &&
          (gridMode || cinkoV2) &&
          room['status'] == 'playing' &&
          !myTurn &&
          DateTime.now().difference(lastPoll) >= const Duration(seconds: 3))
        action('poll');
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    poller?.cancel();
    ticker?.cancel();
    typing?.cancel();
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
            _ => 'Bu futbolcu kriteri karşılamıyor.',
          };
        if (receipt['correct'] == true)
          feedback = switch (mode) {
            'club_club' ||
            'club_country' => 'Doğru! +${receipt['points'] ?? 1} puan',
            'random_five' =>
              'Doğru! ${(room['fivePoints'] as List? ?? const []).indexOf(receipt['points'])} kulüp · +${receipt['points'] ?? 1} puan',
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
          if (business) {
            feedback = gameErrorMessage(e);
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
    if (['finished', 'forfeit'].contains(status) &&
        before['id'] == id &&
        before['status'] != status) {
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
        room.isEmpty) {
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
                    : 'Maça hazırlan',
                style: text.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                waiting
                    ? ranked
                          ? '30 saniye içinde rakip bulunamazsa arama kapanır.'
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
            label: ready[uid] == true ? 'Rakibin hazırlanıyor' : 'Hazırım',
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
          label: ranked ? 'Aramayı iptal et' : 'Odayı kapat',
          icon: Icons.close_rounded,
          color: palette.error,
          onPressed: busy ? null : () => action('leave'),
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
        ),
      if (rewardMap(room['series'])['limit'] == 3)
        note('Seri maçı ${rewardMap(room['series'])['game']} / 3'),
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
    final reward = rewardMap(room['reward']);
    final names = rewardMap(room['names']), scores = rewardMap(room['scores']);
    final rival = room['host'] == uid ? '${room['guest']}' : '${room['host']}';
    final won = room['status'] == 'finished' && room['result'] == 'win';
    final verified = ranked && reward['status'] != 'pending';
    final elo = (reward['eloDelta'] as num? ?? 0).toInt();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: HubResultCard(
            tone: won ? HubResultTone.win : HubResultTone.neutral,
            icon: won
                ? Icons.emoji_events_rounded
                : room['status'] == 'finished'
                ? Icons.sports_score_rounded
                : Icons.flag_rounded,
            kicker: ranked ? 'Dereceli maç' : 'Dostluk maçı',
            title: room['status'] == 'finished'
                ? room['result'] == 'win'
                      ? 'Kazandın'
                      : room['result'] == 'loss'
                      ? 'Maç tamamlandı'
                      : 'Berabere'
                : room['status'] == 'forfeit'
                ? 'Maç hükmen sonuçlandı'
                : 'Maç iptal edildi',
            subtitle:
                '${names[uid] ?? 'Sen'} ${scores[uid] ?? 0} – ${scores[rival] ?? 0} ${names[rival] ?? 'Rakip'}',
            coins: verified ? (reward['coins'] as num?)?.toInt() : null,
            xp: verified ? (reward['xp'] as num?)?.toInt() : null,
            notes: [
              if ('${room['reason'] ?? ''}'.isNotEmpty) '${room['reason']}',
              if (verified) 'Elo ${elo > 0 ? '+' : ''}$elo',
              if (ranked && !verified) 'Sonuç ve ödül doğrulaması bekleniyor.',
              if (!ranked) 'Dostluk maçı · Elo ve ödül yok',
              if (rewardMap(room['series'])['limit'] == 3)
                'Seri galibiyetleri: ${rewardMap(rewardMap(room['series'])['wins']).entries.map((e) => '${names[e.key]} ${e.value}').join(' · ')}',
            ],
          ),
        ),
        ...outcomeRecap(rival),
        const SizedBox(height: 16),
        if (!ranked && ['finished', 'forfeit'].contains(room['status'])) ...[
          ArenaPrimaryButton(
            label: room['nextRoom'] != null
                ? 'Rövanş odasına geç'
                : rewardMap(room['rematch'])[uid] == true
                ? 'Rövanş için rakip bekleniyor'
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
      if (sim.isNotEmpty) ...[
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
      if (mode == 'loto' && room['criteria'] is List) ...[
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
          ['waiting', 'ready'].contains(room['status'])
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
  bool get penaltyMode => clubRace || mode == 'loto' || mode == 'random_five';
  int get raceLock => penaltyMode ? locked : 0;
  bool get raceOut => penaltyMode && outOfWrong;

  /// Why the arena cannot send now; null when a pick may go.
  String? get blockedReason {
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
      _ => {'playerId': p['id']},
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
    'club_manager' =>
      'İkiniz aynı havuzdan, aynı bütçeyle 11 kişilik kadro kurarsınız. Yıldızlar (★) '
          'bütçenin tamamına sığmaz; kimin için harcayacağını seç. İki taraf da kilitleyince '
          'maç oynanır; süre dolduğunda yalnız sen kilitlediysen hükmen kazanırsın. Kadro '
          'bütçesi oyun içindir, Coin harcanmaz.',
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
    final wrong = rewardMap(room[gridMode ? 'gridWrong' : 'wrongMoves']);
    final rival = uid == '${room['host']}'
        ? '${room['guest']}'
        : '${room['host']}';
    final criteria = rows(room['criteria']);
    final found = rows(room['found']);
    final count = (room['answerCount'] as num?)?.toInt();
    final countdown = room['status'] == 'countdown';
    final turnBased = gridMode || cinkoV2;
    final (clockKey, total) = switch (mode) {
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
      caption: cinkoV2
          ? 'Kutu ${rewardMap(room['owners']).values.where((o) => rewardMap(o)['uid'] == id).length}'
          : manager
          ? ((id == uid
                    ? room['submitted'] == true
                    : room['rivalLocked'] == true)
                ? 'Kilitledi'
                : 'Kuruyor')
          : null,
      display: !manager
          ? null
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
                maxWrong: gridMode || cinkoV2 || manager
                    ? null
                    : (room['maxWrong'] as num? ?? 10).toInt(),
                secondsLeft: seconds(room[clockKey]),
                totalSeconds: total,
                countdown: countdown ? seconds(room['startsAt']) : null,
                status: countdown
                    ? null
                    : turnBased
                    ? (myTurn ? 'SIRA SENDE' : 'RAKİPTE')
                    : manager
                    ? (room['submitted'] == true ? 'KİLİTLENDİ' : 'KADRO KUR')
                    : null,
                myTurn: turnBased ? myTurn : null,
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
              ] else if (manager) ...[
                ...managerArena(),
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
              if (rewardMap(room['series'])['limit'] == 3)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Center(
                    child: ArenaPill(
                      child: Text(
                        'Seri maçı ${rewardMap(room['series'])['game']} / 3',
                      ),
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
        if (!countdown && manager)
          managerBar()
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
