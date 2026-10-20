import 'package:flutter/material.dart';
import '../app/route_appearance.dart';
import '../services/search_service.dart';
import '../widgets/game_ui.dart';
import '../widgets/pitch_ui.dart';
import 'online_mode_catalog.dart';
import 'online_mode_route.dart';

class OnlineModeSelectionPage extends StatefulWidget {
  const OnlineModeSelectionPage({super.key, required this.ranked});
  final bool ranked;
  @override
  State<OnlineModeSelectionPage> createState() => _OnlineModeSelectionPageState();
}

class _OnlineModeSelectionPageState extends State<OnlineModeSelectionPage> {
  final _search = TextEditingController();
  @override
  void dispose() { _search.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final modes = OnlinePlayMode.values.where((mode) =>
      SearchService.contains('${mode.title} ${mode.subtitle}', _search.text.trim())).toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.ranked ? 'Rastgele eşleş' : 'Arkadaşlarınla oyna'),
        toolbarHeight: MediaQuery.textScalerOf(context).scale(16) > 24 ? 96 : 64),
      body: GameContent(child: ListView(padding: const EdgeInsets.all(20), children: [
        GameIntro(icon: widget.ranked ? Icons.public_rounded : Icons.groups_rounded,
          title: widget.ranked ? 'Rakibin seni bekliyor' : 'Birlikte sahaya çıkın',
          message: widget.ranked ? 'Modunu seç ve dereceli bir rakiple eşleş.' : 'Modunu seç, oda oluştur veya arkadaşının koduyla katıl.'),
        const SizedBox(height: 20),
        TextField(controller: _search, onChanged: (_) => setState(() {}),
          decoration: InputDecoration(hintText: 'Mod ara', prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.text.isEmpty ? null : IconButton(tooltip: 'Aramayı temizle',
              onPressed: () => setState(_search.clear), icon: const Icon(Icons.close_rounded)))),
        const SizedBox(height: 20),
        Text('${modes.length} mod', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 12),
        if (modes.isEmpty) const PitchPanel(child: Text('Mod bulunamadı. Başka bir ad deneyebilirsin.')),
        for (final mode in modes) Padding(padding: const EdgeInsets.only(bottom: 12), child: PitchRow(
          title: mode.title, subtitle: mode.subtitle, icon: mode.icon, highlight: true,
          onTap: () => Navigator.of(context).push(LinkballRoute(modern: true,
            builder: (_) => onlineModePage(mode, playKind: widget.ranked ? 'ranked' : 'friend'))))),
      ])),
    );
  }
}
