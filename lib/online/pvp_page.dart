import 'dart:async';
import 'dart:math' as math;
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/game_ui.dart';
import '../theme/ortak_saha_theme.dart';
import 'package:flutter/services.dart';
import '../models/rewarded_ad_models.dart';
import '../services/pvp_service.dart';
import '../widgets/player_portrait.dart';
import '../widgets/friend_match_invite_button.dart';
import 'online_mode_catalog.dart';

class PvpPage extends StatefulWidget {
  const PvpPage({super.key, required this.mode, required this.playKind, this.joinCode, this.service});
  final OnlinePlayMode mode;
  final String playKind;
  final String? joinCode;
  final PvpService? service;
  @override
  State<PvpPage> createState() => _PvpPageState();
}
class _PvpPageState extends State<PvpPage> {
  PitchColors get palette => PitchColors.of(context);
  Color get accent => palette.accent;
  late final PvpService service = widget.service ?? PvpService();
  Map<String,dynamic> data = {}, room = {};
  final code = TextEditingController(), query = TextEditingController();
  List<Map<String,dynamic>> results = [];
  Map<String,dynamic>? selected;
  String? target, criterion, error;
  String profile = 'standard', formation = '433';
  final Set<String> xi = {};
  double press = .5, tempo = .5, width = .5;
  bool busy = false, connected = true;
  Timer? poller, ticker;
  final clock = Stopwatch();
  int serverNow = 0, searchSerial = 0;
  bool get ranked => widget.playKind == 'ranked';
  String get mode => widget.mode.wireName;
  String get uid => '${room['myUid']}';
  bool get done => ['finished','cancelled','forfeit','expired'].contains(room['status']);
  List<Map<String,dynamic>> rows(dynamic value) => (value is List ? value : value is Map ? value.values.toList() : <dynamic>[]).map(rewardMap).toList();
  @override
  void initState() {super.initState(); load();
    poller = Timer.periodic(const Duration(seconds: 6), (_) {if (room.isNotEmpty && !busy && (!done || room['playKind'] == 'friend' || rewardMap(room['reward'])['status'] == 'pending')) action('poll');});
    ticker = Timer.periodic(const Duration(seconds: 1), (_) {if (mounted && room.isNotEmpty && !done) setState(() {});});
  }
  @override
  void dispose() {poller?.cancel(); ticker?.cancel(); code.dispose(); query.dispose(); super.dispose();}
  Future<void> run(Future<Map<String,dynamic>> Function() task) async {
    if (busy) return; setState(() {busy = true; error = null;});
    try {
      final response = await task(); if (!mounted) return;
      setState(() {connected = true;
        if (response['room'] != null) {final next = rewardMap(response['room']);
          if (next['id'] != room['id']) {xi.clear(); target = null; criterion = null; selected = null; results = []; query.clear();}
          room = next;
          final squad = rewardMap(room['mySquad']);
          if (squad.isNotEmpty) {
            xi..clear()..addAll((squad['playerIds'] as List).map((id) => '$id'));
            formation = '${squad['formation']}'; final t = rewardMap(squad['tactics']);
            press = (t['press'] as num).toDouble(); tempo = (t['tempo'] as num).toDouble(); width = (t['width'] as num).toDouble();
          }
          serverNow = (room['serverNow'] as num? ?? 0).toInt(); clock..reset()..start();}
        else {data = response;}
        final receipt = rewardMap(response['receipt']);
        if (receipt['correct'] == false) error = 'Bu futbolcu kriteri karşılamıyor.';
        if (receipt['accepted'] == true && receipt.containsKey('correct')) {selected = null; results = []; query.clear();}
      });
    } catch (e) {if (mounted) setState(() {error = '$e'.replaceFirst('Exception: ', ''); connected = !(e is FirebaseFunctionsException && ['unavailable','deadline-exceeded','internal','unknown'].contains(e.code));});}
    finally {if (mounted) setState(() => busy = false);}
  }
  Future<void> load() async {
    await run(() => service.load(mode));
    if (mounted && widget.joinCode != null && data.isNotEmpty) await enter('join', roomCode: widget.joinCode);
  }
  Future<void> enter(String action, {String? roomCode}) => run(() => service.enter(mode, widget.playKind, action,
    code: roomCode, profile: profile));
  Future<void> action(String action, [Map<String,dynamic> extra = const {}]) => run(() => service.act(room, action, extra));
  Future<void> search() async {
    final serial = ++searchSerial; final text = query.text.trim();
    if (text.length < 2) return;
    try {final found = await service.search(mode, text, roomId: room['id']);
      if (mounted && serial == searchSerial) setState(() {results = found; selected = null;});
    } catch (e) {if (mounted) setState(() => error = '$e');}
  }
  int seconds(dynamic deadline) => (((deadline as num? ?? 0).toInt() - serverNow - clock.elapsedMilliseconds) / 1000).ceil().clamp(0, 9999);
  Widget note(String text) => Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: Text(text,
    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: palette.muted)));
  Widget heading(String text) => Text(text, style: Theme.of(context).textTheme.headlineSmall);
  Widget panel(List<Widget> children) => Padding(padding: const EdgeInsets.only(bottom: 16),
    child: PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children)));
  Widget button(String text, VoidCallback? tap, {bool secondary = false}) => Padding(padding: const EdgeInsets.symmetric(vertical: 6),
    child: secondary ? OutlinedButton(onPressed: busy ? null : tap,child: Text(text,textAlign: TextAlign.center)) :
    FilledButton(onPressed: busy ? null : tap,child: Text(text,textAlign: TextAlign.center)));
  Widget choice(String label, String? value, List<Map<String,dynamic>> options, void Function(String) change, {bool enabled = true}) =>
    DropdownButtonFormField<String>(key: ValueKey('$label:$value'), initialValue: options.any((p) => p['id'] == value) ? value : null,
      isExpanded: true, decoration: InputDecoration(labelText: label),
      items: options.map((p) => DropdownMenuItem(value: '${p['id']}',child: Text('${p['label'] ?? p['name']}',maxLines: 2,overflow: TextOverflow.ellipsis))).toList(),
      onChanged: busy || !enabled ? null : (v) {if (v != null) change(v);});
  Widget setup() {
    final available = rewardMap(data['availability'])[ranked ? 'rankedEnabled' : 'friendEnabled'] == true;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch,children: [panel([
      heading(ranked ? 'Eşit koşullarda yarış' : 'Arkadaşınla karşılaş'), note(widget.mode.subtitle),
      note(ranked ? 'Aynı soru, aynı süre. Maç sonucu sunucuda doğrulanır.' : 'Oda koduyla katıl. Dostluk maçında Elo, Coin ve XP değişmez.'),
      if (!available) note(ranked ? 'Sıralamalı maç yakında. Bu mod henüz açılmadı.' : 'Arkadaş güncellemesi henüz kullanıma açılmadı.'),
      if (data['linked'] == false) note('Online maç için profilinden Google hesabını bağla.'),
      if (data['activeId'] != null && data['activePlayKind'] == widget.playKind) button('Kayıtlı maça devam et', () => enter('resume')),
      if (!ranked) ...[
        choice('Maç profili',profile,[{'id':'standard','label':'Tek maç'},{'id':'series3','label':'Üç maçlık seri'}],(v) => setState(() => profile = v)),
        const SizedBox(height: 12), button('Oda oluştur',available && data['linked'] == true ? () => enter('create') : null),
        TextField(controller: code,decoration: const InputDecoration(labelText: '8 karakterli oda kodu'),textCapitalization: TextCapitalization.characters,maxLength: 8),
        button('Koda katıl',available && data['linked'] == true ? () => enter('join',roomCode: code.text.trim().toUpperCase()) : null,secondary: true),
      ] else button('Rakip ara',available && data['linked'] == true ? () => enter('search') : null),
    ]), if (rows(data['history']).isNotEmpty) panel([heading('Son maçların'),
      ...rows(data['history']).where((r) => r['playKind'] == widget.playKind).map((r) => ListTile(contentPadding: EdgeInsets.zero,
        onTap: () => run(() => service.act({...r,'revision':0},'poll')),
        title: Text('${r['status'] == 'finished' ? 'Tamamlandı' : 'Sonlandırıldı'} · ${r['id']}'),
        subtitle: Text(rewardMap(r['scores']).values.join(' – '))))]),
    ]);
  }
  Widget lobby() {
    final host = room['host'] == uid; final ready = rewardMap(room['ready']); final choices = rewardMap(room['choices']);
    return panel([heading(room['status'] == 'waiting' ? ranked ? 'Rakip aranıyor' : 'Arkadaşını bekliyorsun' : 'Maça hazırlan'),
      if (!ranked) ...[SelectableText('${room['id']}',style: TextStyle(fontSize: 28,color: accent,letterSpacing: 3)),
        button('Oda kodunu kopyala',() => Clipboard.setData(ClipboardData(text:'${room['id']}')),secondary: true),
        if (host && room['guest'] == null) FriendMatchInviteButton(mode: widget.mode,roomCode:'${room['id']}')],
      note(ranked ? '30 saniye içinde rakip bulunamazsa arama kapanır.' : 'İki oyuncu da hazır olduğunda beş saniyelik geri sayım başlar.'),
      ...rewardMap(room['names']).entries.map((e) => note('${e.value} · ${ready[e.key] == true ? 'Hazır' : 'Bekliyor'}')),
      if (room['status'] == 'ready') ...[
        if (!ranked && ['club_club','club_country'].contains(mode)) ...[
          choice(host || mode == 'club_club' ? 'Kulübünü seç' : 'Ülkeni seç',choices[host ? 'left' : 'right'],
            rows(data[!host && mode == 'club_country' ? 'countries' : 'clubs']), (v) => action('choose',{'choice':v})),
          note('Eşleşmede en az 8 ortak futbolcu bulunmalı.')],
        button(ready[uid] == true ? 'Rakibin hazırlanıyor' : 'Hazırım',ready[uid] == true ? null : () => action('ready')),
      ], button('Aramayı / odayı iptal et',() => action('leave'),secondary: true)]);
  }
  Widget hud() {
    final names = rewardMap(room['names']), scores = rewardMap(room['scores']);
    final turn = room['turnUid']; final turnMode = ['grid_classic','grid_reverse','cinko'].contains(mode);
    return panel([Wrap(spacing: 16,runSpacing: 8,children: names.entries.map((e) => Text('${e.value}: ${scores[e.key] ?? 0}',
      style: const TextStyle(fontSize: 18,fontWeight: FontWeight.w700))).toList()),
      if (!done) note(room['status'] == 'countdown' ? 'Başlıyor: ${seconds(room['startsAt'])}' :
        turnMode ? '${turn == uid ? 'Senin sıran' : 'Rakibinin sırası'} · ${seconds(room['turnDeadline'])} sn' :
        '${seconds(room[mode == 'grid_random' ? 'roundDeadline' : 'endsAt'])} sn'),
      if (!connected) note('Bağlantı kesildi. Sunucu saati devam ediyor; yeniden bağlanılıyor.'),
      if (mode == 'grid_random' && !done) note('Tur ${(room['round'] as num? ?? 0) + 1} / 5 · Her oyuncuya bir cevap hakkı'),
      if (rewardMap(room['series'])['limit'] == 3) note('Seri maçı ${rewardMap(room['series'])['game']} / 3'),
    ]);
  }
  Widget board(int n, List<String> labels, {bool selectable = true}) => LayoutBuilder(builder: (context,constraints) {
    final scale = MediaQuery.textScalerOf(context).scale(13) / 13;
    final owners = rewardMap(room['owners']);
    final boardWidth = math.max(constraints.maxWidth, n * 112.0 * scale + (n - 1) * 6);
    void detail(int i, String? ownerName) => showDialog<void>(context: context,builder: (_) => AlertDialog(
      title: Text('${i + 1}. hücre'), content: Text('${labels[i]}\n${ownerName ?? 'Boş hücre'}'),
      actions: [TextButton(onPressed: () => Navigator.pop(context),child: const Text('Kapat'))]));
    final grid = GridView.builder(shrinkWrap: true,physics: const NeverScrollableScrollPhysics(),itemCount: labels.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: n,crossAxisSpacing: 6,mainAxisSpacing: 6,
        mainAxisExtent: (n == 5 ? 112 : 132) * scale), itemBuilder: (context,i) {
        final owner = rewardMap(owners['$i']); final selectedCell = target == '$i';
        final ownerName = rewardMap(room['names'])[owner['uid']];
        return Semantics(label: '${i + 1}. hücre, ${labels[i]}, ${ownerName ?? 'boş'}',selected: selectedCell,button: true,
          child: Material(color: selectedCell ? palette.tint : palette.surface,borderRadius: BorderRadius.circular(12),
            child: InkWell(onLongPress: () => detail(i,ownerName?.toString()),onTap: done || owner.isNotEmpty ? () => detail(i,ownerName?.toString()) : () {
              if (selectable) setState(() => target = '$i');
              else detail(i,ownerName?.toString());
            },child: Padding(padding: const EdgeInsets.all(6),child: Column(mainAxisAlignment: MainAxisAlignment.center,children: [
              Icon(owner.isNotEmpty ? Icons.check_circle_outline : selectedCell ? Icons.radio_button_checked : Icons.crop_square,
                size: 20,color: owner['uid'] == uid || selectedCell ? accent : palette.muted),
              const SizedBox(height: 4), Flexible(child: Text(labels[i],textAlign: TextAlign.center,overflow: TextOverflow.ellipsis,maxLines: 5,
                style: const TextStyle(fontSize: 12))), if (ownerName != null) Text('$ownerName',maxLines: 1,overflow: TextOverflow.ellipsis),
            ])))));
      });
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch,children: [
      if (boardWidth > constraints.maxWidth) note('Tahtayı yatay kaydır. Tam hücre bilgisi için basılı tut.'),
      SingleChildScrollView(scrollDirection: Axis.horizontal,child: SizedBox(width: boardWidth,child: grid)),
    ]);
  });
  Widget chooser() => panel([
    if (selected != null) ...[
      PlayerPortrait(playerId: int.tryParse('${selected!['id']}') ?? -1,size: 64,fallback: const Icon(Icons.person,size: 48)),note('${selected!['name']}'),
    ],
    TextField(controller: query,onChanged: (_) => setState(() {selected = null; results = []; searchSerial++;}),onSubmitted: (_) => search(),decoration: InputDecoration(labelText: 'Futbolcu ara',suffixIcon: IconButton(
      tooltip: 'Ara',onPressed: search,icon: const Icon(Icons.search)))),
    ...results.map((p) => ListTile(contentPadding: EdgeInsets.zero,title: Text('${p['name']}'),subtitle: Text('${p['country']} · ${p['position']}'),
      selected: selected?['id'] == p['id'],onTap: () => setState(() {selected = p; results = []; query.text = '${p['name']}';}))),
    button('Cevabı gönder',selected == null || room['submitted'] == true ||
      ['grid_classic','loto'].contains(mode) && target == null ||
      ['grid_classic','cinko'].contains(mode) && room['turnUid'] != uid ? null : () => action('answer',{
        'playerId': selected!['id'],if (target != null) 'targetId': target,if (mode == 'grid_random') 'round': room['round']})),
    if (room['submitted'] == true) note('Cevabın kilitlendi. Rakibinin cevabı tur kapanınca açılır.'),
  ]);
  Widget manager() {
    final pool = rows(room['pool']); final spent = pool.where((p) => xi.contains(p['id'])).fold<num>(0,(n,p) => n + (p['cost'] as num));
    return panel([heading('Aynı bütçe, senin XI’in'),note('${xi.length} / 11 oyuncu · $spent / ${room['budget']} kadro bütçesi'),
      note('Kadro bütçesi oyun içindir; Coin bakiyen kullanılmaz.'),
      choice('Diziliş',formation,[for (final f in ['433','442','352','451']) {'id':f,'label':f.split('').join('-')}],(v) => setState(() => formation = v), enabled: room['submitted'] != true),
      for (final p in pool) CheckboxListTile(contentPadding: EdgeInsets.zero,value: xi.contains(p['id']),
        title: Text('${p['name']}'),subtitle: Text('${p['position']} · ${p['rating']} reyting · ${p['cost']} bütçe'),
        onChanged: busy || room['submitted'] == true ? null : (v) => setState(() {if (v == true) xi.add('${p['id']}'); else xi.remove(p['id']);})),
      for (final t in [('Press',press),('Tempo',tempo),('Genişlik',width)]) ...[note(t.$1),Slider(value: t.$2,divisions: 4,
        label: '${(t.$2*100).round()}',onChanged: room['submitted'] == true ? null : (v) => setState(() {
          if (t.$1 == 'Press') press = v; else if (t.$1 == 'Tempo') tempo = v; else width = v;
        }))],
      button(room['submitted'] == true ? 'Kadro kilitlendi' : 'XI ve taktiği kilitle',xi.length != 11 || spent > (room['budget'] as num? ?? 120) || room['submitted'] == true ? null :
        () => action('squad',{'playerIds':xi.toList(),'formation':formation,'tactics':{'press':press,'tempo':tempo,'width':width}})),
      note('Rakibin kadrosu ve taktiği iki taraf da kilitledikten sonra görünür.'),
    ]);
  }
  Widget play() {
    if (mode == 'club_manager') return manager();
    final criteria = rows(room['criteria']);
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch,children: [
      if (mode == 'grid_classic') ...[
        board(3,[for (final row in rows(room['rows'])) for (final col in rows(room['cols'])) '${row['label']} × ${col['label']}']),
        const SizedBox(height: 14),if (target != null) note('Seçilen hücre: ${rows(room['rows'])[int.parse(target!) ~/ 3]['label']} × ${rows(room['cols'])[int.parse(target!) % 3]['label']}'),
      ] else if (mode == 'grid_reverse') ...[
        board(3,rows(room['players']).map((p) => '${p['name']}').toList(),selectable: false),const SizedBox(height: 14),
        panel([choice('Boş eksen',target,[for (final a in ['r0','r1','r2','c0','c1','c2']) if (!rewardMap(room['owners']).containsKey(a))
          {'id':a,'label':'${a.startsWith('r') ? 'Satır' : 'Sütun'} ${int.parse(a[1])+1}'}],(v) => setState(() => target = v)),
          const SizedBox(height: 12),choice('Ortak kulüp veya ülke',criterion,[...rows(data['clubs']),...rows(data['countries'])],(v) => setState(() => criterion = v)),
          button('Ekseni doğrula',target == null || criterion == null || room['turnUid'] != uid ? null : () => action('answer',{'targetId':target,'criterionId':criterion})),
          ...rewardMap(room['owners']).entries.map((e) => note('${e.key}: ${rewardMap(room['names'])[rewardMap(e.value)['uid']]}'))]),
      ] else if (mode == 'cinko' || mode == 'loto') ...[
        board(mode == 'cinko' ? 5 : 4,criteria.map((k) => '${k['label']}').toList(),selectable: mode == 'loto'),const SizedBox(height: 14),
      ] else panel([for (final k in criteria) heading('${k['label']}')]),
      if (mode == 'loto') panel([heading('Tahtanın futbolcuları'), if (target != null) note('Seçilen hücre: ${criteria[int.parse(target!)]['label']}'),
        ...rows(room['players']).map((p) => ListTile(contentPadding: EdgeInsets.zero,title: Text('${p['name']}'),
          selected: selected?['id'] == p['id'],enabled: !rewardMap(room['used']).containsKey(p['id']),onTap: () => setState(() => selected = p))),
        button('Seçilen hücreye yerleştir',selected == null || target == null ? null : () => action('answer',{'playerId':selected!['id'],'targetId':target}))])
      else if (mode != 'grid_reverse') chooser(),
      if (mode == 'grid_random' && rewardMap(room['rounds']).isNotEmpty) panel([
        heading('Kapanan turlar'),...rewardMap(room['rounds']).entries.map((e) => note('Tur ${int.parse(e.key)+1}: '
          '${rewardMap(rewardMap(e.value)[uid])['correct'] == true ? 'Doğru' : 'Puan yok'}'))]),
    ]);
  }
  Widget outcome() {
    final reward = rewardMap(room['reward']);
    return panel([heading(room['status'] == 'finished' ? room['result'] == 'win' ? 'Kazandın' : room['result'] == 'loss' ? 'Maç tamamlandı' : 'Berabere' :
      room['status'] == 'forfeit' ? 'Maç hükmen sonuçlandı' : 'Maç iptal edildi'),note('${room['reason'] ?? ''}'),
      if (rewardMap(room['series'])['limit'] == 3) note('Seri galibiyetleri: ${rewardMap(rewardMap(room['series'])['wins']).entries.map((e) => '${rewardMap(room['names'])[e.key]} ${e.value}').join(' · ')}'),
      note(ranked ? reward['status'] == 'pending' ? 'Sonuç ve ödül doğrulaması bekleniyor.' :
        '${reward['coins'] ?? 0} Coin · ${reward['xp'] ?? 0} XP · Elo ${reward['eloDelta'] ?? 0}' : 'Dostluk maçı · Elo ve ödül yok'),
      if (room['simulation'] != null) note('Sunucuda hesaplanan gol sonucu: ${rewardMap(rewardMap(room['simulation'])['goals']).values.join(' – ')}'),
      if (room['witness'] != null) ExpansionTile(title: const Text('Örnek doğru futbolcular'),children: rows(room['witness']).map((p) => ListTile(title: Text('${p['name']}'))).toList()),
      if (room['answers'] is List) ExpansionTile(title: const Text('Doğrulanmış cevaplar'),children: [
        for (final round in room['answers'] as List) ...rows(round).map((p) => ListTile(title: Text('${p['name']}')))]),
      if (room['squads'] != null) ExpansionTile(title: const Text('Kilitlenen kadrolar ve taktikler'),children: [
        for (final e in rewardMap(room['squads']).entries) ...[
          note('${rewardMap(room['names'])[e.key]} · ${rewardMap(e.value)['formation']}'),
          for (final id in (rewardMap(e.value)['playerIds'] as List? ?? []))
            note('${rows(room['pool']).where((p) => p['id'] == id).firstOrNull?['name'] ?? id}'),
          note('Press: ${rewardMap(rewardMap(e.value)['tactics'])['press']} · Tempo: ${rewardMap(rewardMap(e.value)['tactics'])['tempo']} · Genişlik: ${rewardMap(rewardMap(e.value)['tactics'])['width']}'),
        ]]),
      button('Sonucu kopyala',() => Clipboard.setData(ClipboardData(text: '${widget.mode.title} · ${ranked ? 'Sıralamalı' : 'Arkadaş'}\n'
        '${rewardMap(room['names']).entries.map((e) => '${e.value}: ${rewardMap(room['scores'])[e.key] ?? 0}').join(' — ')}\nMaç: ${room['id']}')),secondary: true),
      ExpansionTile(title: const Text('Maç bilgisi'),children: [note('${room['id']} · ${room['dataRevision']} · ${room['ruleVersion']}')]),
      if (!ranked && ['finished','forfeit'].contains(room['status'])) button(room['nextRoom'] != null ? 'Rövanş odasına geç' :
        rewardMap(room['rematch'])[uid] == true ? 'Rövanş için rakip bekleniyor' : 'Rövanş iste',
        () async {if (room['nextRoom'] != null) await enter('resume'); else await action('rematch');}),
      button('Yeniden oyna',() {setState(() {room = {}; xi.clear(); target = null; selected = null;});load();},secondary: true),
    ]);
  }
  Future<void> leave() async {
    final yes = await showDialog<bool>(context: context,builder: (_) => AlertDialog(title: const Text('Maçtan ayrıl?'),
      content: const Text('Devam eden maçtan ayrılmak hükmen sonuca yol açar.'),actions: [
        TextButton(onPressed: () => Navigator.pop(context,false),child: const Text('Vazgeç')),
        FilledButton(onPressed: () => Navigator.pop(context,true),child: const Text('Ayrıl'))]));
    if (yes == true) await action('leave');
  }
  @override
  Widget build(BuildContext context) => PopScope(
      canPop: room.isEmpty || done,onPopInvokedWithResult: (didPop,result) {if (!didPop) leave();},
      child: Scaffold(appBar: AppBar(toolbarHeight: MediaQuery.textScalerOf(context).scale(16) > 24 ? 144 : 64,title: Text(widget.mode.title,maxLines: 3,softWrap: true),actions: [
        IconButton(tooltip: 'Yenile',onPressed: busy ? null : () {if (room.isEmpty) load(); else action('poll');},icon: const Icon(Icons.refresh))]),
        body: GameContent(child: ListView(padding: const EdgeInsets.all(16),children: [
          Text(ranked ? 'RASTGELE EŞLEŞME' : 'ARKADAŞ MAÇI',style: TextStyle(color: accent,fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),if (busy && data.isEmpty && room.isEmpty) const LinearProgressIndicator(),
          if (error != null) panel([note(error!),button('Yeniden dene',() {if (room.isEmpty) load(); else action('poll');},secondary: true)]),
          if (room.isEmpty) setup() else ...[hud(),if (['waiting','ready'].contains(room['status'])) lobby()
            else if (done) outcome() else if (room['status'] == 'countdown') panel([heading('Hazır ol'),note('Aynı anda başlayacaksınız.')]) else play(),
            if (!done) button('Maçtan ayrıl',leave,secondary: true)],
        ]))));
}
