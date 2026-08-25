import 'package:flutter/material.dart';

import '../data/build_xi_themes.dart';
import '../services/squad_challenge_progress_service.dart';
import 'build_xi_formation_selection_page.dart';

/// Squad Challenge – Tema seçim (kategori + kilit)
class BuildXiThemeSelectionPage extends StatefulWidget {
  const BuildXiThemeSelectionPage({super.key});

  @override
  State<BuildXiThemeSelectionPage> createState() =>
      _BuildXiThemeSelectionPageState();
}

class _BuildXiThemeSelectionPageState extends State<BuildXiThemeSelectionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _totalStars = 0;
  final Map<String, int> _starsMap = {};
  bool _loading = true;

  static const _tabs = [
    BuildXiCategory.leagues,
    BuildXiCategory.regions,
    BuildXiCategory.rivalries,
    BuildXiCategory.special,
  ];

  static const _tabLabels = ['Ligler', 'Bölgeler', 'Rivalries', 'Özel'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final svc = SquadChallengeProgressService.instance;
    final total = await svc.getTotalStars();
    final map = <String, int>{};
    for (final t in buildXiThemes) {
      map[t.id] = await svc.getStars(t.id);
    }
    if (!mounted) return;
    setState(() {
      _totalStars = total;
      _starsMap.addAll(map);
      _loading = false;
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Squad Challenge'),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            for (var i = 0; i < _tabLabels.length; i++)
              Tab(text: _tabLabels[i]),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 20),
                  const SizedBox(width: 4),
                  Text(
                    '$_totalStars',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: [
                for (final cat in _tabs) _buildCategoryList(cat),
              ],
            ),
    );
  }

  Widget _buildCategoryList(BuildXiCategory category) {
    final themes = themesByCategory(category);
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: themes.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final theme = themes[index];
        final stars = _starsMap[theme.id] ?? 0;
        final unlocked = _totalStars >= theme.unlockStars;

        return Card(
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            enabled: unlocked,
            title: Text(
              theme.name,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: unlocked ? null : Colors.grey,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  theme.description,
                  style: TextStyle(
                    color: unlocked ? Colors.grey : Colors.grey.shade600,
                    fontSize: 13,
                  ),
                ),
                if (!unlocked) ...[
                  const SizedBox(height: 6),
                  Text(
                    '🔒 ${_totalStars}/${theme.unlockStars} yıldız gerekli',
                    style: const TextStyle(
                      color: Colors.orangeAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
            trailing: unlocked
                ? _StarRow(stars: stars)
                : const Icon(Icons.lock, color: Colors.grey),
            onTap: unlocked
                ? () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            BuildXiFormationSelectionPage(theme: theme),
                      ),
                    );
                    // Geri dönünce progress yenile
                    _loadProgress();
                  }
                : null,
          ),
        );
      },
    );
  }
}

class _StarRow extends StatelessWidget {
  final int stars;
  const _StarRow({required this.stars});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        return Icon(
          i < stars ? Icons.star : Icons.star_border,
          color: Colors.amber,
          size: 18,
        );
      }),
    );
  }
}
