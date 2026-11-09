import '../widgets/paid_hint_button.dart';
import '../widgets/hint_panel.dart';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../app/app_feedback.dart';
import '../app/game_audio.dart';
import '../models/rewarded_ad_models.dart';
import '../services/warm_up.dart';
import '../widgets/bot_arena.dart';
import '../services/arcade_service.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/share_result.dart';
import '../widgets/game_ui.dart';
import '../widgets/hub_ui.dart';
import '../services/game_error.dart';
import '../theme/ortak_saha_theme.dart';

int _n(Object? value) =>
    value is num ? value.toInt() : int.tryParse('$value') ?? 0;
List<Map<String, dynamic>> _rows(Object? value) =>
    (value as List? ?? []).map(rewardMap).toList();
String _difficulty(String s) =>
    {
      'easy': 'Kolay',
      'normal': 'Normal',
      'hard': 'Zor',
      'legend': 'Efsane',
    }[s] ??
    s;

class ArcadePage extends StatefulWidget {
  const ArcadePage({
    super.key,
    required this.mode,
    this.service,
    this.recordsInitially = false,
  });
  final String mode;
  final ArcadeService? service;
  final bool recordsInitially;
  @override
  State<ArcadePage> createState() => _ArcadePageState();
}

class _ArcadePageState extends State<ArcadePage> with WidgetsBindingObserver {
  PitchColors get palette => PitchColors.of(context);
  Color get accent => palette.accent;
  late final ArcadeService service = widget.service ?? ArcadeService();
  Map<String, dynamic> data = {};
  Map<String, dynamic> get run => rewardMap(data['session']);
  final answer = TextEditingController();
  final elapsed = Stopwatch();
  Timer? ticker;
  Timer? debounce;
  ScrollController? pyramidScroll;
  List<Map<String, dynamic>> suggestions = [];
  String difficulty = 'normal', style = 'speed', pairType = 'clubClub';
  String? slotId, error;
  bool busy = true, showRecords = false, background = false;

  /// A local Burst clock save is in flight. It never sets [busy]: the save takes
  /// milliseconds on the phone, and flagging the page busy every second flashed
  /// the loading bar and locked the answer field mid-typing.
  bool checkpointing = false;
  Future<void>? _checkpointRun;
  int searchEpoch = 0;
  bool get offline =>
      data['offline'] == true && data['offlinePlayable'] != true;
  bool get local => data['offline'] == true && data['offlinePlayable'] == true;
  bool get active =>
      run.isNotEmpty && run['phase'] == 'active' && run['finished'] != true;
  String get title => {
    'burst': 'Burst',
    'pyramid': 'Bağlantı Piramidi',
    'matching': 'Kart Eşleştirme',
  }[widget.mode]!;
  bool get running =>
      active &&
      run['paused'] != true &&
      !offline &&
      !background &&
      error == null;
  int get delta => running ? elapsed.elapsedMilliseconds : 0;
  @override
  void initState() {
    super.initState();
    showRecords = widget.recordsInitially;
    WidgetsBinding.instance.addObserver(this);
    unawaited(load());
    // Starting and playing use other functions than this screen's status call.
    if (widget.service == null) WarmUp.functions(['prepareArcade', 'actArcade']);
    ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (!mounted || !active) return;
      setState(() {});
      if (busy ||
          error != null ||
          offline ||
          background ||
          run['paused'] == true)
        return;
      // Both Burst styles have a round clock; Speed also has a total clock.
      final speedExpired =
          widget.mode == 'burst' &&
          (delta >= _n(run['roundRemainingMs']) ||
              run['style'] == 'speed' && delta >= _n(run['totalRemainingMs']));
      final lockExpired =
          widget.mode == 'matching' &&
          _n(run['lockUntil']) > 0 &&
          _n(run['serverNow']) + elapsed.elapsedMilliseconds >=
              _n(run['lockUntil']);
      if (speedExpired || lockExpired) {
        unawaited(act('tick'));
      } else if (widget.mode == 'burst' &&
          rewardMap(data['burstKit']).isNotEmpty &&
          elapsed.elapsedMilliseconds >= 1000) {
        unawaited(checkpoint());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    ticker?.cancel();
    debounce?.cancel();
    answer.dispose();
    pyramidScroll?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    background = state != AppLifecycleState.resumed;
    if (error == null && background && active && run['paused'] != true && !busy)
      unawaited(act('pause'));
    if (!background && !busy) unawaited(load());
  }

  void accept(Map<String, dynamic> value) {
    data = {...data, ...value, 'offline': value['offline'] == true};
    elapsed
      ..reset()
      ..start();
    if (slotId != null && rewardMap(run['filled']).containsKey(slotId))
      slotId = null;
  }

  Future<void> load() async {
    if (mounted)
      setState(() {
        busy = true;
        error = null;
      });
    try {
      final value = await service.load(widget.mode);
      if (mounted) setState(() => accept(value));
    } catch (e) {
      if (mounted) setState(() => error = gameErrorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (mounted &&
        error == null &&
        showRecords &&
        active &&
        run['paused'] != true &&
        !offline)
      unawaited(act('pause'));
  }

  Future<void> act(
    String action, [
    Map<String, dynamic> more = const {},
  ]) async {
    if (busy || offline || error != null) return;
    setState(() {
      busy = true;
      error = null;
    });
    // Both write the same local Burst journal: let a running clock save finish first.
    final pending = _checkpointRun;
    if (pending != null) await pending;
    final beforeQuestion = rewardMap(run['question'])['id'];
    int matched() => _rows(
      rewardMap(run['board'])['cards'],
    ).where((c) => c['matched'] == true).length;
    final matchedBefore = matched();
    try {
      final value = await service.mutate({
        'mode': widget.mode,
        'sessionId': run['id'],
        'revision': run['revision'],
        'action': action,
        'questionId': beforeQuestion,
        if (widget.mode == 'burst')
          'elapsedMs': run['paused'] == true ? 0 : elapsed.elapsedMilliseconds,
        ...more,
      });
      if (!mounted) return;
      final before = run;
      setState(() {
        accept(value);
        if (action == 'answer') AppFeedback.answerFrom(before, run);
        // Matching: the flip is confirmed by the server; a new pair is a combo.
        if (action == 'flip')
          AppFeedback.sfx(
            matched() > matchedBefore ? Sfx.perfectCombo : Sfx.cardFlip,
          );
        if (action == 'answer' ||
            beforeQuestion != rewardMap(run['question'])['id']) {
          answer.clear();
          suggestions = [];
          searchEpoch++;
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = gameErrorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (error == null &&
        background &&
        active &&
        run['paused'] != true &&
        !offline &&
        action != 'pause')
      unawaited(act('pause'));
  }

  Future<void> checkpoint() {
    if (busy || checkpointing || !running) return Future.value();
    return _checkpointRun = _checkpoint().whenComplete(() => _checkpointRun = null);
  }

  Future<void> _checkpoint() async {
    checkpointing = true;
    try {
      final value = await service.checkpoint({
        'mode': 'burst',
        'sessionId': run['id'],
        'revision': run['revision'],
        'action': 'tick',
        'questionId': rewardMap(run['question'])['id'],
        'elapsedMs': elapsed.elapsedMilliseconds,
      });
      // An answer or pass that started meanwhile has the newer state; keep it.
      if (mounted && !busy) setState(() => accept(value));
    } catch (e) {
      if (mounted) setState(() => error = gameErrorMessage(e));
    } finally {
      checkpointing = false;
    }
    if (error == null && background && active && run['paused'] != true)
      unawaited(act('pause'));
  }

  Future<void> prepare({bool daily = false}) async {
    if (busy || error != null) return;
    if (data['offline'] == true) {
      setState(() => error = 'Yeni oyun hazırlamak için bağlantı gerekli.');
      return;
    }
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final value = await service.mutate({
        'mode': widget.mode,
        'version': data['version'],
        'difficulty': difficulty,
        'style': style,
        'pairType': pairType,
        if (daily) 'daily': true,
      }, prepare: true);
      if (mounted)
        setState(() {
          accept(value);
          showRecords = false;
        });
    } catch (e) {
      if (mounted) setState(() => error = gameErrorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void search(String text) {
    debounce?.cancel();
    final epoch = ++searchEpoch;
    if (text.trim().length < 2) {
      setState(() => suggestions = []);
      return;
    }
    debounce = Timer(const Duration(milliseconds: 250), () async {
      try {
        final found = await service.search(widget.mode, '${run['id']}', text);
        if (mounted && epoch == searchEpoch)
          setState(() => suggestions = found);
      } catch (_) {
        if (mounted && epoch == searchEpoch) setState(() => suggestions = []);
      }
    });
  }

  Future<void> finish() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Bu oyunu bitir?'),
        content: const Text(
          'Kayıt sonuçlandırılır. Yeni oyun açıldığında enerji kuralı yeniden uygulanır.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Devam et'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Bitir'),
          ),
        ],
      ),
    );
    if (yes == true)
      await act(run['phase'] == 'prepared' ? 'cancel' : 'finish');
  }

  Future<void> adHint({String? boostId, String? itemId}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await service.watch('${run['id']}', boostId: boostId, itemId: itemId);
    } catch (e) {
      if (mounted) setState(() => error = gameErrorMessage(e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (mounted) await load();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !active || error != null || offline,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (busy) return;
        if (run['paused'] != true) await act('pause');
        if (mounted && run['paused'] == true) Navigator.of(context).pop();
      },
      child: Scaffold(
        body: GameContent(
          child: Column(
            children: [
              ArenaHeader(
                title: showRecords ? '$title Rekor Merkezi' : title,
                subtitle: subtitle,
                tag: tag,
                canPop: !active || error != null || offline,
                actions: [
                  ArenaIconButton(
                    tooltip: 'Rekor Merkezi',
                    icon: Icons.emoji_events_outlined,
                    onPressed: busy
                        ? null
                        : () async {
                            if (active && run['paused'] != true && !offline)
                              await act('pause');
                            if (mounted)
                              setState(() => showRecords = !showRecords);
                          },
                  ),
                  ArenaIconButton(
                    tooltip: 'Yenile',
                    icon: Icons.refresh_rounded,
                    onPressed: busy ? null : load,
                  ),
                ],
              ),
              Divider(height: 1, color: palette.border),
              if (busy) const LinearProgressIndicator(minHeight: 2),

              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
                  children: [
                    if (data.isEmpty) ...[
                      GameIntro(
                        icon: widget.mode == 'burst'
                            ? Icons.bolt_outlined
                            : widget.mode == 'pyramid'
                            ? Icons.account_tree_outlined
                            : Icons.grid_view_outlined,
                        title: title,
                        message: widget.mode == 'burst'
                            ? 'Ortak bağları bul, serini büyüt.'
                            : widget.mode == 'pyramid'
                            ? 'Oyuncularla bağlantıları tamamla ve zirveye ulaş.'
                            : 'Oyuncuları kulüpleriyle eşleştir.',
                      ),
                      const SizedBox(height: 16),
                    ],
                    if (error != null)
                      GameErrorPanel(
                        message: error!,
                        onRetry: busy ? null : load,
                      ),
                    if (data['notice'] != null)
                      panel('Oyun durumu', '${data['notice']}'),
                    if (showRecords && data.isNotEmpty)
                      ...records()
                    else if (data.isNotEmpty) ...[
                      if (run.isEmpty || run['finished'] == true) ...[
                        if (run['finished'] == true) ...result(),
                        ...setup(),
                      ] else ...[
                        if (run['phase'] == 'prepared') ...[
                          panel(
                            'Tahtan hazır',
                            'Veriler ve çözüm kontrol edildi. Başlatınca ${data['energyCost'] ?? 0} enerji kullanılır.',
                          ),
                          button('Başlat', () => act('confirm')),
                          TextButton(
                            onPressed: busy ? null : finish,
                            child: const Text('Hazırlığı iptal et'),
                          ),
                        ] else if (run['paused'] == true) ...[
                          panel(
                            'Oyun duraklatıldı',
                            'Kaldığın yer ve kalan hakların hesabında saklı. 24 saat içinde ücretsiz devam edebilirsin.',
                          ),
                          button('Devam et', () => act('resume')),
                        ] else ...[
                          if (widget.mode == 'burst') ...burst(),
                          if (widget.mode == 'pyramid') ...pyramid(),
                          if (widget.mode == 'matching') ...matching(),
                        ],
                        if (run['phase'] == 'active')
                          Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            children: [
                              TextButton(
                                onPressed: busy || offline
                                    ? null
                                    : () => act(
                                        run['paused'] == true
                                            ? 'resume'
                                            : 'pause',
                                      ),
                                child: Text(
                                  run['paused'] == true
                                      ? 'Devam et'
                                      : 'Duraklat',
                                ),
                              ),
                              TextButton(
                                onPressed: busy || offline ? null : finish,
                                child: const Text('Oyunu bitir'),
                              ),
                            ],
                          ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget panel(String heading, String body, {Widget? child}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: PitchPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(heading, style: Theme.of(context).textTheme.headlineSmall),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              body,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: palette.muted),
            ),
          ],
          if (child != null) child,
        ],
      ),
    ),
  );
  Widget button(String text, VoidCallback onPressed) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: FilledButton(
      onPressed: busy || offline ? null : onPressed,
      child: Text(text, textAlign: TextAlign.center),
    ),
  );
  Widget choices(
    String label,
    String current,
    Map<String, String> options,
    ValueChanged<String> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: HubSegmented<String>(
      label: label,
      options: options,
      value: current,
      onChanged: busy ? null : (v) => setState(() => change(v)),
    ),
  );
  List<Widget> setup() => [
    if (widget.mode == 'burst') ...[
      panel(
        'Üç isim. Bir ortak bağ.',
        'Her turda 3 farklı futbolcu bul. Doğru cevap 100 puan; seriyle en fazla ×2. Tur bonusu +50.',
      ),
      choices('Oyun tarzı', style, {
        'speed': 'Hız Atağı',
        'survival': 'Dayanıklılık',
      }, (v) => style = v),
      choices('Eşleşme', pairType, {
        'clubClub': 'Kulüp × Kulüp',
        'clubCountry': 'Kulüp × Ülke',
      }, (v) => pairType = v),
      HubSpecNote(
        style == 'speed'
            ? 'Toplam 120 sn · Tur 30 sn · Yanlış −3 sn\n2 pas: her biri −5 sn · İpucu yok\nKolay çiftlerle başlar, turlar ilerledikçe zorlaşır'
            : '5 can · 12 tamamlanan tur · 2 pas · Tur 75 sn (dolarsa −1 can)\nİpucu önce milliyeti, ikincisi baş harfleri söyler\nDuraklatınca çift gizlenir\nReklam ipuçları diğer solo modlarla ortak 4/gün sınırına tabidir.',
      ),
    ] else ...[
      panel(
        widget.mode == 'pyramid'
            ? 'Bağları kur, zirveye ulaş.'
            : 'Hatırla. Eşleştir. Tamamla.',
        widget.mode == 'pyramid'
            ? 'Her boş hücre iki alt desteğe bağlanmalı. Zirvenin altındaki iki hücre zirveye de bağlanır. Tek bir gizli cevap yok; kalan çözümü koruyan adaylar kabul edilir.'
            : 'Tüm kartlar kapalı başlar. Bir oyuncuyu oynadığı kulüple eşleştir. Yanlış çift 1 saniye açık kalır. En az hamleyle tamamla; süre yalnızca eşitlik bozucudur.',
      ),
      choices('Zorluk', difficulty, {
        'easy': 'Kolay',
        'normal': 'Normal',
        'hard': 'Zor',
      }, (v) => difficulty = v),
      HubSpecNote(
        widget.mode == 'pyramid'
            ? '${difficulty == 'easy' ? '10 hücre · 5 boş' : '15 hücre · 9 boş'} · 5 can\n${difficulty == 'hard' ? 1 : 2} ipucu: ilki türü, aynı hücreye ikincisi bağı söyler · Süre sınırı yok\n${difficulty == 'hard' ? 'Zor tahtalarda her hücreye uyan aday daha az. ' : ''}Bağlı ama tahtayı çözümsüz bırakan aday da yanlış sayılır.\nZafer bonusu: kalan can × 100, ipucusuz +200, her geri alma −50'
            : '${{'easy': 6, 'normal': 8, 'hard': 12}[difficulty]} çift · ${difficulty == 'easy' ? 3 : 4} sütun · Geri sayım yok\n3 yıldız: en fazla ${({'easy': 6, 'normal': 8, 'hard': 12}[difficulty]! * 1.75).floor()} hamle · 2 yıldız: en fazla ${({'easy': 6, 'normal': 8, 'hard': 12}[difficulty]! * 2.5).floor()}\nÜcretsiz ipucu yok; destek ürünün varsa oyun başına bir çift önerisi açılır.\nDuraklatılan oyun süre rekoru sayılmaz.',
      ),
    ],
    const SizedBox(height: 12),
    ExpansionTile(
      title: const Text('Başarılar ve günlük görev'),
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            widget.mode == 'burst'
                ? style == 'speed'
                      ? '2 / 3 / 5 tur: her derece 2 Coin + 4 XP. 7 turu en fazla 1 yanlışla ve passız bitir: Ustalık 3 Coin + 6 XP. Günde bir kez 2 tur: 2 Coin + 4 XP.'
                      : '3 / 6 / 9 tur: her derece 2 Coin + 4 XP. 12 turu ipucu ve pas olmadan, en az 3 canla bitir: Ustalık 3 Coin + 6 XP. Günde bir kez 3 tur: 2 Coin + 4 XP.'
                : widget.mode == 'pyramid'
                ? 'Kolay 2, Normal 2, Zor 3 Coin. Zor tahtayı yanlış, ipucu ve geri alma olmadan bitir: Ustalık 3 Coin. XP, Coin’in iki katıdır. Normal veya Zor zafer: Matching ile ortak günde bir kez 2 Coin + 4 XP.'
                : 'Kolay 1, Normal 2, Zor 2 Coin. Zor tahtayı en fazla 18 hamlede bitir: Ustalık 3 Coin. XP, Coin’in iki katıdır. Normal veya Zor zafer: Pyramid ile ortak günde bir kez 2 Coin + 4 XP.',
          ),
        ),
        const Padding(
          padding: EdgeInsets.all(12),
          child: Text(
            'Başarı ödülleri hesap başına bir kez verilir. Günlük görevler ortak görev sınırına tabidir.',
          ),
        ),
      ],
    ),
    Text(
      data['linked'] == true
          ? 'Yeni oyun: ${data['energyCost'] ?? 0} enerji · Kayıtlı oyuna devam: ücretsiz'
          : 'Konuk alıştırması · Enerji ve Coin ödülü yok',
    ),
    if (rewardMap(data['availability'])['enabled'] == true) ...[
      button('Oyunu hazırla', prepare),
      if (widget.mode != 'burst') ...[
        OutlinedButton.icon(
          onPressed: busy ? null : () => prepare(daily: true),
          icon: const Icon(Icons.today_outlined),
          label: Text(
            widget.mode == 'pyramid' ? 'Günün piramidi' : 'Günün kartları',
          ),
        ),
        Text(
          widget.mode == 'pyramid'
              ? 'Herkes bugün aynı normal tahtayı çözer. Henüz oynamadığın tahtalar önce gelir.'
              : 'Herkes bugün aynı normal kart dizilimini çözer. Sonucu paylaşabilirsin.',
        ),
      ],
    ] else
      panel(
        'Güncelleme hazırlanıyor',
        'Bu mod henüz açılmadı. Rekorların korunuyor.',
      ),
  ];
  List<Widget> message() => [
    if ('${run['message'] ?? ''}'.isNotEmpty)
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text('${run['message']}', style: TextStyle(color: accent)),
      ),
    if ('${run['hint'] ?? ''}'.isNotEmpty) panel('İpucu', '${run['hint']}'),
  ];
  Widget input() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        controller: answer,
        maxLength: 120,
        enabled: !busy && !offline,
        onChanged: search,
        decoration: InputDecoration(
          labelText: 'Ad yaz veya öneriden seç',
          hintText: 'En az 2 harf',
          prefixIcon: const Icon(Icons.search_rounded),
          filled: true,
          fillColor: palette.background,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => submit(),
      ),
      for (final item in suggestions)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Material(
            color: palette.raised,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: palette.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: ListTile(
              dense: true,
              minVerticalPadding: 10,
              leading: item['type'] == 'club' || item['type'] == 'country'
                  ? CriterionMark(
                      ArenaCriterion({
                        'label': '${item['name']}',
                        'type': '${item['type']}',
                      }),
                      size: 28,
                    )
                  : ArenaPlayerAvatar(
                      id: item['playerId'] ?? item['id'],
                      name: '${item['name']}',
                      size: 32,
                    ),
              title: Text('${item['name']}'),
              subtitle: Text(
                item['type'] == 'club'
                    ? 'Kulüp'
                    : item['type'] == 'country'
                    ? 'Ülke'
                    : '${item['country'] ?? 'Oyuncu'}',
              ),
              onTap: busy ? null : () => submit(entityId: '${item['id']}'),
            ),
          ),
        ),
      const SizedBox(height: 4),
      ArenaPrimaryButton(
        label: 'Cevabı kontrol et',
        icon: Icons.bolt_rounded,
        onPressed: busy || offline ? null : submit,
      ),
      const SizedBox(height: 12),
    ],
  );
  void submit({String? entityId}) {
    if (widget.mode == 'pyramid' && slotId == null) {
      setState(() => error = 'Önce iki alt desteği dolu bir boş hücre seç.');
      return;
    }
    unawaited(
      act('answer', {
        'query': answer.text,
        if (entityId != null) 'entityId': entityId,
        if (slotId != null) 'slotId': slotId,
      }),
    );
  }

  String get subtitle => switch (widget.mode) {
    'burst' => run['style'] == 'survival'
        ? 'Dayanıklılık · ortak oyuncu serisi'
        : 'Hız atağı · ortak oyuncu serisi',
    'pyramid' => 'Zincir tırmanışı · zirveye bağla',
    _ => 'Hafıza · oyuncuyu kulübüyle eşleştir',
  };
  String? get tag => run.isEmpty || run['finished'] == true
      ? null
      : upperTr(_difficulty('${run['difficulty'] ?? rewardMap(run['question'])['difficulty'] ?? ''}'));

  Widget _stat(String label, Widget value) => Expanded(
    child: Column(
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: palette.muted,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        DefaultTextStyle.merge(
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w900,
          ),
          child: value,
        ),
      ],
    ),
  );

  List<Widget> burst() {
    final speed = run['style'] == 'speed';
    final q = rewardMap(run['question']);
    final text = Theme.of(context).textTheme;
    final found = _rows(run['found']);
    final country = '${run['pairType'] ?? q['id'] ?? ''}'.toLowerCase().contains('country');
    int seconds(String key) =>
        (math.max(0, _n(run[key]) - delta) / 1000).ceil();
    Widget side(String name, String type) => Expanded(
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: palette.raised,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: palette.border),
            ),
            child: CriterionMark(
              ArenaCriterion({'label': name, 'type': type}),
              size: 44,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
    Widget slot(Widget leading, String title, String body, Color color, {bool done = false}) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: done ? color.withValues(alpha: .08) : palette.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: done ? color.withValues(alpha: .5) : palette.border,
          ),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: text.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(body, style: text.bodySmall?.copyWith(color: palette.muted)),
                ],
              ),
            ),
            if (done) Icon(Icons.verified_rounded, color: color),
          ],
        ),
      ),
    );
    return [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          ArenaPill(
            filled: true,
            color: Arena.lime,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.local_fire_department_rounded, size: 16, color: Arena.lime),
                const SizedBox(width: 4),
                Text('SERİ ${run['streak']}'),
              ],
            ),
          ),
          ArenaPill(child: Text('${run['score']} PUAN')),
          ArenaPill(child: Text('${run['rounds']} tur')),
          if (!speed) ArenaPill(dot: hubAmber(context), child: Text('♥ ${run['lives']}')),
        ],
      ),
      const SizedBox(height: 12),
      ArenaCard(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              spacing: 12,
              runSpacing: 4,
              children: [
                Text(
                  speed
                      ? 'Toplam ${seconds('totalRemainingMs')} sn'
                      : 'Hedef 12 tur',
                  style: text.labelLarge?.copyWith(color: palette.muted),
                ),
                Text(
                  'Tur ${seconds('roundRemainingMs')} sn',
                  style: text.labelLarge?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Round clock: turns amber in the last third.
            Builder(
              builder: (context) {
                final left = math.max(0, _n(run['roundRemainingMs']) - delta);
                final total = math.max(1, _n(run['roundMs'] ?? 30000));
                final part = (left / total).clamp(0.0, 1.0);
                return Semantics(
                  label: 'Tur süresi ${(left / 1000).ceil()} saniye',
                  excludeSemantics: true,
                  child: LinearProgressIndicator(
                    value: part,
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                    backgroundColor: palette.border,
                    color: part < 1 / 3 ? hubAmber(context) : Arena.lime,
                  ),
                );
              },
            ),
          ],
        ),
      ),
      const SizedBox(height: 12),
      ArenaCard(
        glow: accent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'ORTAK OYUNCU',
                    style: text.labelLarge?.copyWith(
                      color: accent,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                ArenaPill(
                  filled: true,
                  color: Arena.lime,
                  child: Text('${found.length}/3 bulundu'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Semantics(
              label: '${q['left']} × ${q['right']}',
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  side('${q['left'] ?? ''}', 'club'),
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: accent.withValues(alpha: .5)),
                          ),
                          child: Icon(Icons.close_rounded, color: accent, size: 20),
                        ),
                        const SizedBox(height: 4),
                        Text('ORTAK', style: text.labelSmall?.copyWith(color: palette.muted)),
                      ],
                    ),
                  ),
                  side('${q['right'] ?? ''}', country ? 'country' : 'club'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${found.length}/3 oyuncu · ${_difficulty('${q['difficulty']}')}',
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
      ArenaSection(
        'Bulunacaklar (3)',
        icon: Icons.people_alt_outlined,
        trailing: Text(
          '${math.max(0, 3 - found.length)} oyuncu kaldı',
          style: text.labelSmall?.copyWith(color: accent),
        ),
      ),
      for (final x in found)
        slot(
          ArenaPlayerAvatar(id: x['id'], name: '${x['name']}', size: 44, ring: palette.success),
          '${x['name']}',
          'Bulundu',
          palette.success,
          done: true,
        ),
      for (var i = found.length; i < 3; i++)
        slot(
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: palette.raised,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.help_outline_rounded, color: palette.muted),
          ),
          '${i + 1}. oyuncu bekleniyor',
          country
              ? 'Kulüpte oynamış ve bu ülkeden bir futbolcu yaz'
              : 'Her iki kulüpte oynamış bir futbolcu yaz',
          accent,
        ),
      ...message(),
      input(),
      Wrap(
        spacing: 10,
        runSpacing: 8,
        children: [
          OutlinedButton.icon(
            icon: const Icon(Icons.fast_forward_rounded, size: 18),
            onPressed: busy || offline || _n(run['passes']) >= 2
                ? null
                : () => act('pass'),
            label: Text(
              'Pas (${2 - _n(run['passes'])})${speed ? ' · −5 sn' : ''}',
            ),
          ),
          if (hintEntry(run, disabled: busy || offline || local, send: (p) => act('hint', p),
              watch: (id) => adHint(itemId: id)) case final w? when !speed)
            w
          else if (!speed && rewardMap(run['support'])['version'] == 1)
            PaidHintButton(
              session: run,
              sku: 'boost_basic',
              label: 'Ek bilgi',
              disabled: busy || offline || local,
              onUse: (payment) => act('hint', payment),
              onWatch: () => adHint(boostId: 'boost_basic'),
            )
          else if (!speed)
            OutlinedButton(
              onPressed:
                  busy ||
                      offline ||
                      run['freeUsed'] == true && _n(run['adCredits']) == 0
                  ? null
                  : () => act('hint'),
              child: Text(
                run['freeUsed'] == true
                    ? 'İpucu (${run['adCredits']})'
                    : 'Ücretsiz ipucu',
              ),
            ),
          if (!speed &&
              rewardMap(run['support'])['version'] != 1 &&
              _n(run['adGranted']) < 2)
            TextButton(
              onPressed: busy || offline || local ? null : adHint,
              child: const Text('Reklamla ipucu'),
            ),
        ],
      ),
    ];
  }

  /// One pyramid cell: a player (portrait), club (mark) or country (flag), or an
  /// open, selectable or locked slot.
  Widget _pyramidCell({
    required String id,
    required Map<String, dynamic> entity,
    required bool start,
    required bool top,
    required bool selected,
    required bool linked,
    required bool available,
    required VoidCallback? onTap,
  }) {
    final text = Theme.of(context).textTheme;
    final solved = entity.isNotEmpty && !start;
    final (Color edge, Color fill) = selected
        ? (Arena.lime, palette.limeTint)
        : top && entity.isNotEmpty
        ? (accent, palette.tint)
        : solved
        ? (palette.success, palette.success.withValues(alpha: .1))
        : linked
        ? (accent, palette.surface)
        : available
        ? (accent.withValues(alpha: .6), palette.surface)
        : (palette.border, entity.isEmpty ? palette.background : palette.surface);
    final type = '${entity['type'] ?? ''}';
    Widget mark() => type == 'player'
        ? ArenaPlayerAvatar(
            id: entity['playerId'],
            name: '${entity['name']}',
            size: 34,
            ring: solved ? palette.success : accent,
          )
        : CriterionMark(
            ArenaCriterion({
              'label': '${entity['name']}',
              'type': type == 'country' ? 'country' : 'club',
            }),
            size: 28,
          );
    final children = entity.isNotEmpty
        ? <Widget>[
            mark(),
            const SizedBox(height: 4),
            Text(
              '${entity['name']}',
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: text.labelMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            if (solved)
              Text(
                'Çözüldü',
                style: text.labelSmall?.copyWith(color: palette.success),
              ),
          ]
        : <Widget>[
            Icon(
              selected
                  ? Icons.edit_rounded
                  : available
                  ? Icons.add_rounded
                  : Icons.lock_outline_rounded,
              size: 20,
              color: selected
                  ? Arena.lime
                  : available
                  ? accent
                  : palette.muted,
            ),
            const SizedBox(height: 2),
            Text(
              selected
                  ? 'Aktif seçim'
                  : available
                  ? 'Seç'
                  : 'Kilitli',
              style: text.labelSmall?.copyWith(
                color: selected ? Arena.lime : palette.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ];
    return Material(
      color: fill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: edge, width: selected || linked ? 1.8 : 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 84, minWidth: 48),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: children,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> pyramid() {
    final board = rewardMap(run['board']);
    final filled = rewardMap(run['filled']);
    final slots = _rows(board['slots']);
    final selected = slots.where((s) => '${s['id']}' == slotId).firstOrNull;
    final highlighted = (selected?['supports'] as List? ?? [])
        .map((x) => '$x')
        .toSet();
    if (selected?['row'] == 1) highlighted.add('0');
    // A five-level board fits a phone; only large text needs side scrolling.
    final boardWidth = math.max(
      math.min(MediaQuery.sizeOf(context).width, 640.0) - 32,
      _n(board['levels']) * 70.0 * MediaQuery.textScalerOf(context).scale(1),
    );
    pyramidScroll ??= ScrollController(
      initialScrollOffset: math.max(
        0,
        (boardWidth -
                (math.min(MediaQuery.sizeOf(context).width, 640.0) - 32)) /
            2,
      ),
    );
    final initial = (board['initial'] as List? ?? []).map((x) => '$x').toSet();
    final cells = _n(board['cells'] ?? (_n(board['levels']) == 4 ? 5 : 9));
    return [
      ArenaCard(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          children: [
            _stat(
              'CAN',
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.favorite_rounded, size: 18, color: palette.error),
                  const SizedBox(width: 4),
                  Text('${run['lives']}'),
                ],
              ),
            ),
            _stat('HÜCRE', Text('${run['correct']}/$cells')),
            _stat(
              'PUAN',
              Text('${run['score'] ?? 0}', style: const TextStyle(color: Arena.lime)),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      if (boardWidth > math.min(MediaQuery.sizeOf(context).width, 640.0) - 32)
        const Text('Tüm hücreleri görmek için tahtayı yatay kaydırabilirsin.'),
      SingleChildScrollView(
        controller: pyramidScroll,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: boardWidth,
          child: Column(
            children: [
              for (var row = 0; row < _n(board['levels']); row++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: slots.where((s) => s['row'] == row).map((s) {
                      final id = '${s['id']}';
                      final entity = rewardMap(filled[id]);
                      final supports = (s['supports'] as List? ?? []).map(
                        (x) => '$x',
                      );
                      final available =
                          entity.isEmpty &&
                          supports.length == 2 &&
                          supports.every(filled.containsKey);
                      return Flexible(
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth:
                                135 * MediaQuery.textScalerOf(context).scale(1),
                            minWidth: 48,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Semantics(
                              label: entity.isEmpty
                                  ? 'Boş hücre ${_n(s['id']) + 1}${available ? ', seçilebilir' : ', alt destekleri doldur'}'
                                  : '${entity['name']}',
                              button: available,
                              child: _pyramidCell(
                                id: id,
                                entity: entity,
                                start: initial.contains(id),
                                top: s['row'] == 0,
                                selected: id == slotId,
                                linked: highlighted.contains(id),
                                available: available,
                                onTap: !busy && !offline && available
                                    ? () => setState(() {
                                        slotId = id;
                                        error = null;
                                      })
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
            ],
          ),
        ),
      ),
      if (selected != null)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: ArenaNote(
            icon: Icons.hub_outlined,
            text:
                'Aktif görev: ${highlighted.map((id) => rewardMap(filled[id])['name']).join(' & ')} bağlantısını bul',
          ),
        ),
      ...message(),
      input(),
      Wrap(
        spacing: 10,
        children: [
          if (hintEntry(run, target: slotId, disabled: busy || offline || slotId == null,
              send: (p) => act('hint', {'slotId': slotId, ...p})) case final w?)
            w
          else if (rewardMap(run['support'])['version'] == 1)
            PaidHintButton(
              session: run,
              sku: 'boost_strong',
              label: 'Bağlantı ipucu',
              disabled:
                  busy ||
                  offline ||
                  slotId == null ||
                  _n(run['hints']) >= (run['difficulty'] == 'hard' ? 1 : 2),
              onUse: (payment) => act('hint', {'slotId': slotId, ...payment}),
            )
          else
            OutlinedButton(
              onPressed:
                  busy ||
                      offline ||
                      slotId == null ||
                      _n(run['hints']) >= (run['difficulty'] == 'hard' ? 1 : 2)
                  ? null
                  : () => act('hint', {'slotId': slotId}),
              child: Text(
                'İpucu (${(run['difficulty'] == 'hard' ? 1 : 2) - _n(run['hints'])})',
              ),
            ),
          TextButton(
            onPressed: busy || offline || run['canUndo'] != true
                ? null
                : () => act('undo'),
            child: const Text('Son hücreyi geri al'),
          ),
        ],
      ),
    ];
  }

  List<Widget> matching() {
    final board = rewardMap(run['board']);
    final cards = _rows(board['cards']);
    final suggested = _rows(
      rewardMap(run['matchingHint'])['cards'],
    ).map((c) => '${c['id']}').toSet();
    final locked =
        _n(run['lockUntil']) >
        _n(run['serverNow']) + elapsed.elapsedMilliseconds;
    final seconds = ((_n(run['activeMs']) + delta) / 1000).floor();
    final columns = run['difficulty'] == 'easy' ? 3 : 4;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final availableWidth =
        math.min(MediaQuery.sizeOf(context).width, 640.0) - 32;
    final boardWidth = scale > 1.3
        ? math.max(availableWidth, columns * 100.0 * scale + (columns - 1) * 8)
        : availableWidth;
    return [
      Text(
        '${run['moves']} hamle · ${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')} · ${run['correct']}/${board['count']} çift',
        style: TextStyle(color: accent),
      ),
      const SizedBox(height: 12),
      if (hintEntry(run, disabled: busy || offline || locked || (run['open'] as List? ?? []).isNotEmpty,
          send: (p) => act('hint', p)) case final w?)
        w
      else if (rewardMap(run['support'])['version'] == 1) ...[
        PaidHintButton(
          session: run,
          sku: 'boost_strong',
          label: 'Tek çift önerisi',
          disabled:
              busy ||
              offline ||
              locked ||
              (run['open'] as List? ?? []).isNotEmpty ||
              _n(run['hints']) >= 1,
          onUse: (payment) => act('hint', payment),
        ),
        const Text('Oyun başına bir öneri. Yardımlı rekor ayrı tutulur.'),
      ],
      if (suggested.isNotEmpty) panel('Önerilen çift', '${run['hint'] ?? ''}'),
      if (locked)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: Text('Kartları hatırla…'),
        ),
      if (boardWidth > availableWidth)
        const Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Text('Kartları görmek için tahtayı yatay kaydırabilirsin.'),
        ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: boardWidth,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: cards.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: columns,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              mainAxisExtent: math.max(
                112,
                112 * MediaQuery.textScalerOf(context).scale(1),
              ),
            ),
            itemBuilder: (context, i) {
              final c = cards[i];
              final visible = c['visible'] == true;
              // Hidden cards have no face text, image, tooltip or semantic identity.
              return Semantics(
                label:
                    '${visible ? '${c['name']}${c['matched'] == true ? ', eşleşti' : ''}' : 'Kapalı kart ${i + 1}'}${suggested.contains(c['id']) ? ', önerilen çift' : ''}',
                button: !visible,
                child: ExcludeSemantics(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.all(6),
                      backgroundColor: visible
                          ? palette.surface
                          : palette.raised,
                      side: BorderSide(
                        color:
                            c['matched'] == true || suggested.contains(c['id'])
                            ? accent
                            : palette.border,
                        width: suggested.contains(c['id']) ? 2 : 1,
                      ),
                    ),
                    onPressed: busy || offline || locked || visible
                        ? null
                        : () => act('flip', {'cardId': c['id']}),
                    child: visible
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                c['type'] == 'club'
                                    ? Icons.shield_outlined
                                    : Icons.person_outline,
                                color: accent,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${c['name']}',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: palette.text,
                                ),
                              ),
                            ],
                          )
                        : Icon(Icons.sports_soccer, color: palette.muted),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    ];
  }

  List<Widget> result() => [
    Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: HubResultCard(
        tone: run['won'] == true ? HubResultTone.win : HubResultTone.neutral,
        icon: run['won'] == true
            ? Icons.emoji_events_rounded
            : Icons.flag_rounded,
        kicker: run['won'] == true ? 'Tamamlandı' : 'Oyun sonucu',
        title: widget.mode == 'matching'
            ? '${run['moves']} hamle'
            : '${run['score']} puan',
        subtitle: '${run['reason'] ?? ''}'.isEmpty ? null : '${run['reason']}',
        coins: _n(run['earnedCoins']),
        xp: _n(run['earnedCoins']) * 2,
        notes: [
          widget.mode == 'matching'
              ? '${(_n(run['activeMs']) / 1000).round()} sn · ${'★' * _n(run['stars'])}${'☆' * (3 - _n(run['stars'])).clamp(0, 3)}${run['daily'] != null ? ' · Günün kartları' : ''}'
              : '${run['correct']} doğru · ${_n(run['wrong'])} yanlış · ${_n(run['hints'])} ipucu'
                    '${widget.mode == 'burst' ? ' · ${run['rounds']} tur · ${_n(run['passes'])} pas' : ''}'
                    '${widget.mode == 'pyramid' ? ' · ${_n(run['undos'])} geri alma' : ''}',
          if (widget.mode == 'pyramid' &&
              run['won'] == true &&
              run['bonus'] != null)
            'Zafer bonusu +${_n(run['bonus'])}: ${_n(run['lives'])} can${_n(run['hints']) == 0 ? ', ipucusuz' : ''}${_n(run['undos']) > 0 ? ', ${_n(run['undos'])} geri alma' : ''}',
          if (run['assisted'] == true)
            'Yardımlı sonuç · Yardımsız rekor ve ustalığa eklenmez.',
          if (run['pendingValidation'] == true)
            'Sonuç doğrulama bekliyor. Yenile ile eşitle.',
          if (run['practice'] == true) 'Konuk alıştırması',
          _n(data['pendingCoins']) > 0
              ? 'Ödül ödemesi bekliyor; Yenile ile eşitle.'
              : rewardMap(data['availability'])['rewardsEnabled'] == true
              ? 'Ödül durumu hesabında kayıtlı.'
              : 'Bu sürümde ödüller henüz açılmadı.',
        ],
      ),
    ),
    if (widget.mode == 'burst')
      for (final h in _rows(run['history']))
        ExpansionTile(
          title: Text('${h['title']}'),
          subtitle: const Text('Bulamadığın geçerli oyuncular'),
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text((h['missed'] as List? ?? []).join(' • ')),
            ),
          ],
        ),
    if (widget.mode == 'pyramid') ShareResultButtons(text: pyramidShare(run)),
    if (widget.mode == 'matching' && run['won'] == true) ...[
      if (_n(run['pauses']) > 0)
        const Padding(
          padding: EdgeInsets.only(bottom: 8),
          child: HubSpecNote(
            'Oyun duraklatıldığı için süre rekoru sayılmadı; hamle rekoru geçerli.',
          ),
        ),
      ShareResultButtons(text: matchingShare(run)),
    ],
    if (widget.mode == 'pyramid')
      ExpansionTile(
        title: const Text('Doğrulanmış çözüm'),
        children: [
          ...rewardMap(run['solution']).entries.map(
            (e) => ListTile(
              title: Text(
                'Hücre ${int.parse(e.key) + 1}: ${rewardMap(e.value)['name']}',
              ),
            ),
          ),
          ..._rows(run['solutionProof']).map(
            (p) => ListTile(
              title: Text('Hücre ${_n(p['from']) + 1} → ${_n(p['to']) + 1}'),
              subtitle: Text('${p['evidence']}'),
            ),
          ),
        ],
      ),
    if (widget.mode == 'matching')
      ExpansionTile(
        title: const Text('Kariyer bağları ve kaynaklar'),
        children: _rows(run['proof'])
            .map(
              (p) => ListTile(
                title: Text('${p['player']} → ${p['club']}'),
                subtitle: SelectableText(
                  (p['sources'] as List? ?? []).join('\n'),
                ),
              ),
            )
            .toList(),
      ),
    button('Tekrar oyna', () {
      setState(() {
        style = '${run['style'] ?? 'speed'}';
        pairType = '${run['pairType'] ?? 'clubClub'}';
        difficulty = '${run['difficulty'] ?? 'normal'}';
      });
      unawaited(prepare());
    }),
    TextButton(
      onPressed: () => Navigator.of(context).maybePop(),
      child: const Text('Ana sayfa'),
    ),
    const Text('Yeni seçim için aşağıdaki ayarları değiştirebilirsin.'),
    const Divider(height: 32),
  ];
  String _medalLabel(String key) {
    const labels = {
      'burst': 'Burst',
      'pyramid': 'Pyramid',
      'matching': 'Matching',
      'speed': 'Hız Atağı',
      'survival': 'Dayanıklılık',
      'bronze': 'Bronz',
      'silver': 'Gümüş',
      'gold': 'Altın',
      'master': 'Ustalık',
      'easy': 'Bronz',
      'normal': 'Gümüş',
      'hard': 'Altın',
    };
    return key
        .split(':')
        .where((p) => p != 'v1')
        .map((p) => labels[p] ?? p)
        .join(' · ');
  }

  List<Widget> records() {
    final records = rewardMap(data['records']).entries
        .map(
          (e) => {
            ...rewardMap(e.value),
            'assisted':
                rewardMap(e.value)['assisted'] == true ||
                e.key.endsWith('__assisted'),
          },
        )
        .where((r) => r['mode'] == widget.mode)
        .toList();
    return [
      panel(
        'Kişisel rekorların',
        widget.mode == 'burst'
            ? 'Hız Atağı ve Dayanıklılık; Kulüp × Kulüp ve Kulüp × Ülke için dört ayrı kayıt.'
            : 'Her zorluk için ayrı kayıt. Veriler hesabına ve içerik sürümüne bağlıdır.',
      ),
      if (records.isEmpty) const Text('Henüz tamamlanan oyun yok.'),
      for (final r in records)
        panel(
          '${widget.mode == 'burst' ? '${r['style'] == 'speed' ? 'Hız Atağı' : 'Dayanıklılık'} · ${r['pairType'] == 'clubClub' ? 'Kulüp × Kulüp' : 'Kulüp × Ülke'}' : _difficulty('${r['difficulty']}')}${r['assisted'] == true ? ' · Yardımlı' : ''}',
          widget.mode == 'matching'
              ? 'En az hamle: ${r['bestMoves'] ?? '—'}\nEn iyi süre: ${r['bestTimeMs'] == null ? '—' : (_n(r['bestTimeMs']) / 1000).round()} sn\n${r['sessions']} oyun'
              : 'En iyi skor: ${r['bestScore']}\n${widget.mode == 'burst' ? 'Tur: ${r['bestRounds']} · En uzun seri: ${r['bestStreak']}\n' : ''}Doğru: ${r['bestCorrect']} · ${r['sessions']} oyun${widget.mode == 'burst' ? '\nİpucusuz en iyi: ${r['bestNoHintScore'] ?? 0}${r['style'] == 'speed' && r['bestAverageAnswerMs'] != null ? '\nEn hızlı ortalama yanıt: ${(_n(r['bestAverageAnswerMs']) / 1000).toStringAsFixed(1)} sn' : ''}${r['style'] == 'survival' && r['bestLives'] != null ? '\nEn çok kalan can: ${r['bestLives']}' : ''}' : ''}',
        ),
      if (rewardMap(data['legacy']).isNotEmpty)
        panel(
          'Bu cihazın eski sürüm rekoru',
          rewardMap(
            data['legacy'],
          ).entries.map((e) => '${e.key}: ${e.value}').join('\n'),
        ),
      for (final e in rewardMap(
        data['medals'],
      ).entries.where((e) => e.key.startsWith(widget.mode)))
        ListTile(
          leading: Icon(Icons.military_tech, color: accent),
          title: Text(_medalLabel(e.key)),
          subtitle: Text(
            '${rewardMap(e.value)['coins']} Coin · ${rewardMap(data['paid'])[e.key] == true ? 'Ödendi' : 'Bekliyor'}',
          ),
        ),
      if (_rows(data['recent']).isNotEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Text('Son oyunlar'),
        ),
      for (final r in _rows(data['recent']))
        ListTile(
          title: Text(
            widget.mode == 'matching'
                ? '${r['moves']} hamle'
                : '${r['score']} puan',
          ),
          subtitle: Text(
            '${r['style'] == 'survival' && widget.mode == 'burst'
                ? 'Dayanıklılık'
                : widget.mode == 'burst'
                ? 'Hız Atağı'
                : _difficulty('${r['difficulty']}')} · ${(_n(r['activeMs']) / 1000).round()} sn${r['assisted'] == true ? ' · Yardımlı' : ''}',
          ),
        ),
    ];
  }
}

/// Share card for a finished pyramid: score and lives, never the cells.
String pyramidShare(Map<String, dynamic> run) {
  int n(Object? v) => (v as num?)?.toInt() ?? 0;
  final day = '${run['daily'] ?? ''}'.split('-').reversed.join('.');
  final level =
      {'easy': 'Kolay', 'normal': 'Normal', 'hard': 'Zor'}[run['difficulty']] ??
      '';
  return [
    'Linkball · Bağlantı Piramidi${level.isEmpty ? '' : ' · $level'}',
    if (run['daily'] != null) 'Günün piramidi · $day',
    run['won'] == true
        ? '🔺 Tamamlandı · ${n(run['score'])} puan'
        : '🧱 ${n(run['correct'])} hücre · ${n(run['score'])} puan',
    '${'❤️' * n(run['lives']).clamp(0, 5)}${'🖤' * (5 - n(run['lives'])).clamp(0, 5)} · ${n(run['hints'])} ipucu · ${n(run['undos'])} geri alma',
  ].join('\n');
}

/// Share card for a finished matching board: moves and stars, no cards.
String matchingShare(Map<String, dynamic> run) {
  int n(Object? v) => (v as num?)?.toInt() ?? 0;
  final day = '${run['daily'] ?? ''}'.split('-').reversed.join('.');
  final level =
      {'easy': 'Kolay', 'normal': 'Normal', 'hard': 'Zor'}[run['difficulty']] ??
      '';
  final pairs = n(rewardMap(run['board'])['count']);
  return [
    'Linkball · Kart Eşleştirme${level.isEmpty ? '' : ' · $level'}',
    if (run['daily'] != null) 'Günün kartları · $day',
    '${'⭐' * n(run['stars']).clamp(0, 3)}${'☆' * (3 - n(run['stars'])).clamp(0, 3)} · ${n(run['moves'])} hamle${pairs > 0 ? ' · $pairs çift' : ''}',
    '${(n(run['activeMs']) / 1000).round()} sn',
  ].join('\n');
}
