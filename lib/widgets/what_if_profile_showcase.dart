import 'dart:async';
import 'package:flutter/material.dart';
import '../app/route_appearance.dart';
import '../controllers/what_if_controller.dart';
import '../models/what_if.dart';
import '../screens/what_if_selection_page.dart';
import 'pitch_ui.dart';

class WhatIfProfileShowcase extends StatefulWidget {
  const WhatIfProfileShowcase({super.key});
  @override
  State<WhatIfProfileShowcase> createState()=>_WhatIfProfileShowcaseState();
}
class _WhatIfProfileShowcaseState extends State<WhatIfProfileShowcase>{
  WhatIfController? c;
  @override
  void initState(){super.initState();_load();}
  Future<void> _load() async {
    try{
      final catalog=await WhatIfCatalog.load();if(!mounted)return;
      c=WhatIfController(catalog:catalog);c!.addListener(_changed);
      await c!.initialize();if(mounted)unawaited(c!.sync());
    }catch(_){/* Archive offers an explicit retry; profile stays navigable. */}
  }
  void _changed(){if(mounted)setState((){});}
  @override
  void dispose(){c?.removeListener(_changed);c?.dispose();super.dispose();}
  @override
  Widget build(BuildContext context){
    final favorites=c?.catalog.scenarios.where((s)=>c!.showcase.contains(s.id)).toList() ?? <WhatIfScenario>[];
    return Padding(padding:const EdgeInsets.only(top:12),child:PitchRow(
      title:'Kader vitrinim',icon:Icons.alt_route_rounded,highlight:true,
      subtitle:favorites.isEmpty?'What If kartlarını keşfet. Kader Arşivi’nden üç kart seç.':
        favorites.map((s)=>'${s.name}${c!.ends(s).length==2?' · Çift evren':''}').join('\n'),
      onTap:() async {
        await Navigator.of(context).push(LinkballRoute(builder:(_)=>const WhatIfPage(archive:true)));
        if(mounted && c!=null)await c!.sync();
      },
    ));
  }
}
