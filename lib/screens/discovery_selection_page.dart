import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/popular_clubs.dart';
import '../data/popular_matchups.dart';
import '../models/club.dart';
import '../models/match_entity.dart';
import '../services/runtime_v4/game_data_v4_query_service.dart';
import '../services/search_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/club_badge.dart';
import '../widgets/club_identity_badge.dart';
import '../widgets/country_badge.dart';
import '../widgets/empty_state.dart';
import '../widgets/hub_ui.dart';
import '../widgets/pitch_ui.dart';
import 'shared_players_result_page.dart';

typedef DiscoveryCatalogLoader = Future<(List<Club>, List<String>)> Function();

/// Both discovery paths share the same selection flow and the existing V4 data.
class DiscoverySelectionPage extends StatefulWidget {
  const DiscoverySelectionPage({
    super.key,
    this.countryMode = false,
    this.prefillClub,
    this.catalogLoader,
  });
  final bool countryMode;
  final Club? prefillClub;
  final DiscoveryCatalogLoader? catalogLoader;

  @override
  State<DiscoverySelectionPage> createState() => _DiscoverySelectionPageState();
}

class _DiscoverySelectionPageState extends State<DiscoverySelectionPage> {
  late bool _countryMode;
  Club? _first, _second;
  String? _country;
  List<Club> _clubs = [];
  List<String> _countries = [];
  bool _loading = true, _failed = false;

  /// Popular pairs start with four; the header opens the full list.
  bool _allPopular = false;

  @override
  void initState() {
    super.initState();
    _countryMode = widget.countryMode;
    _first = widget.prefillClub;
    _load();
  }

  Future<(List<Club>, List<String>)> _defaultCatalog() async {
    final service = GameDataV4QueryService.instance;
    final clubs = await service.sharedXiClubCatalog(
      includeIds: {
        ...popularClubIds,
        for (final pair in popularClubClubMatchups) ...[
          pair.clubId1,
          pair.clubId2,
        ],
        for (final pair in popularClubCountryMatchups) pair.clubId,
        if (widget.prefillClub != null) widget.prefillClub!.id,
      },
    );
    return (clubs, await service.countries());
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final catalog = await (widget.catalogLoader ?? _defaultCatalog)();
      final sorted = List<Club>.of(catalog.$1)
        ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _clubs = sorted;
        _countries = catalog.$2;
        _loading = false;
      });
    } catch (error, stack) {
      debugPrint('Discovery catalog: $error\n$stack');
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  MatchEntity? get _right => _countryMode
      ? (_country == null ? null : MatchEntity.country(_country!))
      : (_second == null ? null : MatchEntity.club(_second!));

  Future<void> _pick(int slot) async {
    final isCountry = slot == 1 && _countryMode;
    final excluded = slot == 0 ? _second?.id : _first?.id;
    final value = await showModalBottomSheet<Object>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _EntityPicker(
        countryMode: isCountry,
        countries: _countries,
        clubs: _clubs.where((c) => _countryMode || c.id != excluded).toList(),
      ),
    );
    if (!mounted || value == null) return;
    setState(() {
      if (value is String) {
        _country = value;
      } else if (value is Club) {
        if (slot == 0) {
          _first = value;
        } else {
          _second = value;
        }
        // A first-club change in country mode must not leave a duplicate pair.
        if (_second?.id == _first?.id) _second = null;
      }
    });
  }

  void _open(MatchEntity left, MatchEntity right) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SharedPlayersResultPage(entity1: left, entity2: right),
      ),
    );
  }

  void _swap() => setState(() {
    final first = _first;
    _first = _second;
    _second = first;
  });

  void _reset() => setState(() {
    _first = null;
    _second = null;
    _country = null;
  });

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final byId = {for (final c in _clubs) c.id: c};
    final popular = <(String, MatchEntity, MatchEntity)>[
      if (!_countryMode)
        for (final pair in popularClubClubMatchups)
          if (byId[pair.clubId1] != null && byId[pair.clubId2] != null)
            (
              pair.label,
              MatchEntity.club(byId[pair.clubId1]!),
              MatchEntity.club(byId[pair.clubId2]!),
            ),
      if (_countryMode)
        for (final pair in popularClubCountryMatchups)
          if (byId[pair.clubId] != null && _countries.contains(pair.country))
            (
              pair.label,
              MatchEntity.club(byId[pair.clubId]!),
              MatchEntity.country(pair.country),
            ),
    ];
    final ready = (_first == null ? 0 : 1) + (_right == null ? 0 : 1);
    final scaler = MediaQuery.textScalerOf(context);
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: math.max(
          64,
          scaler.scale(20) * 1.25 + scaler.scale(13) * 1.4 + 20,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Ortak Oyuncu Keşfi'),
            Text(
              'Kulüp & ülke bağları',
              style: text.bodySmall?.copyWith(color: p.muted),
            ),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: p.border),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _failed
          ? EmptyState(
              icon: Icons.cloud_off_outlined,
              title: 'Kulüpler yüklenemedi',
              message: 'Bir kez daha deneyebilirsin.',
              actionLabel: 'Tekrar dene',
              onAction: _load,
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              children: [
                HubHeroCard(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const HubIconBox(Icons.hub_outlined),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                HubPill(
                                  'EŞLEŞTİRİCİ',
                                  color: p.accent,
                                  background: p.background.withValues(
                                    alpha: .4,
                                  ),
                                ),
                                Text(
                                  'Durum: $ready/2 hazır',
                                  style: text.labelMedium,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _countryMode
                                  ? 'Bir kulüp ve ülke seç; o kulüpte oynamış, o ülkeden futbolcuları keşfet.'
                                  : 'İki kulüp seç; iki kulüpte de forma giymiş futbolcuları keşfet.',
                              style: text.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _ModeTab(
                          label: 'Kulüp – Kulüp',
                          icon: Icons.shield_outlined,
                          selected: !_countryMode,
                          onTap: () => setState(() => _countryMode = false),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: _ModeTab(
                          label: 'Kulüp – Ülke',
                          icon: Icons.flag_outlined,
                          selected: _countryMode,
                          onTap: () => setState(() => _countryMode = true),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _SelectionSlot(
                  label: '1. KULÜP',
                  prompt: 'İlk kulübü seç',
                  entity: _first == null ? null : MatchEntity.club(_first!),
                  club: _first,
                  onTap: () => _pick(0),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Expanded(child: Divider(color: p.border)),
                      const SizedBox(width: 12),
                      IconButton.outlined(
                        tooltip: 'Kulüpleri yer değiştir',
                        style: IconButton.styleFrom(
                          foregroundColor: p.accent,
                          side: BorderSide(
                            color: p.accent.withValues(alpha: .5),
                          ),
                        ),
                        onPressed:
                            !_countryMode && (_first != null || _second != null)
                            ? _swap
                            : null,
                        icon: const Icon(Icons.swap_vert_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Divider(color: p.border)),
                    ],
                  ),
                ),
                _SelectionSlot(
                  label: _countryMode ? '2. ÜLKE' : '2. KULÜP',
                  prompt: _countryMode ? 'Ülkeyi seç' : 'İkinci kulübü seç',
                  entity: _right,
                  club: _countryMode ? null : _second,
                  onTap: () => _pick(1),
                ),
                const SizedBox(height: 16),
                PitchPanel(
                  child: Row(
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: p.limeInk,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _countryMode
                              ? 'Ülke, futbolcunun uyruğunu belirtir.'
                              : 'Aynı kulübü iki kez seçemezsin.',
                          style: text.bodySmall,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          '${groupedNumber(_clubs.length)} kulüp · '
                          '${groupedNumber(_countries.length)} ülke',
                          textAlign: TextAlign.end,
                          style: text.labelMedium?.copyWith(color: p.accent),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _SearchLauncher(
                  label: _countryMode && _first != null
                      ? 'Ülke adı ara'
                      : 'Kulüp adı ara',
                  onTap: () => _pick(_first == null ? 0 : 1),
                ),
                if (popular.isNotEmpty) ...[
                  HubSectionHeader(
                    'Popüler Bağlantılar',
                    icon: Icons.local_fire_department_outlined,
                    iconColor: p.limeInk,
                    trailing: popular.length > 4 && !_allPopular
                        ? TextButton(
                            onPressed: () => setState(() => _allPopular = true),
                            child: Text('Tümü (${popular.length})'),
                          )
                        : HubNote(
                            _countryMode ? 'Kulüp × Ülke' : 'Kulüp × Kulüp',
                          ),
                  ),
                  for (final pair
                      in _allPopular ? popular : popular.take(4)) ...[
                    _PopularPairRow(
                      label: pair.$1,
                      left: pair.$2,
                      right: pair.$3,
                      onTap: () => _open(pair.$2, pair.$3),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
      bottomNavigationBar: _loading || _failed
          ? null
          : DecoratedBox(
              decoration: BoxDecoration(
                color: p.background,
                border: Border(top: BorderSide(color: p.border)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PitchAction(
                        label: 'Ortak oyuncuları keşfet',
                        icon: Icons.explore_outlined,
                        onPressed: _first != null && _right != null
                            ? () => _open(MatchEntity.club(_first!), _right!)
                            : null,
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: ready > 0 ? _reset : null,
                          style: TextButton.styleFrom(foregroundColor: p.muted),
                          child: const Text('Seçimleri sıfırla'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

/// Search-field look-alike that opens the picker for the next empty slot.
class _SearchLauncher extends StatelessWidget {
  const _SearchLauncher({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Semantics(
      button: true,
      child: Material(
        color: p.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: p.border),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: p.muted),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: p.muted),
                    ),
                  ),
                  Icon(Icons.tune_rounded, color: p.muted, size: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ModeTab extends StatelessWidget {
  const _ModeTab({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final color = selected ? p.accent : p.muted;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? p.tint : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: selected
                ? p.accent.withValues(alpha: .5)
                : Colors.transparent,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      label,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 14,
                        color: selected ? p.text : p.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectionSlot extends StatelessWidget {
  const _SelectionSlot({
    required this.label,
    required this.prompt,
    required this.entity,
    required this.onTap,
    this.club,
  });
  final String label, prompt;
  final MatchEntity? entity;
  final Club? club;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    final text = Theme.of(context).textTheme;
    final picked = entity;
    final details = club == null
        ? (picked == null ? '' : 'Futbolcu uyruğu')
        : [club!.country, club!.league].where((s) => s.isNotEmpty).join(' • ');
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: picked == null
                    ? HubPill(
                        '$label BEKLENİYOR',
                        color: p.accent,
                        background: p.tint,
                        dot: true,
                      )
                    : HubPill(
                        '$label SEÇİLDİ',
                        color: p.success,
                        background: p.success.withValues(alpha: .12),
                        icon: Icons.check_circle_outline_rounded,
                      ),
              ),
            ),
            const SizedBox(width: 8),
            if (picked == null)
              HubPill('Seç', color: p.limeInk, background: p.limeTint)
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.swap_horiz_rounded, size: 18, color: p.accent),
                  const SizedBox(width: 4),
                  Text(
                    'Değiştir',
                    style: text.labelLarge?.copyWith(
                      fontSize: 14,
                      color: p.accent,
                    ),
                  ),
                ],
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            if (picked == null)
              const HubIconBox(Icons.add_circle_outline_rounded)
            else if (picked.type == MatchEntityType.club)
              ClubIdentityBadge(
                clubId: picked.clubId ?? 0,
                clubName: picked.displayName,
                size: 48,
              )
            else
              CountryBadge(
                country: picked.countryName ?? picked.displayName,
                width: 48,
                height: 32,
              ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    picked?.displayName ?? prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.titleMedium,
                  ),
                  if ((picked == null ? 'Listeden ara ve seç' : details)
                      .isNotEmpty)
                    Text(
                      picked == null ? 'Listeden ara ve seç' : details,
                      style: text.bodySmall?.copyWith(color: p.muted),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: p.muted),
          ],
        ),
      ],
    );
    return Semantics(
      button: true,
      label:
          '$label: ${picked?.displayName ?? 'seçilmedi'}. Değiştirmek için dokun.',
      excludeSemantics: true,
      child: picked == null
          ? Material(
              color: p.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: p.accent.withValues(alpha: .35)),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: content,
                ),
              ),
            )
          : HubHeroCard(
              onTap: onTap,
              padding: const EdgeInsets.all(16),
              child: content,
            ),
    );
  }
}

class _PopularPairRow extends StatelessWidget {
  const _PopularPairRow({
    required this.label,
    required this.left,
    required this.right,
    required this.onTap,
  });
  final String label;
  final MatchEntity left, right;
  final VoidCallback onTap;

  Widget _badge(MatchEntity e) => e.type == MatchEntityType.club
      ? ClubIdentityBadge(
          clubId: e.clubId ?? 0,
          clubName: e.displayName,
          size: 36,
        )
      : CountryBadge(
          country: e.countryName ?? e.displayName,
          width: 36,
          height: 24,
        );

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
    return Semantics(
      button: true,
      child: PitchPanel(
        onTap: onTap,
        child: Row(
          children: [
            ExcludeSemantics(
              child: SizedBox(
                width: 64,
                height: 40,
                child: Stack(
                  children: [
                    Positioned(left: 0, top: 2, child: _badge(left)),
                    Positioned(right: 0, top: 2, child: _badge(right)),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${left.displayName} × ${right.displayName}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: p.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.arrow_forward_rounded, color: p.accent, size: 20),
          ],
        ),
      ),
    );
  }
}

class _EntityPicker extends StatefulWidget {
  const _EntityPicker({
    required this.countryMode,
    required this.clubs,
    required this.countries,
  });
  final bool countryMode;
  final List<Club> clubs;
  final List<String> countries;
  @override
  State<_EntityPicker> createState() => _EntityPickerState();
}

class _EntityPickerState extends State<_EntityPicker> {
  String _query = '';
  @override
  Widget build(BuildContext context) {
    final clubs = widget.clubs
        .where((c) => SearchService.contains(c.name, _query))
        .toList();
    final countries = widget.countries
        .where((c) => SearchService.contains(c, _query))
        .toList();
    final count = widget.countryMode ? countries.length : clubs.length;
    return FractionallySizedBox(
      heightFactor: .9,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          24,
          0,
          24,
          MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.countryMode ? 'Ülke seç' : 'Kulüp seç',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Kapat',
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              autofocus: true,
              decoration: InputDecoration(
                hintText: widget.countryMode ? 'Ülke ara' : 'Kulüp ara',
                prefixIcon: const Icon(Icons.search_rounded),
              ),
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: count == 0
                  ? const EmptyState(
                      title: 'Sonuç bulunamadı',
                      message: 'Aramanı kısaltarak tekrar dene.',
                      icon: Icons.search_off_rounded,
                    )
                  : ListView.separated(
                      itemCount: count,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final title = widget.countryMode
                            ? countries[index]
                            : clubs[index].name;
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                          leading: widget.countryMode
                              ? CountryBadge(
                                  country: title,
                                  width: 40,
                                  height: 28,
                                )
                              : ClubBadge(club: clubs[index], size: 40),
                          title: Text(title),
                          subtitle:
                              !widget.countryMode &&
                                  clubs[index].league.isNotEmpty
                              ? Text(clubs[index].league)
                              : null,
                          trailing: const Icon(Icons.add_rounded),
                          onTap: () => Navigator.pop<Object>(
                            context,
                            widget.countryMode
                                ? countries[index]
                                : clubs[index],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
