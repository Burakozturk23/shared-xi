import 'package:flutter/material.dart';
import '../controllers/journey_rewards_controller.dart';
import '../models/rewarded_ad_models.dart';
import '../theme/ortak_saha_theme.dart';
import 'pitch_ui.dart';

class JourneyRewardCard extends StatelessWidget {
  const JourneyRewardCard({super.key, required this.rewards, required this.journeyId, required this.chapter});
  final JourneyRewardsController rewards;
  final String journeyId;
  final int chapter;
  @override
  Widget build(BuildContext context) {
    final receipt = rewardMap(rewards.rewards['player__$journeyId']);
    final paid = receipt['settled'] == true;
    final chapterPaid = rewardMap(rewards.rewards['chapter__$chapter'])['settled'] == true;
    final doubled = rewards.rewards.containsKey('double__$chapter');
    return PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,children:[
      Text(paid ? 'Kariyer damgan hazır' : 'Kariyerini koleksiyonuna ekle',style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height:12),
      Wrap(spacing:8,runSpacing:8,children:[
        Chip(avatar:Icon(Icons.toll,color:PitchColors.of(context).limeInk),label:const Text('20 Coin')),
        const Chip(avatar:Icon(Icons.bolt),label:Text('40 XP')),
      ]),
      Text(paid ? 'Ödül hesabına işlendi. Tekrar oynamak ikinci ödül vermez.' :
        'İlk sunucu doğrulamasında bir kez kazanırsın. Eski cihaz kaydı varsa ödül için dört görevi yeniden tamamla.'),
      if (chapterPaid) ...[
        const Divider(height:28),
        Text('Bölüm $chapter tamamlandı',style:Theme.of(context).textTheme.titleMedium),
        Text(doubled ? '160 bölüm coini · 120 XP' : '80 bölüm coini · 120 XP'),
        const Text('XP değişmez. İsteğe bağlı bonus bölüm başına bir kez alınır.'),
        if (!doubled) OutlinedButton.icon(onPressed:rewards.busy ? null : ()=>rewards.action('story_double',{'chapter':chapter},ad:true),
          icon:Icon(rewards.pro ? Icons.workspace_premium : Icons.play_circle_outline),
          label:Text(rewards.pro ? 'Pro bonusunu al · +80 Coin' : 'Reklam izle · +80 Coin')),
      ],
      if (rewards.legend) ...[
        const Divider(height:28),
        const Text('Linkball Kariyer Efsanesi',style:TextStyle(fontWeight:FontWeight.w800)),
        const Text('32 kariyer tamamlandı. Final: 150 Coin + 300 XP, unvan ve vitrin çerçevesi.'),
      ],
      if (rewards.message != null) Padding(padding:const EdgeInsets.only(top:12),child:Text(rewards.message!)),
      TextButton.icon(onPressed:rewards.busy ? null : rewards.refresh,icon:const Icon(Icons.sync),
        label:Text(rewards.busy ? 'Ödüller eşitleniyor…' : 'Ödülleri kontrol et')),
    ]));
  }
}
