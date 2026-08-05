import '../models/player.dart';

bool playedAtClubDuring(Player p, int clubId, int fromYear, int toYear) {
  for (final stop in p.careerTimeline) {
    if (stop.clubId != clubId) continue;
    final start = stop.startYear;
    final end = stop.endYear ?? 9999;
    if (start <= toYear && end >= fromYear) return true;
  }
  return false;
}

bool playedInClubSetDuring(
  Player p,
  Set<int> clubIds,
  int fromYear,
  int toYear,
) {
  for (final stop in p.careerTimeline) {
    if (!clubIds.contains(stop.clubId)) continue;
    final start = stop.startYear;
    final end = stop.endYear ?? 9999;
    if (start <= toYear && end >= fromYear) return true;
  }
  return false;
}