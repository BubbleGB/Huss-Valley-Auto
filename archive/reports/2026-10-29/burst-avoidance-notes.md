# Burst and ranged avoidance — 2026-10-29

The previous runner model relied on ordinary dive clearance and observed
velocity. It could react late to abrupt acceleration, and projectile zone
projection covered only 0.36 seconds. Shield timing used player closing speed
without including projectile trajectories.

Native modules were inspected through Roblox MCP: GearPredictionClient,
GearCatalog, KnifeAbilities, CannonMotion and StepOverMotion. Rocket prediction
uses 64 studs/s for 0.42 seconds followed by 0.6 seconds of carry. Cannon uses
15/0.7 studs/s plus up to 32 studs/s of entry momentum, with 0.7-second flight
and 0.5-second carry. Step Over fakes for 0.42 seconds before a lateral burst;
the native configuration supplies its 12-stud displacement budget. These are
client configuration values; hidden server validation and replicated Until
attributes need not expose the exact internal phase.

The revised model uses explicit replicated activation when available and
observed fast motion otherwise. It predicts closest approach and first contact
analytically across a finite burst and subsequent ordinary travel. Active
attack safety margins survive deadline urgency. Cannon landing risk is treated
conservatively while airborne. Step Over reserves the upcoming lateral juke
rather than assuming its initial fake continues straight.

Ready cannon and Step Over abilities supply soft risk lanes that respect their
replicated cooldowns. Opponents' equipped gear is generally not replicated:
unknown ready gear adds a possible burst lane rather than a false active-attack
assertion. This uncertainty can cause a wider detour. Real activated attacks
remain stronger threats than speculative ones.

Projectile clearance extends to 0.8 seconds, with overlapping samples so fast
objects cannot leave gaps between zones. Remaining replicated lifetime bounds
projection, and native fallback speeds cover sparse attributes. Fresh runner
checks update threats, projectile hazards and defensive ability contact timing
at approximately 30 Hz, subject to rendered frame rate. Evasion preserves the
planned waypoint, physical collision, ground and trap checks. Native dash can
take advantage of an eligible escape turn; its full redirected path is checked.

Verification: new Core fixtures first failed for the missing trajectory model,
then passed 16 checks. An independent review identified a planned-detour
regression; a runtime fixture reproduced it, then passed after the correction.
The complete suite passed 21 suites and 283 Core decision checks plus runtime
assertions before final saved-file verification.

Live observation: the runner reached Safe with eight chasers in its threat
snapshot, six dash requests, one defensive ability request and 78 steering
adjustments. There were no recorded controller errors. Mean route-plan time
was 3.712 ms, maximum 19.798 ms, maximum observed action-check gap 65.053 ms.
This is a limited ordinary crossing observation, not a controlled comparison
or proof of escape from every ability. Opponent abilities were not forced.

Movement caps, Smart Speed policy, cooldowns, attack hitboxes, inventory and
match rules were not changed. Hidden server-only effects, late replication,
frame stalls, unpredictable direction changes and surrounded positions can
still result in a catch. The script cannot know private equipped gear with
certainty or guarantee a safe route when none exists.
