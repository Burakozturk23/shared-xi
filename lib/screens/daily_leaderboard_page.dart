import 'package:flutter/material.dart';

import '../models/leaderboard_models.dart';
import 'leaderboard_page.dart';

class DailyLeaderboardPage extends StatelessWidget {
  final DateTime? date;

  const DailyLeaderboardPage({
    super.key,
    this.date,
  });

  @override
  Widget build(BuildContext context) {
    return LeaderboardPage(
      initialScope: LeaderboardScope.daily,
      dailyDate: date,
    );
  }
}
