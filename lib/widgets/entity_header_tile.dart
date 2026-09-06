import 'package:flutter/material.dart';

import '../models/match_entity.dart';
import 'club_identity_badge.dart';
import 'country_badge.dart';

class EntityHeaderTile extends StatelessWidget {
  final MatchEntity entity;

  const EntityHeaderTile({super.key, required this.entity});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (entity.type == MatchEntityType.club)
          ClubIdentityBadge(
            clubId: entity.clubId ?? 0,
            clubName: entity.displayName,
            size: 52,
          )
        else
          CountryBadge(
            country: entity.countryName ?? entity.displayName,
            width: 52,
            height: 34,
          ),
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
