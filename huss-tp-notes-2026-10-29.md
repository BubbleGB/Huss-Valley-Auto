# TP Dodge — 2026-10-29

User requested a toggleable short teleport for avoiding traps, obstacles and
attacks, with conservative decisions and limited safe testing.

TP Dodge defaults OFF. When enabled alongside Start, it evaluates 2, 3 and
4-stud candidates and favours the shortest useful move. It has a 12-second
cooldown and two uses per round, retained across reloads on the same server.
An imminent attack must be predicted within 0.25 seconds while ordinary walking
is unsafe; a trap or thin-obstacle bypass requires at least 1.1 seconds without
progress and a meaningful route improvement. Native defensive abilities are
considered first. An active shield, forced motion, melee, dive, dash, stun,
airborne state, map transition or paused controller prevents a new TP.

Landing and exit checks use real body overlap queries, ground probes, hazard
zones and predicted attacks. The destination stays at the current height on
stable ground. Thin-obstacle bypasses require matching forward/back ray hits
with at most 1.25 studs of thickness; a second body sweep excludes that one
verified blocker and rejects additional blockers. Safe-zone/barrier/boundary,
spawn and finish parts are excluded. Nearby participant bodies are excluded
even if their collision group permits overlap. After a move, the script follows
the checked exit direction, discards cached routing/motion history and replans.
It preserves native velocity and orientation instead of adding momentum.

The 1.5-second observation window checks MovementReset and unexpected motion
residuals. A same-context reset or snapback disables further use on that server;
an observation gap over 150 ms also blocks further use because the result is
uncertain. The label distinguishes correction from observation gap. Role/map/
round changes or forced ability motion interrupt observation. A clean watch
only means these client observations saw no correction, not server acceptance.

Verification includes 25 Core policy assertions, actual isolated Roblox
collision/ground/thin-wall/boundary fixtures, complete candidate selection,
an isolated-body commit/exit test, paused commit rejection and real UI events.
Review regressions first reproduced a missed snapback across a slow frame and
a second off-centre boundary behind a thin wall; both passed after correction.
A post-TP exit-direction regression was also reproduced and fixed.

One live clear-floor trial moved the actual player exactly two studs. Immediate
and 1.7-second positions matched; MovementReset stayed 97 and the watch completed
without a correction. See huss-tp-live-2026-10-29.json. This was one bounded
trial away from other participants, using the same landing probe and commit/
observation path. No increasing-distance probes were performed. Actual trap,
attack and thin-wall teleports were not forced against live opponents; those
decisions have fixture coverage. Later exit-direction behavior was validated
with the isolated-body fixture.

No distance is established as reliably accepted. Hidden server validation,
swept trap contact, late replication and unpredictable movement can still
reject a move or cause a catch. Wide traps and thick obstacles remain normal
routing problems when no safe candidate fits the four-stud cap.
