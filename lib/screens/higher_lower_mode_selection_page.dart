import 'package:flutter/material.dart';

import '../models/higher_lower_state.dart';
import 'higher_lower_page.dart';

class HigherLowerModeSelectionPage extends StatelessWidget {
  const HigherLowerModeSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Higher or Lower')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Hangi kritere göre oynamak istersin?',
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 20),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(Icons.euro, size: 32),
                title: const Text('Zirve Piyasa Değeri',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: const Text('Kariyerinde gördüğü en yüksek bonservis'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HigherLowerPage(
                        criterion: HigherLowerCriterion.marketValue),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Card(
              child: ListTile(
                contentPadding: const EdgeInsets.all(16),
                leading: const Icon(Icons.sports_soccer, size: 32),
                title: const Text('Kariyer Golü',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                subtitle: const Text('Toplam kariyer gol sayısı'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const HigherLowerPage(criterion: HigherLowerCriterion.goals),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}