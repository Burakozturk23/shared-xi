import 'package:flutter/material.dart';
import '../controllers/journey_rewards_controller.dart';
import '../models/achievement_catalog.dart';
import '../models/journey_task.dart';
import '../models/player.dart';
import '../models/rewarded_ad_models.dart';
import '../services/journey_v2_store.dart';
import '../services/player_journey_progress_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/achievement_badge_emblem.dart';
import '../widgets/pitch_ui.dart';
import '../widgets/player_avatar.dart';

/// One catalog drives the game, passport portraits and the profile showcase.
Future<List<JourneyV2Definition>> loadPassportJourneys() async => [
  for (final chapter in journeyV2Chapters.keys) ...await loadJourneyChapter(chapter),
];
Player passportPlayer(JourneyV2Definition journey) => Player.fromJson({
  'id':journey.playerId, 'name':journey.name, 'position':'', 'countries':<String>[],
});

class JourneyPassportPage extends StatefulWidget {
  const JourneyPassportPage({super.key, this.controller, this.journeys});
  final JourneyRewardsController? controller;
  final List<JourneyV2Definition>? journeys;
  @override
  State<JourneyPassportPage> createState()=>_JourneyPassportPageState();
}
class _JourneyPassportPageState extends State<JourneyPassportPage> {
  late final JourneyRewardsController _rewards;
  List<JourneyV2Definition> _journeys=[];
  Set<String> _local={};
  bool _loading=true, _failed=false;
  int _chapter=1;
  @override
  void initState() {
    super.initState();
    _rewards=widget.controller ?? JourneyRewardsController();
    _rewards.addListener(_changed);
    _load();
  }
  void _changed() { if(mounted) setState(() {}); }
  Future<void> _load() async {
    setState(() { _loading=true; _failed=false; });
    try {
      final journeys=widget.journeys ?? await loadPassportJourneys();
      final local=await PlayerJourneyProgressService.getCompletedIds();
      if(!mounted) return;
      setState(() { _journeys=journeys; _local=local; _loading=false; });
      await _rewards.refresh();
    } catch (_) { if(mounted) setState(() { _loading=false; _failed=true; }); }
  }
  @override
  void dispose() {
    _rewards.removeListener(_changed);
    if(widget.controller==null) _rewards.dispose();
    super.dispose();
  }
  Future<void> _favorite(String id) async {
    final next=[..._rewards.favorites];
    if(next.contains(id)) { next.remove(id); }
    else if(next.length<3) { next.add(id); }
    else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Vitrininde üç yer var. Önce bir damgayı kaldır.')));
      return;
    }
    await _rewards.action('favorites',{'ids':next});
  }
  @override
  Widget build(BuildContext context) {
    final p=PitchColors.of(context);
    final complete=_rewards.completed;
    final count=complete.length;
    final chapterIds=journeyV2Chapters.values.firstWhere((c)=>c.number==_chapter).ids;
    final collected=chapterIds.where(complete.contains).length;
    final paid=rewardMap(_rewards.rewards['chapter__$_chapter'])['settled']==true;
    final doubled=rewardMap(_rewards.rewards['double__$_chapter'])['settled']==true;
    final badge=AchievementCatalog.byId['journey_chapter_$_chapter']!;
    return Scaffold(appBar:AppBar(title:const Text('Kariyer Pasaportu'),actions:[
      IconButton(tooltip:'Yenile',onPressed:_rewards.busy ? null : _load,icon:const Icon(Icons.sync)),
    ]),body:SafeArea(child:_loading ? const Center(child:CircularProgressIndicator()) : _failed
      ? Center(child:FilledButton(onPressed:_load,child:const Text('Pasaportu tekrar yükle')))
      : ListView(padding:const EdgeInsets.fromLTRB(20,12,20,28),children:[
        Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(
          borderRadius:BorderRadius.circular(24),
          gradient:LinearGradient(colors:[p.tint,p.surface]),
          border:Border.all(color:_rewards.legend ? const Color(0xFFE5BC65) : p.accent.withValues(alpha:.45)),
        ),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('LINKBALL • KARİYER ARŞİVİ',style:TextStyle(fontSize:11,letterSpacing:1.8,fontWeight:FontWeight.w800)),
          const SizedBox(height:16),
          Text(_rewards.legend ? 'Linkball Kariyer Efsanesi' : 'Her kariyer bir iz bırakır.',style:Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height:12),
          Text('$count / 32 kariyer damgası',style:Theme.of(context).textTheme.titleMedium),
          const SizedBox(height:10),
          LinearProgressIndicator(value:count/32,borderRadius:BorderRadius.circular(8),minHeight:6),
          const SizedBox(height:12),
          const Text('Dört görevi çöz, oyuncunun damgasını kazan. Üç favorini profil vitrinine taşı.'),
          const SizedBox(height:12),
          const Text('Her kariyer 20 Coin + 40 XP\nHer bölüm 80 Coin + 120 XP',style:TextStyle(fontWeight:FontWeight.w600)),
        ])),
        if(_rewards.busy) const Padding(padding:EdgeInsets.symmetric(vertical:12),child:LinearProgressIndicator()),
        if(_rewards.message!=null) Padding(padding:const EdgeInsets.symmetric(vertical:12),child:Text(_rewards.message!)),
        const PitchSectionTitle('Koleksiyon sayfaları'),
        Wrap(spacing:8,runSpacing:8,children:[for(var n=1;n<=4;n++) ChoiceChip(
          label:Text('Bölüm $n'),selected:_chapter==n,onSelected:(_)=>setState(()=>_chapter=n),
        )]),
        const SizedBox(height:16),
        PitchPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Row(children:[AchievementBadgeEmblem(definition:badge,unlocked:collected==8,size:64),
            const SizedBox(width:12),Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(badge.title,style:Theme.of(context).textTheme.titleMedium),
              Text('$collected / 8 damga · Bölüm rozeti'),
            ])),
          ]),
          const SizedBox(height:12),
          Text(paid ? 'Bölüm ödülü alındı · 80 Coin + 120 XP' : 'Sekiz damgada bölüm ödülü açılır.'),
          if(paid) ...[
            const SizedBox(height:8),
            if(doubled) const Text('Bonus alındı · +80 Coin',style:TextStyle(fontWeight:FontWeight.w700))
            else OutlinedButton.icon(onPressed:_rewards.busy ? null : ()=>_rewards.action('story_double',{'chapter':_chapter},ad:true),
              icon:Icon(_rewards.pro ? Icons.workspace_premium : Icons.play_circle_outline),
              label:Text(_rewards.pro ? 'Pro bonusu · +80 Coin' : 'Reklamla 2× bölüm coini')),
            const Text('İsteğe bağlıdır. XP aynı kalır; bonus bölüm başına bir kez alınır.'),
          ],
        ])),
        const SizedBox(height:16),
        for(final journey in _journeys.where((j)=>chapterIds.contains(j.id))) Padding(
          padding:const EdgeInsets.only(bottom:10),child:PitchPanel(child:Row(children:[
            Opacity(opacity:complete.contains(journey.id) ? 1 : .4,child:PlayerAvatar(player:passportPlayer(journey),size:64)),
            const SizedBox(width:14),
            Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(journey.name,style:Theme.of(context).textTheme.titleSmall),
              const SizedBox(height:4),
              Text(complete.contains(journey.id) ? 'Kariyer damgası kazanıldı' : _local.contains(journey.id)
                ? 'Cihazda tamamlandı · Ödül için yeniden oyna' : 'Dört görevi tamamlayarak aç'),
            ])),
            IconButton(tooltip:_rewards.favorites.contains(journey.id) ? 'Vitrinden kaldır' : 'Vitrine ekle',
              onPressed:complete.contains(journey.id) && !_rewards.busy ? ()=>_favorite(journey.id) : null,
              icon:Icon(_rewards.favorites.contains(journey.id) ? Icons.star_rounded : complete.contains(journey.id) ? Icons.star_outline_rounded : Icons.lock_outline,
                color:_rewards.favorites.contains(journey.id) ? const Color(0xFFE5BC65) : null)),
          ]))),
        const PitchSectionTitle('Kariyerinin imzası'),
        PitchPanel(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Center(child:AchievementBadgeEmblem(definition:AchievementCatalog.byId['journey_legend']!,unlocked:_rewards.legend,size:88)),
          const SizedBox(height:12),
          Text('Linkball Kariyer Efsanesi',textAlign:TextAlign.center,style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:8),
          Text(_rewards.legend ? 'Unvanın ve altın vitrin çerçeven açıldı.' : '32 damgada kalıcı unvan ve altın vitrin çerçevesi.',textAlign:TextAlign.center),
          const SizedBox(height:8),
          const Text('Final ödülü · 150 Coin + 300 XP',textAlign:TextAlign.center),
        ])),
      ])));
  }
}
