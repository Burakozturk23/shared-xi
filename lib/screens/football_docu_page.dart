import '../widgets/energy_sheet.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import '../controllers/football_docu_controller.dart';
import '../models/docu_task.dart';
import '../services/auth_service.dart';
import '../services/football_docu_service.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/player_portrait.dart';


class FootballDocuPage extends StatefulWidget {
  const FootballDocuPage({super.key, this.controller, this.openCollection = false});
  final FootballDocuController? controller;
  final bool openCollection;
  @override
  State<FootballDocuPage> createState() => _FootballDocuPageState();
}
class _FootballDocuPageState extends State<FootballDocuPage> {
  FootballDocuController? _c;
  StreamSubscription<dynamic>? _auth;
  String? _uid;
  String? _loadError;
  int _generation = 0;
  bool _collection = false;
  String _filter = 'all', _theme = 'all', _progress = 'all';
  final _scroll = ScrollController(keepScrollOffset: false);
  Future<void> _startWithEnergy() async {
    final controller = _c;
    final id = controller?.activeId;
    if (controller == null || id == null) return;
    if (widget.controller != null || await StoryEnergyAccess.open(context, 'docu', id)) {
      if (!mounted || _c != controller || controller.activeId != id) return;
      controller.start(); _top();
    }
  }
  @override
  void initState() {
    super.initState();
    _collection = widget.openCollection;
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
    FootballDocuController? created;
    try {
      if (AuthService.uid == null && Firebase.apps.isNotEmpty) {
        try { await AuthService.ensureGuestSignedIn(); } catch (_) { /* Offline drafts remain available. */ }
      }
      if (!mounted || generation != _generation) return;
      final uid = AuthService.uid;
      final catalog = await FootballDocuCatalog.load();
      if (!mounted || generation != _generation) return;
      created = FootballDocuController(catalog: catalog,
          store: LocalFootballDocuStore(uid), gateway: FirebaseFootballDocuGateway(uid));
      // Attach before network sync so the catalog is usable when offline.
      setState(() { _c = created; });
      await created.load();
      if (widget.openCollection && mounted && generation == _generation) created.archive();
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() { _loadError = 'Belgesel Arşivi açılamadı. Cihaz kaydını koruyarak yeniden dene.'; });
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
    if (_loadError != null) return Scaffold(appBar: AppBar(title: const Text('Football Docu-Series', maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min,
        children: [Text(_loadError!), const SizedBox(height: 16), FilledButton(onPressed: _boot, child: const Text('Yeniden dene'))]))));
    if (c == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return AnimatedBuilder(animation: c, builder: (context, _) => PopScope(
      canPop: c.phase == 'archive',
      onPopInvokedWithResult: (didPop, _) { if (!didPop && !c.busy) { c.archive(); _top(); } },
      child: Scaffold(
        appBar: AppBar(title: const Text('Football Docu-Series', maxLines: 1, overflow: TextOverflow.ellipsis),
          leading: c.phase == 'archive' ? null : IconButton(tooltip: 'Arşive dön',
              onPressed: c.busy ? null : () { c.archive(); _top(); }, icon: const Icon(Icons.arrow_back)),
          actions: [IconButton(tooltip: 'Eşitle', onPressed: c.busy ? null : c.sync, icon: const Icon(Icons.sync))]),
        body: !c.ready ? const Center(child: CircularProgressIndicator()) : SafeArea(child: ListView(
          // Each phase owns its lazy-list layout; a solved task must not reuse
          // the previous question's retained children or scroll position.
          key: ValueKey('docu-scroll-${c.phase}-${c.activeId ?? "archive"}'), controller: _scroll,
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
    'evidence'=>Icons.push_pin_outlined, 'timeline'=>Icons.swap_vert,
    'headline'=>Icons.fact_check_outlined, 'turning'=>Icons.bolt_outlined,
    _=>Icons.person_search_outlined,
  };
  Widget _hero(String eyebrow, String title, String subtitle, {Widget? footer}) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
        colors:[Color(0xFF193E3A),Color(0xFF0D1B21)]),
      border: Border.all(color:const Color(0xFF557A63))),
    child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Icon(Icons.movie_filter_outlined,size:36,color:Color(0xFFBDEA84)),
      const SizedBox(height:14),Text(eyebrow,style:const TextStyle(color:Color(0xFFBDEA84),fontSize:12,fontWeight:FontWeight.w700)),
      const SizedBox(height:10),Text(title,style:const TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.w800,height:1.15)),
      const SizedBox(height:12),Text(subtitle,style:const TextStyle(color:Color(0xFFDAE6E8),height:1.45)),
      if(footer!=null)...[const SizedBox(height:18),footer],
    ]));
  Widget _fileIcon(DocuEpisode d, bool earned) => Container(
    padding:const EdgeInsets.all(14),
    decoration:BoxDecoration(shape:BoxShape.circle,color:earned?const Color(0xFF51401F):const Color(0xFF23323A),
      border:Border.all(color:earned?const Color(0xFFBDEA84):const Color(0xFF62747B),width:2)),
    child:Icon(earned?Icons.verified:Icons.lock_outline,color:earned?const Color(0xFFBDEA84):const Color(0xFFBDCDD1),size:26));
  List<Widget> _archive(FootballDocuController c) {
    final visible=c.catalog.episodes.where((d)=>(_filter=='all'||d.chapterId.toString()==_filter) &&
      (_theme=='all'||d.text('theme')==_theme) && (_progress=='all'||(_progress=='done'?c.files.containsKey(d.id):!c.files.containsKey(d.id))));
    return [
      _hero('BELGESEL ODASI','Futbolun\nperde arkası.',
        '24 belgesel. 48 araştırma. Kanıtları birleştir, hikâyeyi tamamla.',
        footer:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text('${c.fileCount} / 24 dosya  ·  ${c.count} / 48 görev',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
          const SizedBox(height:12),LinearProgressIndicator(value:c.fileCount/24,minHeight:6,
            color:const Color(0xFFBDEA84),backgroundColor:Colors.white12),
        ])),
      const SizedBox(height:16),
      const Text('Her görevde ilk başarı: 8 Coin + 20 XP. Her belgeselde iki araştırma, bir hatıra.'),
      if(!c.rewardEligible) const Padding(padding:EdgeInsets.only(top:8),child:Text('Misafir olarak oynayabilirsin. Ödüllerin için bu misafir hesabını Google’a bağla.')),
      const SizedBox(height:14),
      Wrap(spacing:8,runSpacing:8,children:[
        ChoiceChip(label:const Text('Belgeseller'),selected:!_collection,onSelected:(_)=>setState(()=>_collection=false)),
        ChoiceChip(key:const ValueKey('docu-collection'),label:const Text('Belgesel Arşivi'),selected:_collection,onSelected:(_)=>setState(()=>_collection=true)),
      ]),
      const SizedBox(height:12),
      Wrap(spacing:8,runSpacing:8,children:[
        for(final (id,label) in [('all','Tüm bölümler'),('1','I · Mucize'),('2','II · Kırılma'),('3','III · Yeniden doğuş')])
          FilterChip(label:Text(label),selected:_filter==id,onSelected:(_)=>setState(()=>_filter=id)),
      ]),
      const SizedBox(height:8),
      Wrap(spacing:8,runSpacing:8,children:[
        for(final theme in ['all','Mucize','Kimlik','Kırılma','Taraftar','Yeniden doğuş'])
          FilterChip(label:Text(theme=='all'?'Tüm temalar':theme),selected:_theme==theme,onSelected:(_)=>setState(()=>_theme=theme)),
      ]),
      Wrap(spacing:8,runSpacing:8,children:[
        for(final (id,label) in [('all','Tüm dosyalar'),('open','Devam edenler'),('done','Bitirilenler')])
          FilterChip(label:Text(label),selected:_progress==id,onSelected:(_)=>setState(()=>_progress=id)),
      ]),
      if(visible.isEmpty) const Padding(padding:EdgeInsets.symmetric(vertical:20),child:Text('Bu filtrede belgesel bulunmuyor. Başka bir filtre seç.')),
      if(c.pending.isNotEmpty) Padding(padding:const EdgeInsets.only(top:12),child:Text('${c.pending.length} cevap doğrulama bekliyor. Bağlantı geldiğinde Eşitle’ye dokun.')),
      if(c.activeId!=null&&!c.results.containsKey(c.activeId)) Padding(padding:const EdgeInsets.only(top:12),child:PitchRow(
        title:'Kaldığın yerden',subtitle:'${c.catalog.episode(c.active!.episodeId).text('club')} · ${c.active!.text('title')}',icon:Icons.play_circle_outline,
        onTap:c.busy?null:(){_open(c.activeId!);_startWithEnergy();})),
      if(_collection)...[
        const PitchSectionTitle('Arşiv kilometre taşları'),
        for(final raw in c.catalog.economy['milestones'] as List) Padding(padding:const EdgeInsets.only(bottom:8),child:PitchPanel(
          child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Icon(c.fileCount >= docuMap(raw)['count'] ? Icons.verified : Icons.flag_outlined),const SizedBox(width:12),
            Expanded(child:Text('${docuMap(raw)['count']} dosya · +${docuMap(raw)['coins']} Coin / +${docuMap(raw)['xp']} XP\n${docuMap(c.rewards['milestone_${docuMap(raw)['count']}'])['settled']==true?'Ödül alındı':c.fileCount >= docuMap(raw)['count']?'Ödül eşitlemesi bekliyor':'Keşfetmeye devam et'}')),
          ]))),
        PitchPanel(key:const ValueKey('docu-archivist'),child:Text(c.fileCount==24?'Belgeselci · 24/24 dosya tamamlandı':'Belgeselci · tüm dosyalarla açılır')),
      ],
      for(final chapter in [1,2,3]) ...[
        if(visible.any((d)=>d.chapterId==chapter)) PitchSectionTitle(c.catalog.chapters[chapter-1]),
        for(final d in visible.where((d)=>d.chapterId==chapter)) Padding(padding:const EdgeInsets.only(bottom:12),child:PitchPanel(
          key:ValueKey('docu-episode-${d.id}'),onTap:c.busy?null:(){c.openEpisode(d.id);_top();},
          child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            Row(crossAxisAlignment:CrossAxisAlignment.start,children:[_fileIcon(d,c.files.containsKey(d.id)),const SizedBox(width:14),
              Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
                Text(d.text('club'),style:Theme.of(context).textTheme.titleMedium),
                Text(d.text('period')),const SizedBox(height:6),Text(d.text('title')),
              ])),
            ]),
            const SizedBox(height:14),Text('${d.taskIds.where(c.results.containsKey).length} / 2 görev · ${c.files.containsKey(d.id)?'Dosya tamamlandı':'Araştırma 1 → Araştırma 2'}'),
            if(_collection&&c.files.containsKey(d.id)) ...[
              const SizedBox(height:10),Text(docuMap(c.files[d.id])['story'] as String),
              if(docuMap(c.files[d.id])['earnedAt'] is num) Text('Tamamlandı: ${_date((docuMap(c.files[d.id])['earnedAt'] as num).toInt())}'),
              for(final id in d.taskIds) TextButton(onPressed:c.busy?null:()=>_open(id),child:Text('${c.catalog.byId(id).text('title')} · Kanıt ve kaynaklar')),
            ],
            if(!_collection) ...[const SizedBox(height:10),Wrap(spacing:8,runSpacing:4,children:[for(final id in d.taskIds) Text(c.catalog.byId(id).label,style:Theme.of(context).textTheme.labelSmall)])],
          ]))),
      ],
    ];
  }
  String _date(int milliseconds) {
    final d=DateTime.fromMillisecondsSinceEpoch(milliseconds).toLocal();
    return '${d.day.toString().padLeft(2,"0")}.${d.month.toString().padLeft(2,"0")}.${d.year}';
  }
  List<Widget> _intro(FootballDocuController c) {
    final t=c.active!,d=c.catalog.episode(t.episodeId);
    return [
      _hero('${d.text('club').toUpperCase()} · ${d.text('period')}',d.text('title'),d.text('intro')),
      if(t.stage==2&&c.results.containsKey(d.taskIds.first)) ...[
        const SizedBox(height:16),PitchPanel(child:Text(docuMap(c.results[d.taskIds.first])['interlude']?.toString()??'')),
      ],
      const SizedBox(height:20),const Text('İki araştırma, bir belgesel. İlk kanıt ara sahneyi, ikinci kanıt tamamlanmış dosyayı açar.'),
      const SizedBox(height:16),
      for(final id in d.taskIds) Padding(padding:const EdgeInsets.only(bottom:10),child:PitchRow(
        title:c.catalog.byId(id).text('title'),subtitle:c.catalog.byId(id).label,
        icon:c.results.containsKey(id)?Icons.check_circle:c.available(c.catalog.byId(id))?_icon(c.catalog.byId(id).mechanic):Icons.lock_outline,
        onTap:c.busy||!c.available(c.catalog.byId(id))?null:()=>_open(id))),
      const SizedBox(height:12),Text('${t.text('title')} · ${t.label}',style:Theme.of(context).textTheme.titleMedium),
      const SizedBox(height:10),const Text('Ücretsiz ipucu ve sınırsız deneme. Seçimlerin cihazda saklanır; ilerleme ve ödül bağlantı olduğunda doğrulanır.'),
      const SizedBox(height:20),FilledButton.icon(key:const ValueKey('docu-start'),onPressed:c.busy?null:(){_startWithEnergy();_top();},icon:const Icon(Icons.play_arrow),label:Text('${t.text('title')} görevine başla')),
    ];
  }
  List<Widget> _task(FootballDocuController c) {
    final t=c.active!,d=c.catalog.episode(t.episodeId);
    return [
      Text('${d.text('club')} · ${d.text('period')}',style:Theme.of(context).textTheme.titleMedium),
      const SizedBox(height:10),Wrap(spacing:8,runSpacing:8,children:[Chip(label:Text('${t.stage}/2 · ${t.text('title')}')),Chip(avatar:Icon(_icon(t.mechanic),size:18),label:Text(t.label))]),
      const SizedBox(height:16),Text(t.text('prompt'),style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:18),
      PitchPanel(child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Icon(_icon(t.mechanic),size:30),const SizedBox(width:12),Expanded(child:Text(switch(t.mechanic){
          'evidence'=>'KANIT PANOSU\nHer belgeyi sorudaki olayla buluştur.',
          'timeline'=>'KURGU MASASI\nOlayları en eskiden en yeniye diz.',
          'headline'=>'MANŞET MASASI\nİddianın tamamını doğru ya da yanlış olarak değerlendir.',
          'turning'=>'KIRILMA ANI\nHikâyeyi değiştiren somut ayrıntıyı bul.',
          _=>'PERDE ARKASI\nRol ve dönem ipuçlarından kişiyi bul.',
        })),
      ])),
      const SizedBox(height:16),
      if(t.interaction=='order') ..._order(c)
      else if(t.interaction=='match') ..._matching(c)
      else ..._choices(c),
      const SizedBox(height:12),TextButton.icon(key:const ValueKey('docu-hint'),onPressed:c.hint,icon:const Icon(Icons.lightbulb_outline),label:const Text('Ücretsiz ipucu')),
      if(c.hintOpen) PitchPanel(child:Text(t.text('hint'))),
      if(c.hints.containsKey(t.id)) Padding(padding:const EdgeInsets.only(top:12),child:PitchPanel(child:Text(docuMap(c.hints[t.id])['text']?.toString()??''))),
      if(t.interaction!='boolean'&&!c.hints.containsKey(t.id)&&!c.results.containsKey(t.id)) TextButton(key:const ValueKey('docu-extra-help'),onPressed:c.busy?null:()async{
        final taskId=t.id,price=c.pro?0:6;
        final yes=await showDialog<bool>(context:context,builder:(dialog)=>AlertDialog(title:const Text('Ek yardım'),
          content:Text(price==0?'Pro hesabında ücretsiz ek yardımı aç?':'Bu görev için ek yardımı 6 Coin karşılığında aç?'),
          actions:[TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('Aç'))]));
        if(yes==true&&mounted&&identical(c,_c)&&c.activeId==taskId) await c.buyHint(maxPrice:price);
      },child:Text(c.pro?'Pro · Ek yardım':'Ek yardım · 6 Coin')),
      const SizedBox(height:14),FilledButton(key:const ValueKey('docu-submit'),onPressed:c.busy||!c.canSubmit?null:()async{await c.submit();if(mounted&&c.phase=='result')_top();},child:Text(c.busy?'Doğrulanıyor…':'Cevabı kontrol et')),
    ];
  }
  List<Widget> _choices(FootballDocuController c) {
    final t=c.active!,multiple=t.interaction=='multi';
    return [
      Text(multiple?'${t.requiredCount} kart seç · ${c.answers.length}/${t.requiredCount} seçildi':t.interaction=='boolean'?'Manşeti doğrula':'Bir kart seç',style:Theme.of(context).textTheme.titleSmall),
      const SizedBox(height:12),
      for(final o in t.options) Padding(padding:const EdgeInsets.only(bottom:10),child:Semantics(
        selected:c.answers.contains(o['id']),button:true,
        child:PitchRow(key:ValueKey('option-${o['id']}'),title:o['label'] as String,
          leading:t.mechanic=='person'?SizedBox(width:48,height:48,child:ClipOval(child:PlayerPortrait(playerId:(o['playerId'] as num?)?.toInt()??-1,size:48,fallback:ColoredBox(color:Theme.of(context).colorScheme.primaryContainer,child:Center(child:Text((o['label'] as String).split(' ').map((s)=>s.characters.first).take(2).join(),style:const TextStyle(fontWeight:FontWeight.bold))))))):null,
          icon:c.answers.contains(o['id'])?(multiple?Icons.check_box:Icons.radio_button_checked):(multiple?Icons.check_box_outline_blank:Icons.radio_button_off),
          highlight:c.answers.contains(o['id']),trailing:t.mechanic=='person'?Icon(c.answers.contains(o['id'])?Icons.check_circle:Icons.circle_outlined):const SizedBox.shrink(),onTap:c.busy?null:()=>c.choose(o['id'] as String)))),
    ];
  }
  List<Widget> _order(FootballDocuController c) {
    final t=c.active!;
    return [const Text('En erken olay üstte. Basılı tutup sürükle veya yukarı/aşağı düğmelerini kullan.'),const SizedBox(height:12),
      for(var i=0;i<c.answers.length;i++) Padding(padding:const EdgeInsets.only(bottom:10),child:DragTarget<int>(
        onWillAcceptWithDetails:(details)=>!c.busy && details.data!=i,
        onAcceptWithDetails:(details)=>c.move(details.data,i-details.data),
        builder:(context,candidate,rejected)=>LongPressDraggable<int>(
          data:i,maxSimultaneousDrags:c.busy?0:1,
          feedback:Material(borderRadius:BorderRadius.circular(16),child:SizedBox(width:230,child:Padding(padding:const EdgeInsets.all(16),child:Text(t.optionLabel(c.answers[i]))))),
          child:PitchPanel(key:ValueKey('event-${c.answers[i]}'),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
            if(candidate.isNotEmpty) const LinearProgressIndicator(),
            Text('${i+1}. ${t.optionLabel(c.answers[i])}',style:Theme.of(context).textTheme.titleMedium),
            Row(mainAxisAlignment:MainAxisAlignment.end,children:[
              const Icon(Icons.drag_indicator),const Spacer(),
              IconButton(key:ValueKey('up-$i'),tooltip:'Yukarı taşı',onPressed:c.busy||i==0?null:()=>c.move(i,-1),icon:const Icon(Icons.arrow_upward)),
              IconButton(key:ValueKey('down-$i'),tooltip:'Aşağı taşı',onPressed:c.busy||i==c.answers.length-1?null:()=>c.move(i,1),icon:const Icon(Icons.arrow_downward)),
            ])])),
        ))),
    ];
  }
  List<Widget> _matching(FootballDocuController c) {
    final t=c.active!;
    return [const Text('Kartları basılı tutup kanıt alanına sürükle veya Kart seç düğmesini kullan. Aynı kart iki kez kullanılamaz.'),
      const SizedBox(height:12),Wrap(spacing:8,runSpacing:8,children:[
        for(final o in t.options) LongPressDraggable<String>(data:o['id'] as String,maxSimultaneousDrags:c.busy?0:1,
          feedback:Material(child:SizedBox(width:200,child:Padding(padding:const EdgeInsets.all(12),child:Text(o['label'] as String)))),
          child:Chip(avatar:const Icon(Icons.push_pin_outlined,size:18),label:Text(o['label'] as String))),
      ]),
      for(var i=0;i<t.slots.length;i++) Padding(padding:const EdgeInsets.symmetric(vertical:8),child:DragTarget<String>(
        onWillAcceptWithDetails:(details)=>!c.busy && t.optionIds.contains(details.data),
        onAcceptWithDetails:(details)=>c.assign(i,details.data),
        builder:(context,candidate,rejected)=>PitchPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          if(candidate.isNotEmpty) const LinearProgressIndicator(),
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
        ])))),
    ];
  }
  List<Widget> _result(FootballDocuController c) {
    final t=c.active!,d=c.catalog.episode(t.episodeId),r=docuMap(c.results[t.id]),reward=docuMap(c.rewards[t.id]);
    final filed=c.files.containsKey(d.id);
    return [
      _hero(filed?'BELGESEL DOSYASI TAMAMLANDI':'ARA SAHNE · İLK KANIT',d.text('club'),'${d.text('period')} · ${t.text('title')}',
        footer:Text(filed?'2 / 2 araştırma · Arşiv kaydı açıldı':'1 / 2 araştırma · Hikâye devam ediyor',style:const TextStyle(color:Color(0xFFBDEA84)))),
      const SizedBox(height:20),PitchPanel(key:const ValueKey('docu-result'),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Text('Tarihin cevabı'),const SizedBox(height:10),Text(r['answer']?.toString()??'',style:Theme.of(context).textTheme.titleMedium),
      ])),
      const SizedBox(height:16),PitchPanel(child:Text(r['evidence']?.toString()??'')),
      if(t.stage==1&&!filed) ...[const SizedBox(height:16),PitchPanel(key:const ValueKey('docu-interlude'),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Hikâye devam ediyor',style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:12),Text(r['interlude']?.toString()??''),
      ]))],
      if(filed)...[const SizedBox(height:16),PitchPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        _fileIcon(d,true),const SizedBox(height:12),Text(docuMap(c.files[d.id])['story']?.toString()??''),
      ]))],
      const SizedBox(height:16),PitchPanel(child:Text(reward['settled']==true?'İlk başarı ödülü alındı: 8 Coin + 20 XP. Yeniden oynamak ikinci ödül vermez.':'8 Coin + 20 XP ödülün bekliyor. Bağlantını kontrol et; misafirsen bu hesabı Google’a bağlayıp eşitle.')),
      if(filed) ...[const SizedBox(height:12),ExpansionTile(key:PageStorageKey('docu-sources-${t.id}'),title:const Text('Tarihsel kaynaklar'),children:[
        for(final raw in r['sources'] as List? ?? []) Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(Uri.parse(docuMap(raw)['url'] as String).host),Text(docuMap(raw)['url'] as String,style:const TextStyle(fontSize:12)),
          TextButton(onPressed:()async{await Clipboard.setData(ClipboardData(text:docuMap(raw)['url'] as String));},child:const Text('Bağlantıyı kopyala')),
        ])),
      ]),
      ],
      const SizedBox(height:20),
      if(t.stage==1&&!filed) FilledButton(key:const ValueKey('docu-next'),onPressed:c.busy?null:()=>_open(d.taskIds.last),child:const Text('İkinci araştırmaya geç')),
      if(filed) ...[for(final id in d.taskIds) TextButton(onPressed:c.busy?null:()=>_open(id),child:Text('${c.catalog.byId(id).text('title')} sonucunu gör'))],
      if(filed) FilledButton(onPressed:c.busy?null:(){c.archive();_top();setState(()=>_collection=true);},child:const Text('Belgesel Arşivi’ne dön')),
      const SizedBox(height:8),OutlinedButton(onPressed:c.busy?null:()=>_open(t.id,replay:true),child:const Text('Yeniden oyna · ödülsüz')),
    ];
  }
}
