import 'dart:async';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../app/route_appearance.dart';
import '../controllers/what_if_controller.dart';
import '../models/what_if.dart';
import '../models/rewarded_ad_models.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/pitch_ui.dart';

// Preserve the old entry point used by the Story hub.
class LegendsPathPartSelectionPage extends WhatIfPage {
  const LegendsPathPartSelectionPage({super.key});
}
class WhatIfPage extends StatefulWidget {
  const WhatIfPage({super.key,this.controller,this.archive=false});
  final WhatIfController? controller;
  final bool archive;
  @override
  State<WhatIfPage> createState()=>_WhatIfPageState();
}
class _WhatIfPageState extends State<WhatIfPage> {
  WhatIfController? c;
  String? loadError;
  int? chapter;
  late bool archive=widget.archive;
  String filter='Tümü';
  @override
  void initState(){super.initState();_load();}
  Future<void> _load() async {
    setState(()=>loadError=null);
    try {
      final controller=widget.controller ?? WhatIfController(catalog:await WhatIfCatalog.load());
      if(!mounted){if(widget.controller==null)controller.dispose();return;}
      c?.removeListener(_changed);
      c=controller;c!.addListener(_changed);
      await c!.initialize();if(!mounted)return;setState((){});unawaited(c!.sync());
    }catch(_){if(mounted)setState(()=>loadError='Hikâyeler yüklenemedi. Yeniden dene.');}
  }
  void _changed(){if(mounted)setState((){});}
  @override
  void dispose(){c?.removeListener(_changed);if(widget.controller==null)c?.dispose();super.dispose();}
  Future<void> _open(WhatIfScenario s) async {
    await Navigator.of(context).push(LinkballRoute(builder:(_)=>WhatIfPlayPage(controller:c!,scenario:s)));
    if(mounted)unawaited(c!.sync());
  }
  @override
  Widget build(BuildContext context){
    final game=c;
    return Scaffold(appBar:AppBar(title:Text(archive?'Kader Arşivi':'WHAT IF'),actions:[
      if(game!=null)IconButton(tooltip:'Ödülleri eşitle',onPressed:game.syncing?null:game.sync,icon:const Icon(Icons.sync)),
    ]),body:SafeArea(child:loadError!=null?Center(child:TextButton(onPressed:_load,child:Text(loadError!))):
      game==null||game.loading?const Center(child:CircularProgressIndicator()):
      game.error!=null?Center(child:TextButton(onPressed:game.initialize,child:Text(game.error!))):
      ListView(padding:const EdgeInsets.fromLTRB(20,12,20,32),children:[
        _WhatIfHero(eyebrow:archive?'KADER ARŞİVİ':'FUTBOLUN PARALEL EVRENLERİ',
          title:archive?'Her karar bir iz bırakır.':'Bir karar.\nBaşka bir futbol tarihi.',
          subtitle:archive?'${game.complete}/24 kader kartı · ${game.dual} çift evren':'24 hikâye · 3 bölüm · Her hikâyede 2 son',
          progress:game.complete/24),
        const SizedBox(height:16),
        Wrap(spacing:8,runSpacing:8,children:[
          ChoiceChip(label:const Text('Hikâyeler'),selected:!archive,onSelected:(_)=>setState(()=>archive=false)),
          ChoiceChip(label:const Text('Kader Arşivi'),selected:archive,onSelected:(_)=>setState(()=>archive=true)),
        ]),
        if(!game.accountValid)const _Notice('Hesap değişti. Bu ekranı kapatıp yeniden aç.'),
        if(game.message!=null)_Notice(game.message!),
        if(game.syncing)const LinearProgressIndicator(),
        if(!archive && chapter==null)...[
          const PitchSectionTitle('Hangi ihtimali açacaksın?'),
          for(final ch in game.catalog.chapters)Padding(padding:const EdgeInsets.only(bottom:12),child:PitchRow(
            key:ValueKey('what-if-chapter-${ch['id']}'),title:'${ch['id'].toString().padLeft(2,'0')} · ${ch['title']}',
            subtitle:'${ch['subtitle']}\n${game.catalog.scenarios.where((s)=>s.chapter==ch['id']&&game.ends(s).isNotEmpty).length}/8 hikâye keşfedildi',
            icon:Icons.alt_route_rounded,highlight:true,onTap:()=>setState(()=>chapter=ch['id'] as int),
          )),
          const _Notice('Kararların yanlış sayılmaz. Her yol bir futbol göreviyle açılır; alternatif sonuçlar açıkça kurgu olarak anlatılır.'),
        ]else...[
          if(!archive)TextButton.icon(onPressed:()=>setState(()=>chapter=null),icon:const Icon(Icons.arrow_back),label:const Text('Bütün bölümler')),
          if(!archive)_chapterReward(game,chapter!),
          if(archive)...[
            const PitchSectionTitle('Keşiflerini yeniden oku'),
            Wrap(spacing:8,runSpacing:8,children:[for(final f in ['Tümü','Keşfedilen','Çift evren','Favoriler'])
              FilterChip(label:Text(f),selected:filter==f,onSelected:(_)=>setState(()=>filter=f))]),
            const SizedBox(height:12),
            const Text('Kalp: cihaz favorisi · Yıldız: doğrulanmış kartı profil vitrinine ekle (en fazla 3).'),
            const SizedBox(height:12),
          ],
          if(_visible(game).isEmpty)const _Notice('Bu filtrede henüz kart yok. Bir hikâye seçip ilk sonunu keşfet.'),
          for(final s in _visible(game))Padding(padding:const EdgeInsets.only(bottom:12),child:_scenario(game,s)),
          if(archive)const _Notice('İlk bitiriş: 10 Coin + 25 XP. Bölüm: 60 Coin + 100 XP. İkinci son kartını çift evrene dönüştürür; tekrar ödeme yapmaz. Rozetlerin profilindeki Rozet Koleksiyonu’na eklenir.'),
        ],
      ])));
  }
  List<WhatIfScenario> _visible(WhatIfController g)=>g.catalog.scenarios.where((s)=>
    (archive||s.chapter==chapter) && (!archive||switch(filter){
      'Keşfedilen'=>g.ends(s).isNotEmpty,'Çift evren'=>g.ends(s).length==2,
      'Favoriler'=>g.favorites.contains(s.id),_=>true,
    })).toList();
  Widget _chapterReward(WhatIfController g,int chapter){
    final base=rewardMap(g.rewards['chapter__$chapter']);
    final bonus=rewardMap(g.rewards['double__$chapter']);
    return Padding(padding:const EdgeInsets.only(bottom:16),child:PitchPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text(g.catalog.chapters[chapter-1]['title'] as String,style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:8),Text(base['settled']==true?'Bölüm ödülü hesabına işlendi: 60 Coin + 100 XP':'8 hikâyenin ilk sonunu keşfet: 60 Coin + 100 XP'),
      if(base['settled']==true && bonus.isEmpty)Padding(padding:const EdgeInsets.only(top:12),child:OutlinedButton.icon(
        onPressed:g.syncing?null:()=>g.action('what_if_double',{'chapter':chapter},ad:true),
        icon:Icon(g.pro?Icons.workspace_premium:Icons.ondemand_video),label:Text(g.pro?'Pro ile +60 Coin':'İsteğe bağlı reklam · +60 Coin'))),
      if(bonus.isNotEmpty)Text(bonus['settled']==true?'Bölüm bonusu da alındı. XP ikiye katlanmaz.':'Bonus hesabına işleniyor; yeniden eşitle.'),
    ])));
  }
  Widget _scenario(WhatIfController g,WhatIfScenario s){
    final seen=g.ends(s),started=g.progress(s).isNotEmpty;
    final verified=rewardMap(rewardMap(cloudProgress(g))[s.id]);
    return PitchPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Row(children:[Expanded(child:Text('${s.year} · ${s.name}',style:Theme.of(context).textTheme.labelLarge)),
        IconButton(tooltip:g.favorites.contains(s.id)?'Favoriden çıkar':'Favorilere ekle',onPressed:g.busy?null:()=>g.favorite(s),
          icon:Icon(g.favorites.contains(s.id)?Icons.favorite:Icons.favorite_border)),
        if(archive && rewardMap(verified['ends']).isNotEmpty)IconButton(tooltip:g.showcase.contains(s.id)?'Vitrinden çıkar':'Profil vitrinine ekle',
          onPressed:g.syncing?null:()=>_showcase(g,s),icon:Icon(g.showcase.contains(s.id)?Icons.star:Icons.star_outline)),
      ]),
      Text(s.title,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:10),
      Wrap(spacing:8,runSpacing:8,children:[
        _Tag(seen.length==2?'Çift evren':'${seen.length}/2 son keşfedildi',seen.length==2?Icons.auto_awesome:Icons.explore_outlined),
        _Tag('2–3 dk',Icons.schedule),
      ]),const SizedBox(height:12),
      FilledButton.tonal(key:ValueKey('what-if-open-${s.id}'),onPressed:()=>_open(s),
        child:Text(seen.length==2?'Yeniden oyna / sonları oku':started?'Devam et':'Kaderi seç')),
    ]));
  }
  Map<String,dynamic> cloudProgress(WhatIfController g)=>rewardMap(g.cloud['progress']);
  void _showcase(WhatIfController g,WhatIfScenario s){
    final ids=g.showcase;
    if(ids.contains(s.id)){ids.remove(s.id);}else if(ids.length<3){ids.add(s.id);}else{
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Önce vitrindeki üç karttan birini çıkar.')));return;
    }
    unawaited(g.action('favorites',{'ids':ids.toList()}));
  }
}

class WhatIfPlayPage extends StatefulWidget {
  const WhatIfPlayPage({super.key,required this.controller,required this.scenario});
  final WhatIfController controller;
  final WhatIfScenario scenario;
  @override
  State<WhatIfPlayPage> createState()=>_WhatIfPlayPageState();
}
class _WhatIfPlayPageState extends State<WhatIfPlayPage>{
  WhatIfController get c=>widget.controller;
  WhatIfScenario get s=>widget.scenario;
  @override
  void initState(){super.initState();c.addListener(_changed);}
  void _changed(){if(mounted)setState((){});}
  @override
  void dispose(){c.removeListener(_changed);super.dispose();}
  @override
  Widget build(BuildContext context){
    final phase=c.phase(s),route=c.route(s),locked=c.busy||!c.accountValid;
    final step=switch(phase){'intro'=>0,'choice'=>1,'task'=>2,_=>3};
    return Scaffold(appBar:AppBar(title:Text(s.name)),body:SafeArea(child:ListView(
      key:PageStorageKey('what-if-${s.id}-$phase'),padding:const EdgeInsets.fromLTRB(20,12,20,32),children:[
      Wrap(spacing:6,runSpacing:8,children:[for(final (i,label) in ['Tarih','Karar','Görev','Son'].indexed)
        _Tag('${i+1} $label',i<step?Icons.check_circle: i==step?Icons.radio_button_checked:Icons.radio_button_unchecked)]),
      const SizedBox(height:20),
      if(!c.accountValid)const _Notice('Hesap değişti. Ekranı kapatıp yeniden aç.'),
      if(c.message!=null)_Notice(c.message!),
      if(phase=='intro')...[
        _WhatIfHero(eyebrow:'${s.year} · KIRILMA ANI',title:s.title,subtitle:'Gerçek geçmiş. Senin seçeceğin ihtimal.'),
        const SizedBox(height:20),
        PitchPanel(key:const ValueKey('what-if-intro'),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const _Tag('GERÇEK TARİH · BAĞLAM',Icons.history),const SizedBox(height:16),Text(s.intro,style:Theme.of(context).textTheme.bodyLarge),
        ])),
        const SizedBox(height:16),FilledButton(key:const ValueKey('what-if-to-choice'),onPressed:locked?null:()=>c.setPhase(s,'choice'),child:const Text('Kaderi seç')),
        TextButton(onPressed:locked?null:()=>c.setPhase(s,'choice'),child:const Text('Metni geç')),
      ],
      if(phase=='choice')...[
        Text('Hangi evreni açalım?',style:Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height:8),const Text('İki karar da geçerli. Seçimin, oynayacağın görevi ve okuyacağın sonu belirler.'),const SizedBox(height:20),
        for(final r in s.routes)Padding(padding:const EdgeInsets.only(bottom:14),child:PitchPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          _Tag(r.fiction?'ALTERNATİF EVREN · KURGU':'GERÇEK ROTA',r.fiction?Icons.alt_route:Icons.history),
          const SizedBox(height:12),Text(r.label,style:Theme.of(context).textTheme.titleLarge),const SizedBox(height:12),
          FilledButton.tonal(key:ValueKey('what-if-route-${r.id}'),onPressed:locked?null:()=>c.selectRoute(s,r.id),child:const Text('Bu yolu oyna')),
          if(c.ends(s).contains(r.id))TextButton(onPressed:locked?null:()=>c.readEnding(s,r.id),child:const Text('Açılmış sonu yeniden oku')),
        ]))),
        TextButton(onPressed:locked?null:()=>c.setPhase(s,'intro'),child:const Text('Arka planı oku')),
      ],
      if(phase=='task' && route!=null)..._task(route,locked),
      if(phase=='result' && route!=null && c.ends(s).contains(route.id))...[
        _WhatIfHero(eyebrow:route.fiction?'ALTERNATİF SON · KURGU':'GERÇEK TARİH · SONUÇ',title:route.label,
          subtitle:'${c.ends(s).length}/2 son keşfedildi · ${c.ends(s).length==2?'Çift evren kartı':'Kader kartı açıldı'}'),
        const SizedBox(height:18),PitchPanel(key:const ValueKey('what-if-ending'),child:Text(route.ending,style:Theme.of(context).textTheme.bodyLarge)),
        const SizedBox(height:12),PitchPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const _Tag('GÖREVİN GERÇEK CEVABI',Icons.fact_check_outlined),const SizedBox(height:12),Text(route.task.explanation),
        ])),const SizedBox(height:12),_reward(),
        const SizedBox(height:16),FilledButton(key:const ValueKey('what-if-other-route'),onPressed:locked?null:()=>c.setPhase(s,'choice'),child:const Text('Diğer evreni keşfet')),
        OutlinedButton(onPressed:()=>Navigator.of(context).pop(),child:const Text('Kader Arşivi / hikâyelere dön')),
        ExpansionTile(title:const Text('Kaynaklar ve kurgu notu'),children:[Padding(padding:const EdgeInsets.all(12),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(s.note),for(final source in s.sources)TextButton(onPressed:() async {
            final ok=await launchUrl(Uri.parse(source['url']!),mode:LaunchMode.externalApplication);
            if(!ok && context.mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Kaynak açılamadı.')));
          },child:Text(source['label']!)),
        ]))]),
      ],
    ])));
  }
  List<Widget> _task(WhatIfRoute r,bool locked){
    final t=r.task,selected=c.picked(s);
    final input={'scenarioId':s.id,'routeId':r.id};
    return [
      _Tag(t.label,Icons.psychology_outlined),const SizedBox(height:12),
      Text(t.prompt,key:const ValueKey('what-if-prompt'),style:Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height:10),Text(t.timeline?'Olaylara eskiden yeniye dokun. Seçili olaya tekrar dokunarak sıradan çıkar.':'Bir cevap seç. Yanlış cevapta tekrar deneyebilirsin.'),
      const SizedBox(height:18),
      for(final key in c.order(s))Padding(padding:const EdgeInsets.only(bottom:10),child:OutlinedButton(
        key:ValueKey('what-if-option-$key'),onPressed:locked?null:()=>c.choose(s,key),
        style:OutlinedButton.styleFrom(alignment:Alignment.centerLeft,padding:const EdgeInsets.all(16),
          backgroundColor:selected.contains(key)?PitchColors.of(context).tint:null),
        child:Row(children:[Icon(selected.contains(key)?Icons.check_circle:Icons.radio_button_unchecked),const SizedBox(width:12),
          Expanded(child:Text('${t.timeline&&selected.contains(key)?'${selected.indexOf(key)+1}. ':''}${t.options[key]}'))]),
      )),
      if(c.feedback!=null)_Notice(c.feedback!),
      FilledButton(key:const ValueKey('what-if-submit'),onPressed:locked || selected.length!=t.answers.length?null:() async {
        await c.submit(s);if(c.phase(s)=='result')unawaited(c.sync());
      },child:const Text('Kontrol et ve sonu aç')),
      const SizedBox(height:12),
      if(!c.freeHintShown(s))TextButton.icon(key:const ValueKey('what-if-free-hint'),onPressed:locked?null:()=>c.freeHint(s),icon:const Icon(Icons.lightbulb_outline),label:const Text('İlk ipucu ücretsiz'))
      else _Notice(t.hint),
      if(c.hintUnlocked(s))_Notice(t.strongHint)
      else if(c.freeHintShown(s))...[
        const Text('Daha güçlü destek isteğe bağlı. Ücretsiz oynayabilir ve tekrar deneyebilirsin.'),
        Wrap(spacing:8,runSpacing:8,children:[
          OutlinedButton.icon(onPressed:c.syncing||locked||!c.linked?null:()=>c.action('what_if_hint',input,ad:true),
            icon:Icon(c.pro?Icons.workspace_premium:Icons.ondemand_video),label:Text(c.pro?'Pro desteği':'Reklamla destek')),
          OutlinedButton(onPressed:c.syncing||locked||!c.linked?null:()=>c.action('hint',input),child:const Text('10 Coin ile destek')),
        ]),
      ],
      TextButton(onPressed:locked?null:()=>c.setPhase(s,'choice'),child:const Text('Karar ekranına dön')),
    ];
  }
  Widget _reward(){
    final paid=rewardMap(c.rewards['scenario__${s.id}'])['settled']==true;
    return PitchPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text(paid?'10 Coin + 25 XP hesabına işlendi':c.linked?'İlk bitiriş ödülü eşitleniyor':'Bu keşif cihazına kaydedildi',style:Theme.of(context).textTheme.titleMedium),
      const SizedBox(height:8),Text(c.linked?'Bu hikâyenin ödülü yalnız bir kez verilir. İkinci son koleksiyonunu tamamlar.':'Coin, XP ve bulut vitrini için Google hesabına bağlanıp rotayı oyna. Misafir oyunu ücretsizdir.'),
      if(c.linked)TextButton(onPressed:c.syncing?null:c.sync,child:Text(c.syncing?'Eşitleniyor…':'Ödülleri yeniden eşitle')),
    ]));
  }
}
class _Tag extends StatelessWidget {
  const _Tag(this.text,this.icon);
  final String text;final IconData icon;
  @override
  Widget build(BuildContext context)=>Container(padding:const EdgeInsets.symmetric(horizontal:10,vertical:7),
    decoration:BoxDecoration(color:PitchColors.of(context).tint,borderRadius:BorderRadius.circular(10)),
    child:Wrap(crossAxisAlignment:WrapCrossAlignment.center,spacing:6,children:[Icon(icon,size:16),Text(text,style:Theme.of(context).textTheme.labelMedium)]));
}
class _Notice extends StatelessWidget {
  const _Notice(this.text);final String text;
  @override
  Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(text,style:Theme.of(context).textTheme.bodyMedium));
}
class _WhatIfHero extends StatelessWidget {
  const _WhatIfHero({required this.eyebrow,required this.title,required this.subtitle,this.progress});
  final String eyebrow,title,subtitle;final double? progress;
  @override
  Widget build(BuildContext context)=>Container(padding:const EdgeInsets.all(22),decoration:BoxDecoration(
    gradient:const LinearGradient(colors:[Color(0xFF182E49),Color(0xFF153F40)],begin:Alignment.topLeft,end:Alignment.bottomRight),
    border:Border.all(color:const Color(0xFF467274)),borderRadius:BorderRadius.circular(24)),
    child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Icon(Icons.alt_route_rounded,size:38,color:Color(0xFF6EE7D0)),const SizedBox(height:16),
      Text(eyebrow,style:Theme.of(context).textTheme.labelMedium?.copyWith(color:const Color(0xFF6EE7D0))),
      const SizedBox(height:12),Text(title,style:Theme.of(context).textTheme.headlineSmall?.copyWith(color:Colors.white,fontWeight:FontWeight.w800)),
      const SizedBox(height:12),Text(subtitle,style:const TextStyle(color:Color(0xFFD3E5E5))),
      if(progress!=null)...[const SizedBox(height:20),LinearProgressIndicator(value:progress,color:const Color(0xFF6EE7D0),backgroundColor:Colors.white12)],
    ]));
}
