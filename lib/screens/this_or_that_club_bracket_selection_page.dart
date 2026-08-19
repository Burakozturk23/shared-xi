import 'package:flutter/material.dart';

import '../data/bracket_registry.dart';
import '../theme/app_theme.dart';
import 'this_or_that_page.dart';

/// Kulüp vs Kulüp altında bracket listesi.
class ThisOrThatClubBracketSelectionPage extends StatelessWidget {
  const ThisOrThatClubBracketSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final brackets = BracketRegistry.clubBrackets;

    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: AppBar(
        title: const Text('Kulüp vs Kulüp'),
        centerTitle: true,
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: brackets.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 14),
        itemBuilder: (context, index) {
          if (index == 0) {
            return const Text(
              'Bir bracket seç',
              style: TextStyle(
                color: AppTheme.hintColor,
                fontSize: 15,
              ),
            );
          }
          final b = brackets[index - 1];
          return Material(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ThisOrThatPage(bracketId: b.id),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(b.emoji, style: const TextStyle(fontSize: 28)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                b.subtitle,
                                style: const TextStyle(
                                  color: Color(0xFF26C6DA),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                  letterSpacing: 0.4,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                b.title,
                                style: const TextStyle(
                                  color: AppTheme.textColor,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right,
                            color: AppTheme.hintColor),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      b.description,
                      style: const TextStyle(
                        color: AppTheme.hintColor,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppTheme.backgroundColor,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.borderColor),
                      ),
                      child: Text(
                        b.meta,
                        style: const TextStyle(
                          color: AppTheme.hintColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
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
}