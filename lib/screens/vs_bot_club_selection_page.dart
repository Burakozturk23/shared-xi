import 'package:flutter/material.dart';

import '../controllers/vs_bot_controller.dart';
import '../models/club.dart';
import '../repositories/repository.dart';
import '../services/search_service.dart';
import '../theme/app_theme.dart';
import '../widgets/club_card.dart';
import 'vs_bot_page.dart';

class VsBotClubSelectionPage extends StatefulWidget {
  const VsBotClubSelectionPage({super.key});

  @override
  State<VsBotClubSelectionPage> createState() => _VsBotClubSelectionPageState();
}

class _VsBotClubSelectionPageState extends State<VsBotClubSelectionPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';
  Club? _selected;
  VsBotDifficulty _difficulty = VsBotDifficulty.medium;

  late final List<Club> _clubs;

  @override
  void initState() {
    super.initState();
    _clubs = Repository.instance.clubs;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _start() {
    if (_selected == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VsBotPage(
          userClub: _selected!,
          difficulty: _difficulty,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _clubs
        .where((c) => SearchService.contains(c.name, _searchText))
        .toList();

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Bot’a Karşı'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Takımını seç, rastgele rakip kulübe karşı bot ile yarış.',
              style: TextStyle(color: AppTheme.hintColor, fontSize: 14),
            ),
            const SizedBox(height: 16),
            const Text(
              'Zorluk',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppTheme.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _DiffChip(
                  label: 'Kolay',
                  selected: _difficulty == VsBotDifficulty.easy,
                  onTap: () => setState(() => _difficulty = VsBotDifficulty.easy),
                ),
                const SizedBox(width: 8),
                _DiffChip(
                  label: 'Orta',
                  selected: _difficulty == VsBotDifficulty.medium,
                  onTap: () =>
                      setState(() => _difficulty = VsBotDifficulty.medium),
                ),
                const SizedBox(width: 8),
                _DiffChip(
                  label: 'Zor',
                  selected: _difficulty == VsBotDifficulty.hard,
                  onTap: () => setState(() => _difficulty = VsBotDifficulty.hard),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _searchController,
              style: const TextStyle(color: AppTheme.textColor),
              decoration: const InputDecoration(
                hintText: 'Kulüp ara...',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _searchText = v),
            ),
            const SizedBox(height: 8),
            if (_selected != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Seçilen: ${_selected!.name}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            Expanded(
              child: GridView.builder(
                itemCount: filtered.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1,
                ),
                itemBuilder: (context, index) {
                  final club = filtered[index];
                  return ClubCard(
                    club: club,
                    isSelected: club == _selected,
                    onTap: () => setState(() => _selected = club),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 55,
              child: ElevatedButton(
                onPressed: _selected != null ? _start : null,
                child: const Text(
                  'OYUNU BAŞLAT',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DiffChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _DiffChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      selectedColor: AppTheme.primaryColor,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppTheme.textColor,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}