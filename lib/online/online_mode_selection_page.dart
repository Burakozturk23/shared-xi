import 'package:flutter/material.dart';
import '../app/route_appearance.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../services/search_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/game_ui.dart';
import '../widgets/hub_ui.dart';
import '../widgets/online_ui.dart';
import '../widgets/pitch_ui.dart';
import 'online_mode_catalog.dart';
import 'online_mode_route.dart';

class OnlineModeSelectionPage extends StatefulWidget {
  const OnlineModeSelectionPage({super.key, required this.ranked, this.me});
  final bool ranked;

  /// Own profile for the ELO badge; defaults to the live feed for linked
  /// accounts.
  final Stream<UserProfile?>? me;
  @override
  State<OnlineModeSelectionPage> createState() =>
      _OnlineModeSelectionPageState();
}

class _OnlineModeSelectionPageState extends State<OnlineModeSelectionPage> {
  final _search = TextEditingController();
  String? _group;
  late bool _ranked = widget.ranked;
  late final Stream<UserProfile?>? _me =
      widget.me ??
      (AuthService.hasPersistentAccount
          ? ProfileService.watchMyProfile()
          : null);
  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _open(OnlinePlayMode mode) => Navigator.of(context).push(
    LinkballRoute(
      modern: true,
      builder: (_) =>
          onlineModePage(mode, playKind: _ranked ? 'ranked' : 'friend'),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final colors = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final largeText = MediaQuery.textScalerOf(context).scale(16) > 24;
    final modes = OnlinePlayMode.values
        .where(
          (mode) =>
              (_group == null || mode.group == _group) &&
              SearchService.contains(
                '${mode.title} ${mode.subtitle} ${mode.group}',
                _search.text.trim(),
              ),
        )
        .toList();
    int count(String group) =>
        OnlinePlayMode.values.where((m) => m.group == group).length;
    final groupColors = [colors.accent, colors.limeInk, hubAmber(context)];
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _ranked ? 'Rastgele eşleş' : 'Arkadaşlarınla oyna',
          maxLines: 2,
        ),
        toolbarHeight: MediaQuery.textScalerOf(context).scale(16) > 24
            ? 96
            : 64,
      ),
      body: GameContent(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final ranked in [true, false])
                  ChoiceChip(
                    avatar: Icon(
                      ranked ? Icons.public_rounded : Icons.groups_rounded,
                      size: 18,
                      color: colors.accent,
                    ),
                    label: Text(ranked ? 'Online' : 'Arkadaşlarla'),
                    selected: _ranked == ranked,
                    selectedColor: colors.tint,
                    checkmarkColor: colors.accent,
                    onSelected: (_) => setState(() => _ranked = ranked),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_search.text.trim().isEmpty && !largeText)
              HubHeroCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        HubPill(
                          _ranked
                              ? 'DERECELİ 1V1 ARENA'
                              : 'ÖZEL ODA · DOSTLUK MAÇI',
                          color: colors.accent,
                          background: colors.background.withValues(alpha: .4),
                          dot: true,
                        ),
                        Text(
                          '${OnlinePlayMode.values.length} MOD',
                          style: hubCaps(context),
                        ),
                        if (_ranked)
                          StreamBuilder<UserProfile?>(
                            stream: _me,
                            builder: (context, snapshot) =>
                                switch (snapshot.data) {
                                  final me? => HubPill(
                                    '${groupedNumber(me.elo)} ELO',
                                    color: colors.limeInk,
                                    background: colors.limeTint,
                                  ),
                                  null => const SizedBox.shrink(),
                                },
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      _ranked
                          ? 'Bilgini sahaya çıkar.'
                          : 'Rekabet arkadaşlarla güzel.',
                      style: text.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _ranked
                          ? 'Aynı sorular, aynı süre. Modunu seç ve rakibini bul.'
                          : 'Aynı modu seçin; oda kur veya arkadaşının koduyla katıl. Dostluk maçları sıralamanı etkilemez.',
                      style: text.bodyMedium?.copyWith(color: colors.muted),
                    ),
                    const SizedBox(height: 16),
                    PitchAction(
                      label: _ranked
                          ? '${OnlinePlayMode.sharedXi.title} ile hızlı eşleş'
                          : '${OnlinePlayMode.sharedXi.title} ile oda kur',
                      onPressed: () => _open(OnlinePlayMode.sharedXi),
                    ),
                  ],
                ),
              ),
            if (_search.text.trim().isEmpty && largeText)
              Text(
                _ranked
                    ? 'Modunu seç, rakibini bul.'
                    : 'Modunu seç; oda kur veya kodla katıl.',
              ),
            const SizedBox(height: 20),
            TextField(
              key: const ValueKey('mode-search'),
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Oyun veya kategori ara',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Aramayı temizle',
                        onPressed: () => setState(_search.clear),
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ChoiceChip(
                  selectedColor: colors.tint,
                  checkmarkColor: colors.accent,
                  label: _ChipLabel('Tümü', OnlinePlayMode.values.length),
                  selected: _group == null,
                  onSelected: (_) => setState(() => _group = null),
                ),
                for (final group in onlineModeGroups)
                  ChoiceChip(
                    selectedColor: colors.tint,
                    checkmarkColor: colors.accent,
                    label: _ChipLabel(group, count(group)),
                    selected: _group == group,
                    onSelected: (_) => setState(() => _group = group),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${modes.length} mod',
              style: text.labelLarge?.copyWith(color: colors.muted),
            ),
            if (modes.isEmpty) ...[
              const SizedBox(height: 16),
              PitchPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Icon(
                      Icons.search_off_rounded,
                      color: colors.muted,
                      size: 32,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Bu aramada oyun bulunamadı.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => setState(() {
                        _search.clear();
                        _group = null;
                      }),
                      child: const Text('Filtreleri temizle'),
                    ),
                  ],
                ),
              ),
            ],
            for (final (i, group) in onlineModeGroups.indexed)
              if (modes.any((m) => m.group == group)) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 24, bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 4,
                        height: 20,
                        decoration: BoxDecoration(
                          color: groupColors[i % groupColors.length],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(group, style: text.titleLarge)),
                      Text('${count(group)} MOD', style: hubCaps(context)),
                    ],
                  ),
                ),
                for (final mode in modes.where((m) => m.group == group))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: OnlineModeTile(
                      key: ValueKey('online-mode-${mode.wireName}'),
                      mode: mode,
                      ranked: _ranked,
                      onTap: () => _open(mode),
                    ),
                  ),
              ],
          ],
        ),
      ),
    );
  }
}

/// Group name and its mode count; the name stays its own text.
class _ChipLabel extends StatelessWidget {
  const _ChipLabel(this.label, this.count);
  final String label;
  final int count;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label),
      const SizedBox(width: 4),
      Text('($count)', style: TextStyle(color: PitchColors.of(context).muted)),
    ],
  );
}
