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
import '../widgets/player_portrait.dart';
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
  Timer? poller, ticker;
  final clock = Stopwatch();
  int serverNow = 0, searchSerial = 0;
  bool get ranked => room.isNotEmpty
      ? room['playKind'] == 'ranked'
      : widget.playKind == 'ranked';
  String get mode => widget.mode.wireName;
  String get uid => '${room['myUid']}';
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
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    poller?.cancel();
    ticker?.cancel();
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
      feedback = null;
    });
    try {
      final response = await task();
      if (!mounted) return;
      setState(() {
        connected = true;
        if (response.containsKey('availability')) data = response;
        if (response['room'] != null) {
          final next = rewardMap(response['room']);
          if (next['revision'] != room['revision']) cinkoCells.clear();
          if (next['id'] != room['id'] || next['round'] != room['round']) {
            searchSerial++;
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
          feedback = 'Bu futbolcu kriteri karşılamıyor.';
        if (receipt['accepted'] == true && receipt['correct'] is bool) {
          AppFeedback.sfx(
            receipt['correct'] == true ? Sfx.answerCorrect : Sfx.answerWrong,
          );
        }
        if (receipt['accepted'] == true && receipt.containsKey('correct')) {
          selected = null;
          results = [];
          query.clear();
        }
      });
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

  Future<void> action(String action, [Map<String, dynamic> extra = const {}]) =>
      run(() => service.act(room, action, extra), userAction: action != 'poll');
  Future<void> search() async {
    if (!connected || busy) return;
    final serial = ++searchSerial;
    final text = query.text.trim();
    if (text.length < 2) return;
    try {
      final found = await service.search(mode, text, roomId: room['id']);
      if (mounted && serial == searchSerial)
        setState(() {
          results = found;
          selected = null;
        });
    } catch (e) {
      if (mounted && serial == searchSerial)
        setState(() => feedback = gameErrorMessage(e));
    }
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
  List<Widget> gridNotes() {
    if (room['gridRules'] != 2) return const [];
    final wrong = rewardMap(room['gridWrong']);
    final rival = room['host'] == uid ? room['guest'] : room['host'];
    return [
      if (mode == 'grid_random')
        note(
          'Doğru cevap 1 puan; çiftin az bilinen yarısından bir isim '
          '+${room['rareBonus'] ?? 1} puan daha getirir.',
        )
      else
        note(
          'Yanlış cevap: ${wrong[uid] ?? 0} · rakip ${wrong[rival] ?? 0}. '
          'Skor eşitse az yanlış yapan kazanır.',
        ),
    ];
  }

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
    final available =
        rewardMap(data['availability'])[ranked
            ? 'rankedEnabled'
            : 'friendEnabled'] ==
        true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GameIntro(
          icon: widget.mode.icon,
          title: ranked ? 'Eşit koşullarda yarış' : 'Arkadaşınla karşılaş',
          message: widget.mode.subtitle,
        ),
        const SizedBox(height: 16),
        panel([
          note(
            ranked
                ? 'Aynı soru, aynı süre. Maç sonucu sunucuda doğrulanır.'
                : 'Oda koduyla katıl. Dostluk maçında Elo, Coin ve XP değişmez.',
          ),
          if (!available)
            note(
              ranked
                  ? 'Bu modda dereceli eşleşme şu anda kapalı.'
                  : 'Bu modda arkadaş odaları şu anda kapalı.',
            ),
          if (data['linked'] == false)
            note('Online maç için profilinden Google hesabını bağla.'),
          if (data['activeId'] != null &&
              data['activePlayKind'] == widget.playKind)
            button('Kayıtlı maça devam et', () => enter('resume')),
          if (data['activeId'] != null &&
              data['activePlayKind'] != widget.playKind) ...[
            note('Bu modda diğer eşleşme türünde kayıtlı bir maçın var.'),
            button(
              'Kayıtlı maç ekranını aç',
              () => Navigator.of(context).pushReplacement(
                LinkballRoute(
                  modern: true,
                  builder: (_) => PvpPage(
                    mode: widget.mode,
                    playKind: '${data['activePlayKind']}',
                    service: service,
                  ),
                ),
              ),
              secondary: true,
            ),
          ],
          if (!ranked) ...[
            choice('Maç profili', profile, [
              {'id': 'standard', 'label': 'Tek maç'},
              {'id': 'series3', 'label': 'Üç maçlık seri'},
            ], (v) => setState(() => profile = v)),
            const SizedBox(height: 12),
            button(
              'Oda oluştur',
              available && data['linked'] == true
                  ? () => enter('create')
                  : null,
            ),
            RoomCodeField(
              controller: code,
              enabled: !busy && connected,
              onChanged: (_) => setState(() {}),
            ),
            button(
              'Koda katıl',
              available && data['linked'] == true && validRoomCode(code.text)
                  ? () =>
                        enter('join', roomCode: code.text.trim().toUpperCase())
                  : null,
              secondary: true,
            ),
          ] else
            button(
              'Rakip ara',
              available && data['linked'] == true
                  ? () => enter('search')
                  : null,
            ),
        ]),
        if (rows(data['history']).isNotEmpty)
          panel([
            heading('Son maçların'),
            ...rows(data['history'])
                .where((r) => r['playKind'] == widget.playKind)
                .map(
                  (r) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    onTap: () =>
                        run(() => service.act({...r, 'revision': 0}, 'poll')),
                    title: Text(
                      '${r['status'] == 'finished' ? 'Tamamlandı' : 'Sonlandırıldı'} · ${r['id']}',
                    ),
                    subtitle: Text(rewardMap(r['scores']).values.join(' – ')),
                  ),
                ),
          ]),
      ],
    );
  }

  Widget lobby() {
    final host = room['host'] == uid;
    final ready = rewardMap(room['ready']);
    final choices = rewardMap(room['choices']);
    return panel([
      heading(
        room['status'] == 'waiting'
            ? ranked
                  ? 'Rakip aranıyor'
                  : 'Arkadaşını bekliyorsun'
            : 'Maça hazırlan',
      ),
      if (!ranked) ...[
        OnlineRoomCode(code: '${room['id']}'),
        if (host && room['guest'] == null)
          FriendMatchInviteButton(mode: widget.mode, roomCode: '${room['id']}'),
      ],
      note(
        ranked
            ? '30 saniye içinde rakip bulunamazsa arama kapanır.'
            : 'İki oyuncu da hazır olduğunda beş saniyelik geri sayım başlar.',
      ),
      ...rewardMap(room['names']).entries.map(
        (e) =>
            note('${e.value} · ${ready[e.key] == true ? 'Hazır' : 'Bekliyor'}'),
      ),
      if (room['status'] == 'ready') ...[
        if (!ranked && ['club_club', 'club_country'].contains(mode)) ...[
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
        button(
          ready[uid] == true ? 'Rakibin hazırlanıyor' : 'Hazırım',
          ready[uid] == true ? null : () => action('ready'),
        ),
      ],
      button(
        'Aramayı / odayı iptal et',
        () => action('leave'),
        secondary: true,
      ),
    ]);
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
      if (mode == 'grid_random' && !done)
        note(
          'Tur ${(room['round'] as num? ?? 0) + 1} / 5 · Her oyuncuya bir cevap hakkı',
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
      onChanged: (_) => setState(() {
        selected = null;
        results = [];
        searchSerial++;
      }),
      onSubmitted: (_) => search(),
      decoration: InputDecoration(
        labelText: 'Futbolcu ara',
        suffixIcon: IconButton(
          tooltip: 'Ara',
          onPressed: !connected || busy ? null : search,
          icon: const Icon(Icons.search),
        ),
      ),
    ),
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

  Widget manager() {
    final pool = rows(room['pool']);
    final budget = room['budget'] as num? ?? 120;
    final locked = room['submitted'] == true;
    final editable = !busy && connected && !locked;
    final spent = pool
        .where((p) => xi.contains(p['id']))
        .fold<num>(0, (n, p) => n + (p['cost'] as num));
    final slots = managerSlots[formation]!;
    int picked(String pos) =>
        pool.where((p) => p['position'] == pos && xi.contains(p['id'])).length;
    final fits = slots.entries.every((e) => picked(e.key) == e.value);
    final over = spent > budget;
    final v2 = room['managerRules'] == 2;
    return panel([
      heading('Aynı bütçe, senin XI’in'),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: (spent / budget).clamp(0, 1).toDouble(),
            minHeight: 10,
            color: over ? palette.error : accent,
            backgroundColor: palette.border,
          ),
        ),
      ),
      note(
        '${xi.length} / 11 oyuncu · $spent / $budget kadro bütçesi'
        '${over ? ' · bütçe aşıldı' : ' · kalan ${budget - spent}'}',
      ),
      note(
        'Yıldızlar (★, 14–18) bütçenin tamamına sığmaz; kimin için harcayacağını '
        'seç. Kadro bütçesi oyun içindir; Coin bakiyen kullanılmaz.',
      ),
      choice(
        'Diziliş',
        formation,
        [
          for (final f in managerSlots.keys)
            {'id': f, 'label': f.split('').join('-')},
        ],
        (v) => setState(() => formation = v),
        enabled: !locked,
      ),
      Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final e in slots.entries)
            Chip(
              avatar: Icon(
                picked(e.key) == e.value
                    ? Icons.check_circle_rounded
                    : Icons.radio_button_unchecked_rounded,
                size: 18,
                color: picked(e.key) == e.value
                    ? palette.success
                    : picked(e.key) > e.value
                    ? palette.error
                    : palette.muted,
              ),
              label: Text(
                '${positionNames[e.key]} ${picked(e.key)}/${e.value}',
              ),
            ),
        ],
      ),
      if (!locked)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: editable ? () => autoFill(pool, budget) : null,
            icon: const Icon(Icons.auto_fix_high_rounded),
            label: const Text('Boşları bütçeye göre doldur'),
          ),
        ),
      for (final pos in positionNames.keys) ...[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(
            '${positionNames[pos]} · ${picked(pos)}/${slots[pos]}',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        for (final p in pool.where((p) => p['position'] == pos))
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            value: xi.contains(p['id']),
            title: Text('${(p['cost'] as num) >= 14 ? '★ ' : ''}${p['name']}'),
            subtitle: Text('${p['rating']} reyting · ${p['cost']} bütçe'),
            onChanged: !editable
                ? null
                : (v) => setState(() {
                    if (v == true) {
                      xi.add('${p['id']}');
                    } else {
                      xi.remove(p['id']);
                    }
                  }),
          ),
      ],
      const SizedBox(height: 8),
      Text('Taktik', style: Theme.of(context).textTheme.titleSmall),
      note(
        v2
            ? 'Taktikler döngü gibi: yüksek pres tempoyu, tempo genişliği, '
                  'genişlik presi yener. Her şeyi yükseltmek avantaj getirmez; '
                  'rakibin taktiği maçtan sonra açılır.'
            : 'Rakibin taktiği maçtan sonra açılır.',
      ),
      for (final t in [
        ('Press', press),
        ('Tempo', tempo),
        ('Genişlik', width),
      ]) ...[
        note('${t.$1} · ${(t.$2 * 100).round()}'),
        Slider(
          value: t.$2,
          divisions: 4,
          label: '${(t.$2 * 100).round()}',
          onChanged: !editable
              ? null
              : (v) => setState(() {
                  if (t.$1 == 'Press') {
                    press = v;
                  } else if (t.$1 == 'Tempo') {
                    tempo = v;
                  } else {
                    width = v;
                  }
                }),
        ),
      ],
      if (!locked && xi.length == 11 && !fits)
        note(
          'Seçtiğin oyuncular ${formation.split('').join('-')} dizilişine uymuyor.',
        ),
      button(
        locked ? 'Kadro kilitlendi' : 'XI ve taktiği kilitle',
        xi.length != 11 || over || !fits || locked
            ? null
            : () => action('squad', {
                'playerIds': xi.toList(),
                'formation': formation,
                'tactics': {'press': press, 'tempo': tempo, 'width': width},
              }),
      ),
      note(
        v2
            ? 'Rakibin kadrosu iki taraf da kilitledikten sonra görünür. Süre '
                  'dolduğunda yalnız sen kilitlediysen maçı hükmen kazanırsın.'
            : 'Rakibin kadrosu ve taktiği iki taraf da kilitledikten sonra görünür.',
      ),
    ]);
  }

  Widget play() {
    if (mode == 'club_manager') return manager();
    final criteria = rows(room['criteria']);
    final labels = {
      for (final k in [...rows(data['clubs']), ...rows(data['countries'])])
        '${k['id']}': '${k['label']}',
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (mode.startsWith('grid_')) ...gridNotes(),
        if (mode == 'grid_classic') ...[
          board(3, [
            for (final row in rows(room['rows']))
              for (final col in rows(room['cols']))
                '${GridCriterionLabel.text(row)} × ${GridCriterionLabel.text(col)}',
          ]),
          const SizedBox(height: 14),
          if (target != null)
            note(
              'Seçilen hücre: ${GridCriterionLabel.text(rows(room['rows'])[int.parse(target!) ~/ 3])} × '
              '${GridCriterionLabel.text(rows(room['cols'])[int.parse(target!) % 3])}',
            ),
        ] else if (mode == 'grid_reverse') ...[
          board(
            3,
            rows(room['players']).map((p) => '${p['name']}').toList(),
            selectable: false,
          ),
          const SizedBox(height: 14),
          panel([
            choice('Boş eksen', target, [
              for (final a in ['r0', 'r1', 'r2', 'c0', 'c1', 'c2'])
                if (!rewardMap(room['owners']).containsKey(a))
                  {
                    'id': a,
                    'label':
                        '${a.startsWith('r') ? 'Satır' : 'Sütun'} ${int.parse(a[1]) + 1}',
                  },
            ], (v) => setState(() => target = v)),
            const SizedBox(height: 12),
            choice('Ortak kulüp veya ülke', criterion, [
              ...rows(data['clubs']),
              ...rows(data['countries']),
            ], (v) => setState(() => criterion = v)),
            button(
              'Ekseni doğrula',
              target == null || criterion == null || room['turnUid'] != uid
                  ? null
                  : () => action('answer', {
                      'targetId': target,
                      'criterionId': criterion,
                    }),
            ),
            ...rewardMap(room['owners']).entries.map(
              (e) => note(
                '${axisName(e.key)}: '
                '${labels[rewardMap(e.value)['criterionId']] ?? rewardMap(e.value)['criterionId']} · '
                '${rewardMap(e.value)['uid'] == uid ? 'Sen' : rewardMap(room['names'])[rewardMap(e.value)['uid']]}',
              ),
            ),
          ]),
        ] else if (mode == 'cinko' || mode == 'loto') ...[
          board(
            mode == 'cinko' ? 5 : 4,
            criteria.map((k) => '${k['label']}').toList(),
            selectable: mode == 'loto',
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
        if (mode == 'loto')
          panel([
            heading('Tahtanın futbolcuları'),
            ...wrongNotes(),
            if (target != null)
              note('Seçilen hücre: ${criteria[int.parse(target!)]['label']}'),
            ...rows(room['players']).map(
              (p) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('${p['name']}'),
                selected: selected?['id'] == p['id'],
                enabled: !rewardMap(room['used']).containsKey(p['id']),
                onTap: () => setState(() => selected = p),
              ),
            ),
            button(
              'Seçilen hücreye yerleştir',
              selected == null || target == null || locked > 0 || outOfWrong
                  ? null
                  : () => action('answer', {
                      'playerId': selected!['id'],
                      'targetId': target,
                    }),
            ),
          ])
        else if (mode != 'grid_reverse')
          chooser(),
        if (mode == 'grid_random' && rewardMap(room['rounds']).isNotEmpty)
          panel([
            heading('Kapanan turlar'),
            ...rewardMap(room['rounds']).entries.map((e) {
              final mine = rewardMap(rewardMap(e.value)[uid]);
              return note(
                'Tur ${int.parse(e.key) + 1}: '
                '${mine['correct'] == true ? 'Doğru${mine['bonus'] != null ? ' · nadir isim +${mine['bonus']}' : ''}' : 'Puan yok'}',
              );
            }),
          ]),
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
        panel([
          if (room['simulation'] != null) ...[
            note(
              'Sunucuda hesaplanan gol sonucu: ${rewardMap(rewardMap(room['simulation'])['goals']).values.join(' – ')}',
            ),
            for (final side in [uid, rival])
              note(
                '${side == uid ? 'Sen' : names[rival] ?? 'Rakip'} · güç '
                '${(rewardMap(rewardMap(room['simulation'])['powers'])[side] as num? ?? 0).toStringAsFixed(1)} · xG '
                '${(rewardMap(rewardMap(room['simulation'])['xg'])[side] as num? ?? 0).toStringAsFixed(2)}',
              ),
            if (rewardMap(room['simulation'])['penalties'] != null)
              note(
                'Penaltılar: ${rewardMap(rewardMap(room['simulation'])['penalties'])[uid] ?? 0} – '
                '${rewardMap(rewardMap(room['simulation'])['penalties'])[rival] ?? 0}',
              ),
          ],
          if (room['found'] is List || room['missed'] is List) ...[
            for (final side in [uid, rival])
              note(
                '${side == uid ? 'Senin bulduğun' : '${names[rival] ?? 'Rakip'} buldu'}: '
                '${joinOr(rows(room['found']).where((p) => p['uid'] == side).map((p) => p['name']))}',
              ),
            if (rows(room['missed']).isNotEmpty)
              note(
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
                  ...rows(
                    round,
                  ).map((p) => ListTile(title: Text('${p['name']}'))),
              ],
            ),
          if (room['squads'] != null)
            ExpansionTile(
              title: const Text('Kilitlenen kadrolar ve taktikler'),
              children: [
                for (final e in rewardMap(room['squads']).entries) ...[
                  note(
                    '${rewardMap(room['names'])[e.key]} · ${rewardMap(e.value)['formation']}',
                  ),
                  for (final id
                      in (rewardMap(e.value)['playerIds'] as List? ?? []))
                    note(
                      '${rows(room['pool']).where((p) => p['id'] == id).firstOrNull?['name'] ?? id}',
                    ),
                  note(
                    'Press: ${rewardMap(rewardMap(e.value)['tactics'])['press']} · Tempo: ${rewardMap(rewardMap(e.value)['tactics'])['tempo']} · Genişlik: ${rewardMap(rewardMap(e.value)['tactics'])['width']}',
                  ),
                ],
              ],
            ),
          button(
            'Sonucu kopyala',
            () => Clipboard.setData(
              ClipboardData(
                text:
                    '${widget.mode.title} · ${ranked ? 'Sıralamalı' : 'Arkadaş'}\n'
                    '${rewardMap(room['names']).entries.map((e) => '${e.value}: ${rewardMap(room['scores'])[e.key] ?? 0}').join(' — ')}\nMaç: ${room['id']}',
              ),
            ),
            secondary: true,
          ),
          ExpansionTile(
            title: const Text('Maç bilgisi'),
            children: [
              note(
                '${room['id']} · ${room['dataRevision']} · ${room['ruleVersion']}',
              ),
            ],
          ),
          if (!ranked && ['finished', 'forfeit'].contains(room['status']))
            button(
              room['nextRoom'] != null
                  ? 'Rövanş odasına geç'
                  : rewardMap(room['rematch'])[uid] == true
                  ? 'Rövanş için rakip bekleniyor'
                  : 'Rövanş iste',
              () async {
                if (room['nextRoom'] != null)
                  await enter('resume');
                else
                  await action('rematch');
              },
            ),
          button('Yeniden oyna', () {
            setState(() {
              room = {};
              xi.clear();
              target = null;
              selected = null;
              cinkoCells.clear();
            });
            load();
          }, secondary: true),
        ]),
      ],
    );
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

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: room.isEmpty || done || !connected || accountChanged,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) leave();
    },
    child: MusicScene(
      track: _inMatch ? _matchTrack : MusicTrack.menu,
      quiet: !_inMatch,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: MediaQuery.textScalerOf(context).scale(16) > 24
              ? 144
              : 64,
          title: Text(widget.mode.title, maxLines: 3, softWrap: true),
          actions: [
            IconButton(
              tooltip: 'Yenile',
              onPressed: busy || accountChanged
                  ? null
                  : () {
                      if (room.isEmpty)
                        load();
                      else
                        action('poll');
                    },
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        body: GameContent(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                ranked ? 'RASTGELE EŞLEŞME' : 'ARKADAŞ MAÇI',
                style: TextStyle(color: accent, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
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
                panel([Semantics(liveRegion: true, child: note(feedback!))]),
              if (room.isEmpty && data.isNotEmpty && error == null) setup(),
              if (room.isNotEmpty) ...[
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
                if (!done) button('Maçtan ayrıl', leave, secondary: true),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}
