import 'package:flutter/material.dart';
import '../models/club.dart';

class ClubCard extends StatelessWidget {
  final Club club;
  final bool isSelected;
  final VoidCallback onTap;

  const ClubCard({
    super.key,
    required this.club,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blue.withValues(alpha:0.25)
              : const Color(0xFF161B22),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? Colors.blue : Colors.white24,
            width: 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
  club.logo,
  height: 60,
  width: 60,
  errorBuilder: (context, error, stackTrace) {
    return const Icon(
      Icons.sports_soccer,
      size: 60,
      color: Colors.white54,
    );
  },
),

            const SizedBox(height: 12),

            Text(
              club.name,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}