# Huss action timing and cluster audit — 2026-10-29

The current connected client's replicated modules were inspected directly through
Roblox MCP. Contact predictions use native client geometry; this does not reveal
all hidden server validation or guarantee a successful catch.

## Changes

Runner selection estimates clusters 0.25 seconds ahead in a 14-stud radius,
with height filtering, a capped density discount, and switching margins.
Close clear catches and invisible-runner tiers remain ahead of density.
Held close targets have a 12/14-stud entry/exit band.

Melee sweeps the actual contact box over its windup/active window and takes
priority over speculative dives and placement abilities. Dive predictions use
native eased displacement, early contact windows, and existing conservative
momentum/stability gates. Both retain obstruction and protection checks.
Dash previews reproduce native intent-history redirection and validate the
resulting full travel segment. Bear traps score predicted cluster coverage;
bowling balls and leashes use projectile interception.

Action opportunities are checked at approximately 30 Hz, independently of
10 Hz route checks, subject to render frame rate. Native eligibility, recovery,
cooldown, charges, ownership, and server validation remain in use.

## Native timing and contact geometry

| Action | Native start and duration | Native client geometry / limits |
| --- | --- | --- |
| Melee | Synchronous prediction; 120 ms windup, 180 ms active, 550 ms recovery; 850 ms total | Width 5.3, height 5.6; forward interval -0.5 to 4.3 studs; overlap 1.9. Big Dagger doubles the forward reach to 8.6. Commit distance 5.25 and tracking distance 12 are different configuration values, not the contact box. |
| Dive | Synchronous request/prediction; motion begins in physics. Profile varies with entry speed. A typical long profile is approximately 337 ms movement plus 663 ms recovery, cooldown 1.1 s. | Native replay width 4.94, height 4.75, forward interval 0 to 6.08 for the inspected long profile. Movement uses native eased displacement. Additional server/physical collision checks remain authoritative. |
| Dash | Request buffered for up to 150 ms, consumed at native Input+1 render step; 280 ms movement, 200 ms recovery, 1.1 s cooldown in inspected configuration | Movement ability with no offensive contact box. Distance scales with native profile; remembered input direction can redirect a diagonal input into lateral travel. |
| Bear trap | Owned ability dispatch; visual hand hold 180 ms plus approximately 570 ms flight. Prediction conservatively allows 900 ms before contact opportunity. | Throw range 10, trigger radius 2, stun 500 ms, life 12 s; 35 s cooldown. Hidden server arming time was not independently established. |
| Shield | Native owned ability and replicated HitShielded effect | 750 ms protection; 45 s cooldown. |
| Bowling ball / leash | Projectile intercept uses native speeds 42 / 65 studs/s | Ball duration 2 s; leash throw range 15. Catalog radius fields are not assumed to be projectile body hitboxes. |

Native TouchActionButton invokes touch on InputBegan (touchdown); its non-touch
Activated path dispatches on activation/click release. Native mouse/keyboard
combat handlers dispatch synchronously after eligibility checks. The script
calls the same native requests without a physical click. Its measured
request-to-prediction and request-to-observed-activation timings below must
not be presented as human click reaction time.

## Live measurements

Captured during ordinary enabled chaser play after the new full suite passed:

| Action | Count / accepted | Dispatch to local prediction or dispatch | Dispatch to observed activation | Matching server reply |
| --- | --- | --- | --- | --- |
| Melee | 3 / 3 | 0.056–0.062 ms prediction | 122.8–142.6 ms active phase | 73.6–92.1 ms |
| Dive | 1 / 1 | 0.396 ms prediction | 10.861 ms first simulation | 74.773 ms |
| Bear trap | 1 / 1 | 0.587 ms dispatch | 92.201 ms replicated visual | 92.295 ms |
| Dash | No eligible live sample in this observation window | Native source and fixture verified | Not measured live | No individual action reply assumed |

Bear-trap visual appearance is not trap arming. Server acceptance is not a hit.
Server-reported start timestamps matched melee requests and differed by 0.259 ms
for the dive; these timestamp offsets are not network transit measurements.
Native network ping was approximately 17 ms during inspection. Actual action
reply measurements above include scheduling and replication behavior.

The captured dive used 323.050 ms movement plus 676.950 ms recovery, demonstrating
why timings are read from each current profile rather than hardcoded.
Raw observations are saved in huss-action-live-2026-10-29.json.
ActionTiming aggregates counts/min/max/mean/last separately for each stage;
ActionTimeline retains at most 32 requests. No synthetic fixture samples are
left in live telemetry.

## Verification and limits

Full native-client suite: 19 suites passed, 0 failed, 267 Core decision checks,
plus runtime assertions for UI/input, startup rollback, speed/profile cleanup,
prompts, blackout, anti-AFK, timing, bounded history and stopping/reexecution.
New fixtures exercise actual HitReplayMath and MovementModel behavior,
cluster preference/hysteresis, blocked close approaches, melee-before-dive,
Big Dagger, protected targets, trap coverage and projectile interception.

Only the currently equipped bear-trap ability received a live cast in this
window. Other inventory abilities and runner dash have native-source/fixture
coverage, not fresh live timing samples. Frame stalls, future game updates,
target direction changes, hidden hazards and server rules can change outcomes.
