/// Hikâye Modu reward values the server pays (functions/config/*_catalog.json
/// and functions/story_finals.js). A test compares them, so the screens never
/// promise a number the server does not pay.
class StoryMilestone {
  const StoryMilestone(this.count, this.coins, this.xp);
  final int count, coins, xp;
}

class StoryFinal {
  const StoryFinal(this.coins, this.xp);
  final int coins, xp;
}

const uclMilestones = [
  StoryMilestone(10, 40, 75),
  StoryMilestone(20, 70, 100),
  StoryMilestone(34, 100, 150),
];

const internationalMilestones = [
  StoryMilestone(10, 40, 75),
  StoryMilestone(20, 70, 100),
  StoryMilestone(30, 90, 125),
  StoryMilestone(40, 120, 175),
];

/// One closing reward for the whole catalog (base + Ekim 2026 expansion),
/// paid once with its own receipt (`expansion_final`).
const storyFinals = <String, StoryFinal>{
  'ucl_moments': StoryFinal(20, 50),
  'international_glory': StoryFinal(20, 50),
  'dynasties': StoryFinal(20, 50),
  'turkish_nostalgia': StoryFinal(20, 50),
  'player_journey': StoryFinal(40, 100),
};

/// "10, 20 ve 34" style list of milestone counts.
String milestoneCounts(List<StoryMilestone> list) {
  final counts = [for (final m in list) '${m.count}'];
  return counts.length < 2
      ? counts.join()
      : '${counts.sublist(0, counts.length - 1).join(', ')} ve ${counts.last}';
}
