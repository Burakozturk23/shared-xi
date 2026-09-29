import 'package:flutter_test/flutter_test.dart';
import '../lib/models/football_calendar_theme.dart';
import '../lib/services/daily_challenge_service.dart';

void main() {
  test(
    'daily fixtures require enough answers to finish their actual target',
    () {
      for (final theme in [
        FootballCalendarTheme.fromFixture(
          isDerby: true,
          leagueId: 203,
          label: '',
        ),
        FootballCalendarTheme.fromFixture(
          isDerby: false,
          leagueId: 2,
          label: '',
        ),
        FootballCalendarTheme.fromFixture(
          isDerby: false,
          leagueId: 39,
          label: '',
        ),
        FootballCalendarTheme.forDate(DateTime(2026, 9, 28)),
      ]) {
        expect(
          DailyChallengeService.hasEnoughAnswers(theme.targetFinds - 1, theme),
          isFalse,
        );
        expect(
          DailyChallengeService.hasEnoughAnswers(theme.targetFinds, theme),
          isTrue,
        );
      }
    },
  );
}
