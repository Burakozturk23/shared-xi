import 'package:flutter/material.dart';
import '../app/route_appearance.dart';
import '../services/search_service.dart';
import '../theme/ortak_saha_theme.dart';
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
  String? _group;
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colors = PitchColors.of(context);
    final modes = OnlinePlayMode.values.where((mode) =>
      (_group == null || mode.group == _group) &&
      SearchService.contains('${mode.title} ${mode.subtitle} ${mode.group}', _search.text.trim())).toList();
    return Scaffold(
      appBar: AppBar(title: Text(widget.ranked ? 'Rastgele eşleş' : 'Arkadaşlarınla oyna', maxLines: 2),
        toolbarHeight: MediaQuery.textScalerOf(context).scale(16) > 24 ? 96 : 64),
      body: GameContent(child: ListView(padding: const EdgeInsets.fromLTRB(24, 8, 24, 32), children: [
        if (_search.text.trim().isEmpty) PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: colors.tint, borderRadius: BorderRadius.circular(12)),
              child: Icon(widget.ranked ? Icons.public_rounded : Icons.groups_rounded, color: colors.accent)),
            const SizedBox(width: 12),
            Expanded(child: Text(widget.ranked ? 'DERECELİ OYUN' : 'ÖZEL ODA',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.accent))),
            Icon(Icons.sports_soccer_rounded, color: colors.muted),
          ]),
          const SizedBox(height: 16),
          Text(widget.ranked ? 'Bilgini sahaya çıkar.' : 'Rekabet arkadaşlarla güzel.',
            style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(widget.ranked ? 'Oyununu seç, eşleşmeye geç.' : 'Oyununu seç; oda kur veya kodla katıl.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.muted)),
        ])),
        const SizedBox(height: 24),
        TextField(key: const ValueKey('mode-search'), controller: _search, onChanged: (_) => setState(() {}),
          decoration: InputDecoration(hintText: 'Oyun veya kategori ara', prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.text.isEmpty ? null : IconButton(tooltip: 'Aramayı temizle',
              onPressed: () => setState(_search.clear), icon: const Icon(Icons.close_rounded)))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 4, children: [
          ChoiceChip(label: const Text('Tümü'), selected: _group == null,
            onSelected: (_) => setState(() => _group = null)),
          for (final group in onlineModeGroups) ChoiceChip(label: Text(group), selected: _group == group,
            onSelected: (_) => setState(() => _group = group)),
        ]),
        const SizedBox(height: 16),
        Text('${modes.length} mod', style: Theme.of(context).textTheme.labelLarge?.copyWith(color: colors.muted)),
        if (modes.isEmpty) ...[
          const SizedBox(height: 16),
          PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Icon(Icons.search_off_rounded, color: colors.muted, size: 32),
            const SizedBox(height: 12),
            const Text('Bu aramada oyun bulunamadı.', textAlign: TextAlign.center),
            const SizedBox(height: 12),
            TextButton(onPressed: () => setState(() { _search.clear(); _group = null; }),
              child: const Text('Filtreleri temizle')),
          ])),
        ],
        for (final group in onlineModeGroups)
          if (modes.any((m) => m.group == group)) ...[
            PitchSectionTitle(group),
            for (final mode in modes.where((m) => m.group == group))
              Padding(padding: const EdgeInsets.only(bottom: 12), child: PitchRow(
                title: mode.title, subtitle: mode.subtitle, icon: mode.icon, highlight: true,
                onTap: () => Navigator.of(context).push(LinkballRoute(modern: true,
                  builder: (_) => onlineModePage(mode, playKind: widget.ranked ? 'ranked' : 'friend'))))),
          ],
      ])),
    );
  }

}
