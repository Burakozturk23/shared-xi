import 'package:flutter/material.dart';
import '../app/route_appearance.dart';
import '../controllers/journey_rewards_controller.dart';
import '../models/journey_task.dart';
import '../screens/journey_passport_page.dart';
import '../theme/ortak_saha_theme.dart';
import 'player_avatar.dart';

class JourneyProfileShowcase extends StatefulWidget {
  const JourneyProfileShowcase({super.key});
  @override
  State<JourneyProfileShowcase> createState()=>_JourneyProfileShowcaseState();
}
class _JourneyProfileShowcaseState extends State<JourneyProfileShowcase> {
  final _rewards=JourneyRewardsController();
  List<JourneyV2Definition> _journeys=[];
  @override
  void initState() { super.initState(); _rewards.addListener(_changed); _load(); }
  void _changed() { if(mounted) setState(() {}); }
  Future<void> _load() async {
    try { final journeys=await loadPassportJourneys(); if(mounted) setState(()=>_journeys=journeys); } catch (_) {}
    await _rewards.refresh();
  }
  @override
  void dispose() { _rewards.removeListener(_changed); _rewards.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final p=PitchColors.of(context);
    final favorites=_journeys.where((j)=>_rewards.favorites.contains(j.id)).toList();
    return Material(color:p.surface,shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(20),
      side:BorderSide(color:_rewards.legend ? const Color(0xFFE5BC65) : p.border,width:_rewards.legend ? 2 : 1)),
      clipBehavior:Clip.antiAlias,child:InkWell(onTap:() async {
        await Navigator.of(context).push(LinkballRoute(builder:(_)=>const JourneyPassportPage()));
        if(mounted) await _rewards.refresh();
      },child:Padding(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        Row(children:[Icon(_rewards.legend ? Icons.workspace_premium : Icons.auto_stories_outlined,color:_rewards.legend ? const Color(0xFFE5BC65) : p.accent),
          const SizedBox(width:10),Expanded(child:Text(_rewards.legend ? 'Linkball Kariyer Efsanesi' : 'Kariyer vitrinim',style:Theme.of(context).textTheme.titleMedium)),
          const Icon(Icons.chevron_right),
        ]),
        const SizedBox(height:12),
        if(favorites.isEmpty) const Text('Kariyer pasaportundan üç favori damganı seç.')
        else Wrap(spacing:14,runSpacing:12,children:[for(final j in favorites) SizedBox(width:80,child:Column(children:[
          PlayerAvatar(player:passportPlayer(j),size:64),const SizedBox(height:6),Text(j.name,textAlign:TextAlign.center,style:Theme.of(context).textTheme.bodySmall),
        ]))]),
        const SizedBox(height:8),Text('${_rewards.completed.length} / 32 damga · Pasaportu aç'),
      ]))));
  }
}
