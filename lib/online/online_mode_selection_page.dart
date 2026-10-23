import 'package:flutter/material.dart';
import '../app/route_appearance.dart';
import '../services/search_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/game_ui.dart';
import '../widgets/online_ui.dart';
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
  late bool _ranked = widget.ranked;
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final colors = PitchColors.of(context);
    final modes = OnlinePlayMode.values.where((mode) =>
      (_group == null || mode.group == _group) &&
      SearchService.contains('${mode.title} ${mode.subtitle} ${mode.group}', _search.text.trim())).toList();
    return Scaffold(
      appBar: AppBar(title: Text(_ranked ? 'Rastgele eşleş' : 'Arkadaşlarınla oyna', maxLines: 2),
        toolbarHeight: MediaQuery.textScalerOf(context).scale(16) > 24 ? 96 : 64),
      body: GameContent(child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 32), children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final ranked in [true, false]) ChoiceChip(
            avatar: Icon(ranked ? Icons.public_rounded : Icons.groups_rounded, size: 18, color: colors.accent),
            label: Text(ranked ? 'Online' : 'Arkadaşlarla'), selected: _ranked == ranked,
            selectedColor: colors.tint, checkmarkColor: colors.accent,
            onSelected: (_) => setState(() => _ranked = ranked)),
        ]),
        const SizedBox(height: 16),
        if (_search.text.trim().isEmpty) PitchPanel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: colors.tint, borderRadius: BorderRadius.circular(12)),
              child: Icon(_ranked ? Icons.public_rounded : Icons.groups_rounded, color: colors.accent)),
            const SizedBox(width: 12),
            Expanded(child: Text(_ranked ? 'DERECELİ OYUN' : 'ÖZEL ODA',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: colors.accent))),
            Icon(Icons.sports_soccer_rounded, color: colors.muted),
          ]),
          const SizedBox(height: 16),
          Text(_ranked ? 'Bilgini sahaya çıkar.' : 'Rekabet arkadaşlarla güzel.',
            style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Text(_ranked ? 'Aynı sorular, aynı süre. Modunu seç ve rakibini bul.' : 'Aynı modu seçin; oda kur veya arkadaşının koduyla katıl. Dostluk maçları sıralamanı etkilemez.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: colors.muted)),
        ])),
        const SizedBox(height: 24),
        TextField(key: const ValueKey('mode-search'), controller: _search, onChanged: (_) => setState(() {}),
          decoration: InputDecoration(hintText: 'Oyun veya kategori ara', prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _search.text.isEmpty ? null : IconButton(tooltip: 'Aramayı temizle',
              onPressed: () => setState(_search.clear), icon: const Icon(Icons.close_rounded)))),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 4, children: [
          ChoiceChip(selectedColor: colors.tint, checkmarkColor: colors.accent, label: const Text('Tümü'), selected: _group == null,
            onSelected: (_) => setState(() => _group = null)),
          for (final group in onlineModeGroups) ChoiceChip(selectedColor: colors.tint, checkmarkColor: colors.accent, label: Text(group), selected: _group == group,
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
              Padding(padding: const EdgeInsets.only(bottom: 12), child: OnlineModeTile(
                key: ValueKey('online-mode-${mode.wireName}'), mode: mode, ranked: _ranked,
                onTap: () => Navigator.of(context).push(LinkballRoute(modern: true,
                  builder: (_) => onlineModePage(mode, playKind: _ranked ? 'ranked' : 'friend'))))),
          ],
      ])),
    );
  }

}
