import 'package:flutter/material.dart';

import '../models/match_entity.dart';

class EntityHeaderTile extends StatelessWidget {
  final MatchEntity entity;

  const EntityHeaderTile({super.key, required this.entity});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (entity.type == MatchEntityType.club)
          ClipOval(
            child: Image.network(
              entity.logoUrl ?? '',
              height: 52,
              width: 52,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  height: 52,
                  width: 52,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                );
              },
              errorBuilder: (context, error, stackTrace) {
                return const Icon(Icons.sports_soccer, size: 52);
              },
            ),
          )
        else
          const Icon(Icons.public, size: 52),
        const SizedBox(height: 8),
        Text(
          entity.displayName,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}