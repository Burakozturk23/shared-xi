# Step 05B — Server-owned Daily leaderboard authority

05A found B03/B04/B05 as production blockers. This step moves Daily leaderboard
write authority to callable Cloud Functions and adds version-controlled RTDB rules.

The server owns session start time, derives score, success rate, time tie-break,
streak and final timestamp, then writes through Admin SDK. Clients cannot write
`dailyLeaderboard` or `dailyScoreSessions` directly.

App Check enforcement is deliberately postponed to Step 05C so Play Integrity
can be installed and tested before `enforceAppCheck: true` is enabled.
