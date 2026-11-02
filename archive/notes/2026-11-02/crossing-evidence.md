# Crossing evidence and faster route updates

The existing loadstring loads this release. Full planning remains every 100 ms normally. Fresh 30 Hz action checks request an earlier plan when an opponent within 90 studs starts/changes an observed attack, unexpectedly moves more than 6 studs from its predicted position, arrives nearby, a nearby hazard appears, or the current heading is blocked. Reactive plans wait at least 1/30 second between full plans and invalidate the route cache. Fast evasive steering remains active during that wait. The timing is a scheduling target, not a guarantee under low frame rates or expensive geometry.

Projected points along a moving projectile are excluded from new-hazard detection; native projectile evasion continues to use them. Geometry checks and lane safety requirements still apply.

`getgenv().HussAutoCross:CrossingReport()` now includes `recent[i].evidence`:

- `history`: at most 20 observations, sampled no more often than every 100 ms during an ordinary runner crossing.
- Each observation contains position, velocity, selected direction, waypoint, route status, current dash availability/decision, urgency and nearby dangers. Up to four nearest threats and four hazards are retained; generated projectile trail points are excluded.
- `sampleAge` and `fresh`: the age at crossing completion; observations older than 0.5 seconds are marked stale. Missing observations are not fresh.
- `interpretation`: observations are context, not proof of which opponent or ability caused a catch.

Reports are deep copies. History resets with each attempt and stays local to the loaded script; the existing limit of 30 completed crossing records remains. Special events do not affect ordinary crossing statistics. Stop and destruction clear queued replans.

`ReactivePlans` and `LastPlanReason` expose early update counts and the latest reason. These changes passed deterministic/runtime tests; a higher live crossing success rate has not yet been established.
