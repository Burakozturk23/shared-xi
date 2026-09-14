import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_feedback.dart';
import '../app/route_appearance.dart';
import '../controllers/vs_bot_controller.dart';
import '../models/club.dart';
import '../services/runtime_v4/game_data_v4_query_service.dart';
import '../services/search_service.dart';
import '../theme/ortak_saha_theme.dart';
import '../widgets/club_badge.dart';
import '../widgets/pitch_ui.dart';
import 'team_race_page.dart';

/// V4-backed setup for Botla Oyna > Takım Yarışı.
class VsBotClubSelectionPage extends StatefulWidget {
  const VsBotClubSelectionPage({super.key});

  @override
  State<VsBotClubSelectionPage> createState() => _VsBotClubSelectionPageState();
}

class _VsBotClubSelectionPageState extends State<VsBotClubSelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  List<Club> _clubs = const <Club>[];
  Club? _selected;
  VsBotDifficulty _difficulty = VsBotDifficulty.medium;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_loadClubs());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadClubs() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final clubs = await GameDataV4QueryService.instance.sharedXiClubCatalog();
      if (!mounted) return;
      setState(() {
        _clubs = clubs;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Takım listesi yüklenemedi.';
      });
      debugPrint('[TeamRaceSetup] $error');
    }
  }

  void _start() {
    final club = _selected;
    if (club == null) return;
    AppFeedback.selection();
    Navigator.of(context).push(
      LinkballRoute(
        modern: true,
        builder: (_) => TeamRacePage(
          userClub: club,
          difficulty: _difficulty,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchText.trim();
    final filtered = query.isEmpty
        ? _clubs
        : _clubs
            .where((club) => SearchService.contains(club.name, query))
            .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: const Text('Takım Yarışı')),
      body: SafeArea(
        bottom: false,
        child: _loading
            ? _message(
                icon: Icons.shield_outlined,
                title: 'Takımlar hazırlanıyor',
                text:
                    'Ortak oyuncu havuzu yükleniyor. Bu işlem yalnızca ilk açılışta biraz sürebilir.',
                loading: true,
              )
            : _error != null
            ? _message(
                icon: Icons.cloud_off_outlined,
                title: 'Takımlar yüklenemedi',
                text:
                    'Bağlantıyı veya oyun veri paketini kontrol edip yeniden deneyebilirsin.',
                actions: [
                  PitchAction(label: 'Yeniden dene', onPressed: _loadClubs),
                ],
              )
            : CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverToBoxAdapter(child: _header()),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    sliver: SliverGrid(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) => _clubCard(filtered[index]),
                        childCount: filtered.length,
                      ),
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 190,
                        mainAxisExtent: 148,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                      ),
                    ),
                  ),
                  if (filtered.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: Text('Takım bulunamadı.')),
                    ),
                ],
              ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: PitchAction(
          label: _selected == null
              ? 'Önce takımını seç'
              : '${_selected!.name} ile devam et',
          onPressed: _selected == null ? null : _start,
        ),
      ),
    );
  }

  Widget _header() {
    final p = PitchColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Takımını seç', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 8),
        Text(
          'Seçtiğin kulübün ortak oyuncularını bottan önce bul.',
          style:
              Theme.of(context).textTheme.bodyMedium?.copyWith(color: p.muted),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _searchController,
          onChanged: (value) => setState(() => _searchText = value),
          decoration: const InputDecoration(
            hintText: 'Kulüp ara',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const PitchSectionTitle('Zorluk'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final difficulty in VsBotDifficulty.values)
              ChoiceChip(
                label: Text(_difficultyLabel(difficulty)),
                selected: _difficulty == difficulty,
                onSelected: (_) {
                  AppFeedback.selection();
                  setState(() => _difficulty = difficulty);
                },
              ),
          ],
        ),
        if (_selected != null) ...[
          const SizedBox(height: 16),
          PitchPanel(
            child: Row(
              children: [
                ClubBadge(club: _selected!, size: 48),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Seçilen takım',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _selected!.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.check_circle_rounded, color: p.accent),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _clubCard(Club club) {
    final p = PitchColors.of(context);
    final selected = club.id == _selected?.id;
    return Semantics(
      button: true,
      selected: selected,
      label: '${club.name}, ${club.country}',
      child: PitchPanel(
        onTap: () {
          AppFeedback.selection();
          setState(() => _selected = club);
        },
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClubBadge(club: club, size: 48),
            const SizedBox(height: 8),
            Text(
              club.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 4),
            Text(
              club.country,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: selected ? p.accent : p.muted,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _message({
    required IconData icon,
    required String title,
    required String text,
    bool loading = false,
    List<Widget> actions = const <Widget>[],
  }) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 40),
        Icon(icon, size: 42, color: PitchColors.of(context).accent),
        const SizedBox(height: 20),
        Text(title, style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 12),
        Text(text),
        if (loading) ...[
          const SizedBox(height: 24),
          const LinearProgressIndicator(minHeight: 4),
        ],
        if (actions.isNotEmpty) ...[
          const SizedBox(height: 28),
          ...actions,
        ],
      ],
    );
  }

  String _difficultyLabel(VsBotDifficulty difficulty) => switch (difficulty) {
        VsBotDifficulty.easy => 'Kolay',
        VsBotDifficulty.medium => 'Orta',
        VsBotDifficulty.hard => 'Zor',
      };
}
