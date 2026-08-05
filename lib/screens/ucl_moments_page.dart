import 'package:flutter/material.dart';

import '../data/ucl_moments.dart';
import '../models/match_entity.dart';
import '../repositories/repository.dart';
import 'game_page.dart';

class UclMomentsPage extends StatelessWidget {
  const UclMomentsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('UCL Moments')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: uclMoments.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final moment = uclMoments[index];

          return Card(
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _startMatch(context, moment),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (moment.year.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(moment.year,
                                style: const TextStyle(
                                    fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber)),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Expanded(
                          child: Text(moment.title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(moment.scoreLabel,
                        style: const TextStyle(fontSize: 13, color: Colors.grey, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text(moment.narrative, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: const [
                        Text('Ortak oyuncuları bul',
                            style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.w600)),
                        SizedBox(width: 4),
                        Icon(Icons.arrow_forward, size: 14, color: Colors.blue),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  void _startMatch(BuildContext context, UclMoment moment) {
    final clubA = Repository.instance.clubById(moment.clubIdA);
    final clubB = Repository.instance.clubById(moment.clubIdB);

    if (clubA == null || clubB == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bu maç için kulüp verisi bulunamadı.')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => GamePage(
          entity1: MatchEntity.club(clubA),
          entity2: MatchEntity.club(clubB),
        ),
      ),
    );
  }
}