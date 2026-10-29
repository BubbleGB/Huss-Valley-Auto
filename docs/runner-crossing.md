# Runner crossing improvements

The previous runner planner used mostly static threat circles and could spend a dash whenever a path was clear. This release adds arrival-time edge checks, heading/cooldown-sensitive ready-dive costs, route retention, a minimum urgency risk weight, tactical dash decisions and observable outcome counts.

A* stores physical travel time separately from weighted route cost. Direct paths, smoothing and retained routes use the same time callbacks. Finite attacks are projected only through their committed duration; near-term catch collision checks cover 1.25 seconds. Further predictions remain soft and include uncertainty. Fast avoidance keeps refreshing current threats.

Dash decisions use native RunBoost easing and entry-speed scaling, validate dash/recovery/exit positions, and compare the escape with ordinary walking. Native cooldown starts at activation, so an early progress dash is allowed when it can recharge before the next predicted threat. Clear ground with little net gain conserves the dash.

CrossingReport separates safe/caught/timeouts from interruptions and tracks outcomes exactly once. Server deadline extensions are reflected, and a different character's death is not attributed to the previous attempt. Re-executing the controller resets its statistics.

Validation: 30 suites passed, 401 Core decision checks, zero failures; source compiled and distribution checks passed. Regression cases cover approaching versus departing chasers, finite attacks, expired projectiles, catch-space escape, time-sensitive smoothing, lane retention/abandonment, native dash displacement at every sampled time, cooldown reservation, recovery hazards and outcome lifecycle. Independent review was completed; expiry handling and deadline/character edge cases were covered by RED/GREEN tests.

During development, a candidate completed one observed crossing safely in about 8.6 seconds with no dash. In that sample, planning averaged about 2.5 ms and peaked near 14 ms. A separate synthetic nine-chaser routing query took about 24 ms. These observations are functional checks and are too small to demonstrate an improved live success rate.
