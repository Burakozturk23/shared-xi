import 'package:flutter/material.dart';

import '../data/popular_clubs.dart';
import '../data/popular_matchups.dart';
import '../models/club.dart';
import '../models/match_entity.dart';
import '../services/runtime_v4/game_data_v4_query_service.dart';
import '../services/search_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/club_badge.dart';
import '../widgets/country_badge.dart';
import '../widgets/empty_state.dart';
import '../widgets/entity_header_tile.dart';
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

  @override
  Widget build(BuildContext context) {
    final p = PitchColors.of(context);
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
    return Scaffold(
      appBar: AppBar(title: const Text('Ortak oyuncu keşfi')),
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
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'İki taraf. Ortak hikâyeler.',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  _countryMode
                      ? 'Bir kulüp ve ülke seç; o kulüpte oynamış, o ülkeden futbolcuları keşfet.'
                      : 'İki kulüpte de forma giymiş futbolcuları keşfet.',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: p.muted),
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Kulüp – Kulüp'),
                      selected: !_countryMode,
                      onSelected: (_) => setState(() => _countryMode = false),
                    ),
                    ChoiceChip(
                      label: const Text('Kulüp – Ülke'),
                      selected: _countryMode,
                      onSelected: (_) => setState(() => _countryMode = true),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final slots = [
                      _SelectionSlot(
                        label: 'İlk kulüp',
                        entity: _first == null
                            ? null
                            : MatchEntity.club(_first!),
                        onTap: () => _pick(0),
                      ),
                      _SelectionSlot(
                        label: _countryMode ? 'Ülke' : 'İkinci kulüp',
                        entity: _right,
                        onTap: () => _pick(1),
                      ),
                    ];
                    if (constraints.maxWidth < 300 ||
                        MediaQuery.textScalerOf(context).scale(16) > 24) {
                      return Column(
                        children: [
                          slots[0],
                          const SizedBox(height: 16),
                          slots[1],
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: slots[0]),
                        const SizedBox(width: 16),
                        Expanded(child: slots[1]),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
                Text(
                  _countryMode
                      ? 'Ülke, futbolcunun uyruğunu belirtir.'
                      : 'Aynı kulübü iki kez seçemezsin.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (popular.isNotEmpty) ...[
                  const PitchSectionTitle('Bir eşleşmeyle başla'),
                  for (final pair in popular.take(4)) ...[
                    PitchRow(
                      title: pair.$1,
                      subtitle:
                          '${pair.$2.displayName} × ${pair.$3.displayName}',
                      icon: Icons.join_inner_rounded,
                      onTap: () => _open(pair.$2, pair.$3),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],
              ],
            ),
      bottomNavigationBar: _loading || _failed
          ? null
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: PitchAction(
                  label: 'Ortak oyuncuları gör',
                  onPressed: _first != null && _right != null
                      ? () => _open(MatchEntity.club(_first!), _right!)
                      : null,
                ),
              ),
            ),
    );
  }
}

class _SelectionSlot extends StatelessWidget {
  const _SelectionSlot({
    required this.label,
    required this.entity,
    required this.onTap,
  });
  final String label;
  final MatchEntity? entity;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label:
        '$label: ${entity?.displayName ?? 'seçilmedi'}. Değiştirmek için dokun.',
    child: PitchPanel(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 16),
            if (entity != null)
              EntityHeaderTile(entity: entity!)
            else ...[
              Icon(
                Icons.add_circle_outline_rounded,
                size: 48,
                color: PitchColors.of(context).accent,
              ),
              const SizedBox(height: 8),
              const Text('Seç'),
            ],
          ],
        ),
      ),
    ),
  );
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
