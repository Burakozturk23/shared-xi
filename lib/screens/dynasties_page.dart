import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import '../controllers/dynasties_controller.dart';
import '../models/dynasty_task.dart';
import '../services/auth_service.dart';
import '../services/dynasties_service.dart';
import '../widgets/pitch_ui.dart';


class DynastiesPage extends StatefulWidget {
  const DynastiesPage({super.key, this.controller, this.openAtlas = false});
  final DynastiesController? controller;
  final bool openAtlas;
  @override
  State<DynastiesPage> createState() => _DynastiesPageState();
}
class _DynastiesPageState extends State<DynastiesPage> {
  DynastiesController? _c;
  StreamSubscription<dynamic>? _auth;
  String? _uid;
  String? _loadError;
  int _generation = 0;
  bool _collection = false;
  String _filter = 'all';
  final _scroll = ScrollController();
  @override
  void initState() {
    super.initState();
    _collection = widget.openAtlas;
    if (widget.controller != null) {
      _c = widget.controller;
    } else {
      _uid = AuthService.uid;
      _auth = AuthService.authStateChanges.listen((user) {
        if (user?.uid != _uid) { _uid = user?.uid; _boot(); }
      });
      _boot();
    }
  }
  Future<void> _boot() async {
    final generation = ++_generation;
    final old = _c; _c = null; old?.dispose();
    if (mounted) setState(() { _loadError = null; });
    DynastiesController? created;
    try {
      if (AuthService.uid == null && Firebase.apps.isNotEmpty) {
        try { await AuthService.ensureGuestSignedIn(); } catch (_) { /* Offline drafts remain available. */ }
      }
      if (!mounted || generation != _generation) return;
      final uid = AuthService.uid;
      final catalog = await DynastiesCatalog.load();
      if (!mounted || generation != _generation) return;
      created = DynastiesController(catalog: catalog,
          store: LocalDynastiesStore(uid), gateway: FirebaseDynastiesGateway(uid));
      // Attach before network sync so the catalog is usable when offline.
      setState(() { _c = created; });
      await created.load();
      if (widget.openAtlas && mounted && generation == _generation) created.archive();
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() { _loadError = 'Hanedanlıklar Atlası açılamadı. Cihaz kaydını koruyarak yeniden dene.'; });
      }
    }
  }
  void _top() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }
  void _open(String id, {bool replay = false}) { _c!.open(id, replay: replay); _top(); }
  @override
  void dispose() {
    _generation++; _auth?.cancel(); _scroll.dispose();
    if (widget.controller == null) _c?.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (_loadError != null) return Scaffold(appBar: AppBar(title: const Text('Dynasties', maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min,
        children: [Text(_loadError!), const SizedBox(height: 16), FilledButton(onPressed: _boot, child: const Text('Yeniden dene'))]))));
    if (c == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return AnimatedBuilder(animation: c, builder: (context, _) => PopScope(
      canPop: c.phase == 'archive',
      onPopInvokedWithResult: (didPop, _) { if (!didPop && !c.busy) { c.archive(); _top(); } },
      child: Scaffold(
        appBar: AppBar(title: const Text('Dynasties', maxLines: 1, overflow: TextOverflow.ellipsis),
          leading: c.phase == 'archive' ? null : IconButton(tooltip: 'Arşive dön',
              onPressed: c.busy ? null : () { c.archive(); _top(); }, icon: const Icon(Icons.arrow_back)),
          actions: [IconButton(tooltip: 'Eşitle', onPressed: c.busy ? null : c.sync, icon: const Icon(Icons.sync))]),
        body: !c.ready ? const Center(child: CircularProgressIndicator()) : SafeArea(child: ListView(
          key: const PageStorageKey('dy-scroll'), controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32), children: [
            if (c.busy) const Padding(padding: EdgeInsets.only(bottom: 12), child: LinearProgressIndicator()),
            if (c.message.isNotEmpty) Padding(padding: const EdgeInsets.only(bottom: 16),
              child: Semantics(liveRegion: true, child: PitchPanel(child: Text(c.message)))),
            if (c.phase == 'archive') ..._archive(c)
            else if (c.phase == 'intro') ..._intro(c)
            else if (c.phase == 'task') ..._task(c)
            else ..._result(c),
          ])),
      ),
    ));
  }
  IconData _icon(String type) => switch(type) {
    'route'=>Icons.route, 'squad'=>Icons.groups_outlined, 'timeline'=>Icons.swap_vert,
    'trophies'=>Icons.emoji_events_outlined, 'tactics'=>Icons.account_tree_outlined,
    _=>Icons.bar_chart_rounded,
  };
  Widget _hero(String eyebrow, String title, String subtitle, {Widget? footer}) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
        colors:[Color(0xFF263B42),Color(0xFF101D23)]),
      border: Border.all(color:const Color(0xFF927849))),
    child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Icon(Icons.castle_outlined,size:36,color:Color(0xFFF3CF87)),
      const SizedBox(height:14),Text(eyebrow,style:const TextStyle(color:Color(0xFFF3CF87),fontSize:12,fontWeight:FontWeight.w700)),
      const SizedBox(height:10),Text(title,style:const TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.w800,height:1.15)),
      const SizedBox(height:12),Text(subtitle,style:const TextStyle(color:Color(0xFFDAE6E8),height:1.45)),
      if(footer!=null)...[const SizedBox(height:18),footer],
    ]));
  Widget _seal(Dynasty d, bool earned) => Container(
    padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(shape:BoxShape.circle,color:earned?const Color(0xFF51401F):const Color(0xFF23323A),
      border:Border.all(color:earned?const Color(0xFFF3CF87):const Color(0xFF62747B),width:2)),
    child:Icon(earned?Icons.verified:Icons.lock_outline,color:earned?const Color(0xFFF3CF87):const Color(0xFFBDCDD1),size:26));
  List<Widget> _archive(DynastiesController c) {
    final visible=c.catalog.dynasties.where((d)=>_filter=='all'||d.chapterId.toString()==_filter);
    return [
      _hero('HANEDANLIKLAR ÇAĞI','Bir dönem.\nKalıcı bir iz.',
        '19 hanedanlık. 38 görev. Kadroyu, kupaları ve oyun fikrini keşfet.',
        footer:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${c.sealCount} / ${c.catalog.dynasties.length} mühür  ·  ${c.count} / ${c.catalog.tasks.length} görev',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
          const SizedBox(height:12),LinearProgressIndicator(value:c.sealCount/c.catalog.dynasties.length,minHeight:6,
            color:const Color(0xFFF3CF87),backgroundColor:Colors.white12),
        ])),
      const SizedBox(height:16),
      const Text('Her görevde ilk başarı: 8 Coin + 20 XP. Her dönemde iki görev, bir mühür.'),
      if(!c.rewardEligible) const Padding(padding:EdgeInsets.only(top:8),child:Text('Misafir olarak oynayabilirsin. Ödüllerin için bu misafir hesabını Google’a bağla.')),
      const SizedBox(height:14),
      Wrap(spacing:8,runSpacing:8,children:[
        ChoiceChip(label:const Text('Dönemler'),selected:!_collection,onSelected:(_)=>setState(()=>_collection=false)),
        ChoiceChip(key:const ValueKey('dy-atlas'),label:const Text('Hanedanlıklar Atlası'),selected:_collection,onSelected:(_)=>setState(()=>_collection=true)),
      ]),
      const SizedBox(height:12),
      Wrap(spacing:8,runSpacing:8,children:[
        for(final (id,label) in [('all','Tümü'),('1','Doğuş'),('2','Miras')])
          FilterChip(label:Text(label),selected:_filter==id,onSelected:(_)=>setState(()=>_filter=id)),
      ]),
      if(c.pending.isNotEmpty) Padding(padding:const EdgeInsets.only(top:12),child:Text('${c.pending.length} cevap doğrulama bekliyor. Bağlantı geldiğinde Eşitle’ye dokun.')),
      if(c.activeId!=null&&!c.results.containsKey(c.activeId)) Padding(padding:const EdgeInsets.only(top:12),child:PitchRow(
        title:'Kaldığın yerden',subtitle:'${c.catalog.dynasty(c.active!.dynastyId).text('club')} · ${c.active!.text('title')}',icon:Icons.play_circle_outline,
        onTap:c.busy?null:(){_open(c.activeId!);c.start();})),
      if(_collection)...[
        const PitchSectionTitle('Atlas kilometre taşları'),
        for(final raw in c.catalog.economy['milestones'] as List) Padding(padding:const EdgeInsets.only(bottom:8),child:PitchPanel(
          child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Icon(c.catalog.dynasties.where((d) => c.seals.containsKey(d.id)).length >= dyMap(raw)['count'] ? Icons.verified : Icons.flag_outlined),const SizedBox(width:12),
            Expanded(child:Text('${dyMap(raw)['count']} mühür · +${dyMap(raw)['coins']} Coin / +${dyMap(raw)['xp']} XP\n${dyMap(c.rewards['milestone_${dyMap(raw)['count']}'])['settled']==true?'Ödül alındı':c.catalog.dynasties.where((d) => c.seals.containsKey(d.id)).length >= dyMap(raw)['count']?'Ödül eşitlemesi bekliyor':'Keşfetmeye devam et'}')),
          ]))),
        PitchPanel(key:const ValueKey('dy-historian'),child:Text(c.catalog.dynasties.where((d) => d.data['expansion'] == null && c.seals.containsKey(d.id)).length==16?'Futbol Tarihçisi · 16/16 mühür tamamlandı':'Futbol Tarihçisi · ilk 16 dönemin mühürleriyle açılır')),
      ],
      for(final chapter in [1,2]) ...[
        if(visible.any((d)=>d.chapterId==chapter)) PitchSectionTitle(c.catalog.chapters[chapter-1]),
        for(final d in visible.where((d)=>d.chapterId==chapter)) Padding(padding:const EdgeInsets.only(bottom:12),child:PitchPanel(
          key:ValueKey('dynasty-${d.id}'),onTap:c.busy?null:(){c.openDynasty(d.id);_top();},
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(crossAxisAlignment:CrossAxisAlignment.start,children:[_seal(d,c.seals.containsKey(d.id)),const SizedBox(width:14),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(d.text('club'),style:Theme.of(context).textTheme.titleMedium),
                Text(d.text('period')),const SizedBox(height:6),Text(d.text('title')),
              ])),
            ]),
            const SizedBox(height:14),Text('${d.taskIds.where(c.results.containsKey).length} / 2 görev · ${c.seals.containsKey(d.id)?'Mühür kazanıldı':'Yükseliş → Zirve'}'),
            if(_collection&&c.seals.containsKey(d.id)) ...[const SizedBox(height:10),Text(dyMap(c.seals[d.id])['story'] as String)],
            if(!_collection) ...[const SizedBox(height:10),Wrap(spacing:8,runSpacing:4,children:[for(final id in d.taskIds) Text(c.catalog.byId(id).label,style:Theme.of(context).textTheme.labelSmall)])],
          ]))),
      ],
    ];
  }
  List<Widget> _intro(DynastiesController c) {
    final t=c.active!,d=c.catalog.dynasty(t.dynastyId);
    return [
      _hero('${d.text('club').toUpperCase()} · ${d.text('period')}',d.text('title'),d.text('intro')),
      const SizedBox(height:20),const Text('Yükseliş’i çöz, Zirve’ye ulaş. İki görev tamamlandığında Hanedanlık Mührü ve dönemin hikâyesi açılır.'),
      const SizedBox(height:16),
      for(final id in d.taskIds) Padding(padding:const EdgeInsets.only(bottom:10),child:PitchRow(
        title:c.catalog.byId(id).text('title'),subtitle:c.catalog.byId(id).label,
        icon:c.results.containsKey(id)?Icons.check_circle:c.available(c.catalog.byId(id))?_icon(c.catalog.byId(id).mechanic):Icons.lock_outline,
        onTap:c.busy||!c.available(c.catalog.byId(id))?null:()=>_open(id))),
      const SizedBox(height:12),Text('${t.text('title')} · ${t.label}',style:Theme.of(context).textTheme.titleMedium),
      const SizedBox(height:10),const Text('Ücretsiz ipucu ve sınırsız deneme. Seçimlerin cihazda saklanır; ilerleme ve ödül bağlantı olduğunda doğrulanır.'),
      if (t.data['expansion'] != null) const Padding(padding:EdgeInsets.only(top:12),child:Text('İlk başarı: 8 Coin + 20 XP. Tekrar oynama ikinci ödül vermez.')),
      const SizedBox(height:20),FilledButton.icon(key:const ValueKey('dy-start'),onPressed:c.busy?null:(){c.start();_top();},icon:const Icon(Icons.play_arrow),label:Text('${t.text('title')} görevine başla')),
    ];
  }
  List<Widget> _task(DynastiesController c) {
    final t=c.active!,d=c.catalog.dynasty(t.dynastyId);
    return [
      Text('${d.text('club')} · ${d.text('period')}',style:Theme.of(context).textTheme.titleMedium),
      const SizedBox(height:10),Wrap(spacing:8,runSpacing:8,children:[Chip(label:Text('${t.stage}/2 · ${t.text('title')}')),Chip(avatar:Icon(_icon(t.mechanic),size:18),label:Text(t.label))]),
      const SizedBox(height:16),Text(t.text('prompt'),style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:18),
      if(t.mechanic=='tactics') _hero('TAKTİK TAHTASI','Oyunun fikrini bul.','Sorudaki rolü veya prensibi seç.'),
      if(t.mechanic=='records') const PitchPanel(child:Row(children:[Icon(Icons.query_stats,size:36),SizedBox(width:12),Expanded(child:Text('Rekor kartı\nSorudaki sezon sınırlarına dikkat et.'))])),
      if(t.mechanic=='squad') const PitchPanel(child:Row(children:[Icon(Icons.checkroom,size:36),SizedBox(width:12),Expanded(child:Text('Hanedanlığın omurgası\nSoruda belirtilen kadroyu veya rolü kullan.'))])),
      if(t.mechanic=='trophies') const PitchPanel(child:Row(children:[Icon(Icons.emoji_events_outlined,size:36),SizedBox(width:12),Expanded(child:Text('Kupa dolabını tamamla\nSezon ve takvim yılı ayrımına dikkat et.'))])),
      const SizedBox(height:16),
      if(t.interaction=='order') ..._order(c)
      else if(t.interaction=='match') ..._matching(c)
      else ..._choices(c),
      const SizedBox(height:12),TextButton.icon(key:const ValueKey('dy-hint'),onPressed:c.hint,icon:const Icon(Icons.lightbulb_outline),label:const Text('Ücretsiz ipucu')),
      if(c.hintOpen) PitchPanel(child:Text(t.text('hint'))),
      if(c.hints.containsKey(t.id)) Padding(padding:const EdgeInsets.only(top:12),child:PitchPanel(child:Text(dyMap(c.hints[t.id])['text']?.toString()??''))),
      if(!c.hints.containsKey(t.id)&&!c.results.containsKey(t.id)) TextButton(key:const ValueKey('dy-extra-help'),onPressed:c.busy?null:()async{
        final taskId=t.id,price=c.pro?0:6;
        final yes=await showDialog<bool>(context:context,builder:(dialog)=>AlertDialog(title:const Text('Ek yardım'),
          content:Text(price==0?'Pro hesabında ücretsiz ek yardımı aç?':'Bu görev için ek yardımı 6 Coin karşılığında aç?'),
          actions:[TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('Aç'))]));
        if(yes==true&&mounted&&identical(c,_c)&&c.activeId==taskId) await c.buyHint(maxPrice:price);
      },child:Text(c.pro?'Pro · Ek yardım':'Ek yardım · 6 Coin')),
      const SizedBox(height:14),FilledButton(key:const ValueKey('dy-submit'),onPressed:c.busy||!c.canSubmit?null:()async{await c.submit();if(mounted&&c.phase=='result')_top();},child:Text(c.busy?'Doğrulanıyor…':'Cevabı kontrol et')),
    ];
  }
  List<Widget> _choices(DynastiesController c) {
    final t=c.active!,multiple=t.interaction=='multi';
    return [
      Text(multiple?'${t.requiredCount} kart seç · ${c.answers.length}/${t.requiredCount} seçildi':'Bir kart seç',style:Theme.of(context).textTheme.titleSmall),
      const SizedBox(height:12),
      for(final o in t.options) Padding(padding:const EdgeInsets.only(bottom:10),child:Semantics(
        selected:c.answers.contains(o['id']),button:true,
        child:PitchRow(key:ValueKey('option-${o['id']}'),title:o['label'] as String,
          icon:c.answers.contains(o['id'])?(multiple?Icons.check_box:Icons.radio_button_checked):(multiple?Icons.check_box_outline_blank:Icons.radio_button_off),
          highlight:c.answers.contains(o['id']),trailing:const SizedBox.shrink(),onTap:c.busy?null:()=>c.choose(o['id'] as String)))),
    ];
  }
  List<Widget> _order(DynastiesController c) {
    final t=c.active!;
    return [const Text('En erken olay üstte. Kartları yukarı/aşağı taşı.'),const SizedBox(height:12),
      for(var i=0;i<c.answers.length;i++) Padding(padding:const EdgeInsets.only(bottom:10),child:PitchPanel(
        key:ValueKey('event-${c.answers[i]}'),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${i+1}. ${t.optionLabel(c.answers[i])}',style:Theme.of(context).textTheme.titleMedium),
          Row(mainAxisAlignment:MainAxisAlignment.end,children:[
            IconButton(key:ValueKey('up-$i'),tooltip:'Yukarı taşı',onPressed:c.busy||i==0?null:()=>c.move(i,-1),icon:const Icon(Icons.arrow_upward)),
            IconButton(key:ValueKey('down-$i'),tooltip:'Aşağı taşı',onPressed:c.busy||i==c.answers.length-1?null:()=>c.move(i,1),icon:const Icon(Icons.arrow_downward)),
          ])]))),
    ];
  }
  List<Widget> _matching(DynastiesController c) {
    final t=c.active!;
    return [const Text('Her yuvaya bir kart ata. Aynı kart iki kez kullanılamaz.'),
      for(var i=0;i<t.slots.length;i++) Padding(padding:const EdgeInsets.symmetric(vertical:8),child:PitchPanel(
        child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(t.slots[i],style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:10),
          OutlinedButton.icon(key:ValueKey('match-slot-$i'),icon:const Icon(Icons.unfold_more),
            label:Text(c.answers[i].isEmpty?'Kart seç':t.optionLabel(c.answers[i])),
            onPressed:c.busy?null:()async{
              final taskId=t.id;
              final selected=await showDialog<String>(context:context,builder:(dialog)=>SimpleDialog(
                title:Text('${t.slots[i]} · Kart seç'),children:[for(final o in t.options) SimpleDialogOption(
                  onPressed:()=>Navigator.pop(dialog,o['id']),child:Padding(padding:const EdgeInsets.symmetric(vertical:8),child:Text(o['label'] as String)))]));
              if(selected!=null&&mounted&&identical(c,_c)&&c.activeId==taskId)c.assign(i,selected);
            }),
        ]))),
    ];
  }
  List<Widget> _result(DynastiesController c) {
    final t=c.active!,d=c.catalog.dynasty(t.dynastyId),r=dyMap(c.results[t.id]),reward=dyMap(c.rewards[t.id]);
    final sealed=c.seals.containsKey(d.id);
    return [
      _hero(sealed?'HANEDANLIK MÜHRÜ KAZANILDI':'YÜKSELİŞ TAMAMLANDI',d.text('club'),'${d.text('period')} · ${t.text('title')}',
        footer:Text(sealed?'2 / 2 görev · Atlas kaydı açıldı':'1 / 2 görev · Zirve seni bekliyor',style:const TextStyle(color:Color(0xFFF3CF87)))),
      const SizedBox(height:20),PitchPanel(key:const ValueKey('dy-result'),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Tarihin cevabı'),const SizedBox(height:10),Text(r['answer']?.toString()??'',style:Theme.of(context).textTheme.titleMedium),
      ])),
      if(sealed)...[const SizedBox(height:16),PitchPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _seal(d,true),const SizedBox(height:12),Text(dyMap(c.seals[d.id])['story']?.toString()??''),
      ]))],
      const SizedBox(height:16),PitchPanel(child:Text(reward['settled']==true?'İlk başarı ödülü alındı: 8 Coin + 20 XP. Yeniden oynamak ikinci ödül vermez.':'8 Coin + 20 XP ödülün bekliyor. Bağlantını kontrol et; misafirsen bu hesabı Google’a bağlayıp eşitle.')),
      const SizedBox(height:12),ExpansionTile(key:PageStorageKey('dy-sources-${t.id}'),title:const Text('Tarihsel kaynaklar'),children:[
        for(final raw in r['sources'] as List? ?? []) Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(Uri.parse(dyMap(raw)['url'] as String).host),Text(dyMap(raw)['url'] as String,style:const TextStyle(fontSize:12)),
          TextButton(onPressed:()async{await Clipboard.setData(ClipboardData(text:dyMap(raw)['url'] as String));},child:const Text('Bağlantıyı kopyala')),
        ])),
      ]),
      const SizedBox(height:20),
      if(t.stage==1&&!sealed) FilledButton(key:const ValueKey('dy-next'),onPressed:c.busy?null:()=>_open(d.taskIds.last),child:const Text('Zirve’ye geç')),
      if(sealed) ...[for(final id in d.taskIds) TextButton(onPressed:c.busy?null:()=>_open(id),child:Text('${c.catalog.byId(id).text('title')} sonucunu gör'))],
      if(sealed) FilledButton(onPressed:c.busy?null:(){c.archive();_top();setState(()=>_collection=true);},child:const Text('Hanedanlıklar Atlası’na dön')),
      const SizedBox(height:8),OutlinedButton(onPressed:c.busy?null:()=>_open(t.id,replay:true),child:const Text('Yeniden oyna · ödülsüz')),
    ];
  }
}
