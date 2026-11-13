import '../widgets/story_support_panel.dart';
import '../widgets/energy_sheet.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import '../controllers/derby_day_controller.dart';
import '../models/derby_task.dart';
import '../services/auth_service.dart';
import '../services/derby_day_service.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/player_portrait.dart';



class DerbyDayPage extends StatefulWidget {
  const DerbyDayPage({super.key, this.controller, this.openCollection = false, this.country});
  final DerbyDayController? controller;
  final bool openCollection;
  final String? country;
  @override
  State<DerbyDayPage> createState() => _DerbyDayPageState();
}
class _DerbyDayPageState extends State<DerbyDayPage> {
  DerbyDayController? _c;
  StreamSubscription<dynamic>? _auth;
  String? _uid;
  String? _loadError;
  int _generation = 0;
  bool _collection = false;
  String _country = 'all', _club = 'all', _progress = 'all', _mechanic = 'all', _query = '';
  final _search = TextEditingController();
  final _scroll = ScrollController(keepScrollOffset: false);
  Future<void> _startWithEnergy() async {
    final controller = _c;
    final id = controller?.activeId;
    if (controller == null || id == null) return;
    if (widget.controller != null || await StoryEnergyAccess.open(context, 'derby', id)) {
      if (!mounted || _c != controller || controller.activeId != id) return;
      controller.start(); _top();
    }
  }
  @override
  void initState() {
    super.initState();
    _collection = widget.openCollection;
    _country = widget.country ?? 'all';
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
    DerbyDayController? created;
    try {
      if (AuthService.uid == null && Firebase.apps.isNotEmpty) {
        try { await AuthService.ensureGuestSignedIn(); } catch (_) { /* Offline drafts remain available. */ }
      }
      if (!mounted || generation != _generation) return;
      final uid = AuthService.uid;
      final catalog = await DerbyDayCatalog.load();
      if (!mounted || generation != _generation) return;
      created = DerbyDayController(catalog: catalog,
          store: LocalDerbyDayStore(uid), gateway: FirebaseDerbyDayGateway(uid));
      // Attach before network sync so the catalog is usable when offline.
      setState(() { _c = created; });
      await created.load();
      if (widget.openCollection && mounted && generation == _generation) created.archive();
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(() { _loadError = 'Derbi Pasaportu açılamadı. Cihaz kaydını koruyarak yeniden dene.'; });
      }
    }
  }
  void _top() {
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }
  void _open(String id, {bool replay = false}) { _c!.open(id, replay: replay); _top(); }
  @override
  void dispose() {
    _generation++; _auth?.cancel(); _scroll.dispose(); _search.dispose();
    if (widget.controller == null) _c?.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    final c = _c;
    if (_loadError != null) return Scaffold(appBar: AppBar(title: const Text('Derby Day', maxLines: 1, overflow: TextOverflow.ellipsis)),
      body: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min,
        children: [Text(_loadError!), const SizedBox(height: 16), FilledButton(onPressed: _boot, child: const Text('Yeniden dene'))]))));
    if (c == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return AnimatedBuilder(animation: c, builder: (context, _) => PopScope(
      canPop: c.phase == 'archive',
      onPopInvokedWithResult: (didPop, _) { if (!didPop && !c.busy) { c.archive(); _top(); } },
      child: Scaffold(
        appBar: AppBar(title: const Text('Derby Day', maxLines: 1, overflow: TextOverflow.ellipsis),
          leading: c.phase == 'archive' ? null : IconButton(tooltip: 'Atlasa dön',
              onPressed: c.busy ? null : () { c.archive(); _top(); }, icon: const Icon(Icons.arrow_back)),
          actions: [IconButton(tooltip: 'Eşitle', onPressed: c.busy ? null : c.sync, icon: const Icon(Icons.sync))]),
        body: !c.ready ? const Center(child: CircularProgressIndicator()) : SafeArea(child: ListView(
          // Each phase owns its lazy-list layout; a solved task must not reuse
          // the previous question's retained children or scroll position.
          key: ValueKey('derby-scroll-${c.phase}-${c.activeId ?? "archive"}'), controller: _scroll,
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
  IconData _icon(String type)=>switch(type){'memory'=>Icons.scoreboard_outlined,'identity'=>Icons.location_on_outlined,'timeline'=>Icons.swap_vert,'two_shirts'=>Icons.checkroom,_=>Icons.person_search_outlined};
  Widget _hero(String eyebrow, String title, String subtitle, {Widget? footer}) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(begin:Alignment.topLeft,end:Alignment.bottomRight,
        colors:[Color(0xFF193E3A),Color(0xFF0D1B21)]),
      border: Border.all(color:const Color(0xFF557A63))),
    child: Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Icon(Icons.public,size:36,color:Color(0xFFBDEA84)),
      const SizedBox(height:14),Text(eyebrow,style:const TextStyle(color:Color(0xFFBDEA84),fontSize:12,fontWeight:FontWeight.w700)),
      const SizedBox(height:10),Text(title,style:const TextStyle(color:Colors.white,fontSize:27,fontWeight:FontWeight.w800,height:1.15)),
      const SizedBox(height:12),Text(subtitle,style:const TextStyle(color:Color(0xFFDAE6E8),height:1.45)),
      if(footer!=null)...[const SizedBox(height:18),footer],
    ]));
  Widget _filter(String label, String value, List<String> values, ValueChanged<String> change) => DropdownButtonFormField<String>(
    key:ValueKey('filter-$label-$value'),initialValue:value,isExpanded:true,decoration:InputDecoration(labelText:label),
    items:values.map((v)=>DropdownMenuItem(value:v,child:Text(v=='all'?'Tümü':v,maxLines:1,overflow:TextOverflow.ellipsis))).toList(),
    onChanged:(v){if(v!=null)setState(()=>change(v));});
  List<Widget> _archive(DerbyDayController c) {
    final clubs=c.catalog.tasks.expand((t)=>t.clubs).toSet().toList()..sort();
    final visible=c.catalog.tasks.where((t)=>(_country=='all'||t.text('country')==_country)&&(_club=='all'||t.clubs.contains(_club))&&
      (_mechanic=='all'||t.label==_mechanic)&&(_progress=='all'||(_progress=='Tamamlanan'?c.stamps.containsKey(t.id):!c.stamps.containsKey(t.id)))&&
      derbySearch('${t.text('title')} ${t.text('country')} ${t.text('city')} ${t.text('rivalryName')}').contains(derbySearch(_query))).toList();
    return [
      _hero(_collection?'DERBİ PASAPORTU':'REKABET ATLASI',_collection?'Her damga,\nbir hikâye.':'Bir dünya.\n48 rekabet.',
        '16 ülkeyi keşfet. Şehirleri, formaları ve unutulmaz maçları aynı pasaportta buluştur.',
        footer:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('${c.stampCount} / 48 damga',style:const TextStyle(color:Colors.white,fontWeight:FontWeight.bold)),
          const SizedBox(height:12),LinearProgressIndicator(value:c.stampCount/48,minHeight:6,color:const Color(0xFFBDEA84),backgroundColor:Colors.white12)])),
      const SizedBox(height:16),const Text('İlk başarı: 8 Coin + 20 XP. Her rekabet, tek görev ve kalıcı bir pasaport damgası.'),
      if(!c.rewardEligible) const Padding(padding:EdgeInsets.only(top:8),child:Text('Misafir olarak oynayabilirsin. Ödüllerini almak için bu misafir hesabını Google’a bağla.')),
      if(c.pending.isNotEmpty) Padding(padding:const EdgeInsets.only(top:12),child:Text('${c.pending.length} cevap doğrulama bekliyor. Bağlantı gelince Eşitle’ye dokun.')),
      const SizedBox(height:14),Wrap(spacing:8,runSpacing:8,children:[
        ChoiceChip(key:const ValueKey('derby-atlas'),label:const Text('Rekabet Atlası'),selected:!_collection,onSelected:(_)=>setState(()=>_collection=false)),
        ChoiceChip(key:const ValueKey('derby-collection'),label:const Text('Derbi Pasaportu'),selected:_collection,onSelected:(_)=>setState(()=>_collection=true)),
      ]),
      if(_collection)...[
        const PitchSectionTitle('Pasaport rozetleri'),
        for(final raw in c.catalog.economy['milestones'] as List) Padding(padding:const EdgeInsets.only(bottom:10),child:PitchPanel(key:ValueKey('badge-${derbyMap(raw)['count']}'),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Icon(c.stampCount>=derbyMap(raw)['count']?Icons.verified:Icons.lock_outline,color:Theme.of(context).colorScheme.primary),
          const SizedBox(height:8),Text('${derbyMap(raw)['title']} · ${derbyMap(raw)['count']} damga',style:Theme.of(context).textTheme.titleMedium),
          const SizedBox(height:6),Text('+${derbyMap(raw)['coins']} Coin / +${derbyMap(raw)['xp']} XP'),
          Text(c.stampCount<derbyMap(raw)['count']?'Keşfetmeye devam et':derbyMap(c.rewards['milestone_${derbyMap(raw)['count']}'])['settled']==true?'Rozet açıldı · Ödül alındı':'Rozet açıldı · Ödül eşitlemesi bekliyor'),
        ]))),
      ],
      const SizedBox(height:14),TextField(key:const ValueKey('derby-search'),controller:_search,onChanged:(v)=>setState(()=>_query=v),
        decoration:InputDecoration(labelText:'Kulüp, ülke veya şehir ara',prefixIcon:const Icon(Icons.search),suffixIcon:_query.isEmpty?null:IconButton(tooltip:'Aramayı temizle',onPressed:(){_search.clear();setState(()=>_query='');},icon:const Icon(Icons.close)))),
      ExpansionTile(title:const Text('Ülke, kulüp ve ilerleme filtreleri'),children:[
        _filter('Ülke',_country,['all',...c.catalog.countries],(v)=>_country=v),const SizedBox(height:12),
        _filter('Kulüp',_club,['all',...clubs],(v)=>_club=v),const SizedBox(height:12),
        _filter('Görev türü',_mechanic,['all',...c.catalog.tasks.map((t)=>t.label).toSet()],(v)=>_mechanic=v),const SizedBox(height:12),
        _filter('İlerleme',_progress,['all','Tamamlanan','Keşfedilecek'],(v)=>_progress=v),const SizedBox(height:12),
        TextButton(onPressed:(){_search.clear();setState((){_country=_club=_mechanic=_progress='all';_query='';});},child:const Text('Filtreleri temizle')),
      ]),
      if(c.activeId!=null&&!c.results.containsKey(c.activeId)) Padding(padding:const EdgeInsets.symmetric(vertical:12),child:PitchRow(title:'Kaldığın yerden',subtitle:c.active!.text('title'),icon:Icons.play_circle_outline,onTap:c.busy?null:(){_open(c.activeId!);_startWithEnergy();})),
      Text('${visible.length} rekabet',key:const ValueKey('derby-visible-count')),
      if(visible.isEmpty) const Padding(padding:EdgeInsets.symmetric(vertical:24),child:Text('Bu filtrelerde rekabet bulunamadı. Aramayı veya filtreleri değiştir.')),
      for(final country in c.catalog.countries) ...[
        if(visible.any((t)=>t.text('country')==country)) PitchSectionTitle('$country · ${c.catalog.tasks.where((t)=>t.text('country')==country&&c.stamps.containsKey(t.id)).length}/${c.catalog.tasks.where((t)=>t.text('country')==country).length}'),
        for(final t in visible.where((t)=>t.text('country')==country)) Padding(padding:const EdgeInsets.only(bottom:12),child:PitchPanel(key:ValueKey('rivalry-${t.id}'),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Wrap(spacing:8,runSpacing:4,children:[Text(t.id,style:Theme.of(context).textTheme.labelSmall),if(t.text('rivalryName').isNotEmpty) Text(t.text('rivalryName')),if(t.text('origin')=='pdf_final') const Text('YENİ',style:TextStyle(fontWeight:FontWeight.bold)),
            Text(c.stamps.containsKey(t.id)?'✓ DAMGALANDI':t.label)]),
          const SizedBox(height:8),Text(t.text('title'),style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:8),Text(t.text('city')),
          if(_collection&&c.stamps.containsKey(t.id)) ...[const SizedBox(height:8),Text('Hatıra: ${derbyMap(c.stamps[t.id])['period']}'),Text('Damga: ${_date((derbyMap(c.stamps[t.id])['earnedAt'] as num?)?.toInt()??0)}')],
          const SizedBox(height:12),OutlinedButton.icon(key:ValueKey('open-${t.id}'),onPressed:c.busy?null:()=>_open(t.id),icon:Icon(c.stamps.containsKey(t.id)?Icons.verified:_icon(t.mechanic)),label:Text(c.stamps.containsKey(t.id)?'Hatırayı aç':'Rekabeti keşfet')),
        ]))),
      ],
    ];
  }
  String _date(int ms) {if(ms<=0)return 'Eşitleniyor';final d=DateTime.fromMillisecondsSinceEpoch(ms).toLocal();return '${d.day}.${d.month}.${d.year}';}
  List<Widget> _intro(DerbyDayController c) {
    final t=c.active!;
    return [_hero('${t.text('country')} · ${t.text('city')}',t.text('title'),t.text('intro')),
      const SizedBox(height:20),PitchPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(_icon(t.mechanic),size:32),const SizedBox(height:12),Text(t.label,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:10),const Text('Bir görev, bir pasaport damgası. İsteğe bağlı destek ve sınırsız deneme. İlerleme ve ödül bağlantı olduğunda doğrulanır.')])),
      const SizedBox(height:20),FilledButton.icon(key:const ValueKey('derby-start'),onPressed:c.busy?null:(){_startWithEnergy();_top();},icon:const Icon(Icons.play_arrow),label:const Text('Derbiye başla'))];
  }
  Widget _scene(DerbyDayController c) {
    final t=c.active!;
    return PitchPanel(key:ValueKey('scene-${t.mechanic}'),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      if(t.mechanic=='memory') ...[
        const Center(child:Icon(Icons.scoreboard_outlined,size:40)),const SizedBox(height:12),
        const Text('MAÇ HAFIZASI',textAlign:TextAlign.center),const SizedBox(height:12),
        Text(c.answers.isEmpty?'? – ?':t.optionLabel(c.answers.single),textAlign:TextAlign.center,style:const TextStyle(fontSize:42,fontWeight:FontWeight.w800,fontFeatures:[FontFeature.tabularFigures()])),
        const Text('Skor sırası soruda belirtilmiştir.',textAlign:TextAlign.center),
      ] else if(t.mechanic=='two_shirts') ...[
        const Text('KARİYER KARTI',textAlign:TextAlign.center),const SizedBox(height:16),
        for(final club in t.clubs) Padding(padding:const EdgeInsets.only(bottom:12),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.checkroom,size:32),const SizedBox(width:12),Expanded(child:Text(club,style:Theme.of(context).textTheme.titleMedium))])),
        const Divider(),const Text('İki forma · Aynı futbolcu',textAlign:TextAlign.center),
      ] else if(t.mechanic=='legend') ...[
        const Center(child:CircleAvatar(radius:42,child:Icon(Icons.person_outline,size:58))),const SizedBox(height:14),
        const Text('PORTRE HENÜZ GİZLİ',textAlign:TextAlign.center),const SizedBox(height:8),const Text('Tarih, rol ve performans ipuçlarından ismi bul.',textAlign:TextAlign.center),
      ] else if(t.mechanic=='identity') ...[
        const Icon(Icons.location_on_outlined,size:42),const SizedBox(height:12),Text(t.text('city'),textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:12),const Text('Şehirden, stadyumdan veya gelenekten gelen izi takip et.',textAlign:TextAlign.center),
      ] else ...[const Icon(Icons.route_outlined,size:42),const SizedBox(height:12),const Text('ZAMAN ÇİZGİSİ',textAlign:TextAlign.center),const SizedBox(height:8),const Text('En eski olaydan en yeniye doğru ilerle.',textAlign:TextAlign.center)],
    ]));
  }
  List<Widget> _task(DerbyDayController c) {
    final t=c.active!;
    return [Text(t.text('title'),style:Theme.of(context).textTheme.titleMedium),const SizedBox(height:10),Text(t.label,style:Theme.of(context).textTheme.labelLarge),const SizedBox(height:16),
      Text(t.text('prompt'),style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:18),_scene(c),const SizedBox(height:16),
      if(t.ordered)..._order(c) else ...[
        const Text('Bir seçenek seç'),const SizedBox(height:12),
        for(final o in t.options) Padding(padding:const EdgeInsets.only(bottom:10),child:Semantics(selected:c.answers.contains(o['id']),button:true,
          child:PitchRow(key:ValueKey('option-${o['id']}'),title:o['label'] as String,icon:c.answers.contains(o['id'])?Icons.radio_button_checked:Icons.radio_button_off,highlight:c.answers.contains(o['id']),trailing:const SizedBox.shrink(),onTap:c.busy?null:()=>c.choose(o['id'] as String)))),
      ],
      StorySupportPanel(mode: 'derby_day', targetId: t.id, disabled: c.busy,
        knownBasic: c.hintOpen ? t.text('hint') : null,
        legacy: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SizedBox(height:12),TextButton.icon(key:const ValueKey('derby-hint'),onPressed:c.hint,icon:const Icon(Icons.lightbulb_outline),label:const Text('Ücretsiz ipucu')),
      if(c.hintOpen) PitchPanel(child:Text(t.text('hint'))),
      if(c.hints.containsKey(t.id)) Padding(padding:const EdgeInsets.only(top:12),child:PitchPanel(child:Text(derbyMap(c.hints[t.id])['text']?.toString()??''))),
      if(t.interaction!='boolean'&&!c.hints.containsKey(t.id)&&!c.results.containsKey(t.id)) TextButton(key:const ValueKey('derby-extra-help'),onPressed:c.busy?null:()async{
        final taskId=t.id,price=c.pro?0:6;
        final yes=await showDialog<bool>(context:context,builder:(dialog)=>AlertDialog(title:const Text('Ek yardım'),
          content:Text(price==0?'Pro hesabında ücretsiz ek yardımı aç?':'Bu görev için ek yardımı 6 Coin karşılığında aç?'),
          actions:[TextButton(onPressed:()=>Navigator.pop(dialog,false),child:const Text('Vazgeç')),FilledButton(onPressed:()=>Navigator.pop(dialog,true),child:const Text('Aç'))]));
        if(yes==true&&mounted&&identical(c,_c)&&c.activeId==taskId) await c.buyHint(maxPrice:price);
      },child:Text(c.pro?'Pro · Ek yardım':'Ek yardım · 6 Coin')),
      ])),
      const SizedBox(height:14),FilledButton(key:const ValueKey('derby-submit'),onPressed:c.busy||!c.canSubmit?null:()async{await c.submit();if(mounted&&c.phase=='result')_top();},child:Text(c.busy?'Doğrulanıyor…':'Cevabı kontrol et')),
    ];
  }
  List<Widget> _order(DerbyDayController c) {
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
  List<Widget> _result(DerbyDayController c) {
    final t=c.active!,r=derbyMap(c.results[t.id]),reward=derbyMap(c.rewards[t.id]),stamp=derbyMap(c.stamps[t.id]);
    return [
      StorySupportPanel(mode: 'derby_day', targetId: t.id, resultOnly: true, legacy: const SizedBox.shrink()),
_hero('PASAPORT DAMGASI AÇILDI',t.text('title'),'${t.text('country')} · ${t.text('city')}',footer:Text('${_date((stamp['earnedAt'] as num?)?.toInt()??0)} · ${c.stampCount}/48',style:const TextStyle(color:Color(0xFFBDEA84)))),
      if(t.mechanic=='legend') ...[const SizedBox(height:16),Center(child:PlayerPortrait(playerId:(r['playerId'] as num?)?.toInt()??-1,size:88,fallback:CircleAvatar(radius:44,child:Text((r['answer']?.toString()??'?').split(' ').where((s)=>s.isNotEmpty).map((s)=>s.characters.first).take(2).join()))))],
      const SizedBox(height:20),PitchPanel(key:const ValueKey('derby-result'),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        const Icon(Icons.verified_outlined,size:40),const SizedBox(height:12),Text(r['period']?.toString()??'',style:Theme.of(context).textTheme.labelLarge),const SizedBox(height:12),
        Text(r['answer']?.toString()??'',style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:16),Text(r['evidence']?.toString()??''),
      ])),
      const SizedBox(height:16),PitchPanel(child:Text(reward['settled']==true?'İlk başarı ödülü alındı: 8 Coin + 20 XP. Yeniden oynamak ikinci ödül vermez.':'8 Coin + 20 XP ödülün bekliyor. Bağlantını kontrol et; misafirsen bu hesabı Google’a bağlayıp eşitle.')),
      const SizedBox(height:12),ExpansionTile(key:PageStorageKey('derby-sources-${t.id}'),title:const Text('Tarihsel kaynaklar'),children:[
        for(final raw in r['sources'] as List? ?? []) Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(derbyMap(raw)['name'] as String),Text(derbyMap(raw)['url'] as String,style:const TextStyle(fontSize:12)),
          TextButton(onPressed:()async{await Clipboard.setData(ClipboardData(text:derbyMap(raw)['url'] as String));},child:const Text('Bağlantıyı kopyala')),
        ])),
      ]),const SizedBox(height:20),FilledButton(key:const ValueKey('derby-passport'),onPressed:c.busy?null:(){c.archive();_top();setState(()=>_collection=true);},child:const Text('Derbi Pasaportu’nu aç')),
      const SizedBox(height:8),OutlinedButton(onPressed:c.busy?null:()=>_open(t.id,replay:true),child:const Text('Yeniden oyna · ödülsüz')),
      const SizedBox(height:8),TextButton(onPressed:c.busy?null:(){c.archive();_top();setState(()=>_collection=false);},child:const Text('Atlasa dön')),
    ];
  }
}
