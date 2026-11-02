# Huss Valley automatic crossing and chasing

Execute [auto-play.lua](../src/auto-play.lua) in your connected Huss Valley client. It loads your saved settings and starts unless Stop everything is enabled.

New script versions are published to GitHub. Keep using the repository loadstring; no script version is written into the Delta workspace. Settings changes automatically save to an account-specific JSON preferences file.

See the [categorized UI/settings guide](ui-settings.md) for map preference, hero/chicken threshold, priorities, role/combat/camera toggles, minimize/restore and profiles. The gameplay descriptions below describe defaults unless overridden in settings.

- **Stop everything** off enables automatic play; on stops all automated actions, including rewards and equipment changes. Its state persists.
- **X** stops and unloads the script.
- Drag the title to move the window. Minimize preserves automation and shows only a square reading Huss above Valley. Tap it or press Right Shift to restore.
- Collection and Equipment categories provide free reward toggles and owned loadout selectors; see the [settings guide](ui-settings.md).

As a chaser, it first considers nearby catchable runners within 12 studs at a
compatible height and with a clear approach; the held close target remains in
that tier until 14 studs to avoid boundary flicker. Within that group, or among all runners if none are close,
it prioritizes currently invisible/cloaked runners; within that
group it favours clusters predicted 0.25 seconds ahead within 14 studs. Density
reduces effective travel cost by a bounded amount, and cluster-driven switches
require a meaningful improvement; immediate catches and substantially closer
runners retain priority. Both human and bot participants are
included using the game's participant directory. It keeps the selected
target unless another runner is at least 35% closer and four studs closer. Once
the target reaches safety, gets caught, dies, or leaves, it picks another active
runner. It checks target eligibility every frame and re-evaluates distances ten
times per second. Trapped human runners remain eligible when native contact
sampling still considers them catchable; anchored actors and movement-locked
client bots remain excluded. The panel shows the hunted player's username. While chasing,
camera following and continuous body facing are off by default; separate Chaser toggles enable them. A native dive alone receives the necessary one-time aim rotation. It estimates motion from observed
positions and reported velocity, discards teleport-sized jumps, and solves for
a reachable interception point up to 1.25 seconds ahead. It reads current movement
profiles for both participants, including round balance, knife perks, boosts and
slows. Estimates account for the chaser's current momentum and acceleration,
observed target acceleration, and braking after a temporary burst or slowdown.
Predictions stop short
of blocked paths and safe-zone barriers. Chaser routes refresh more quickly as
the interception point moves. It keeps following a shielded runner while the
short hit shield expires and avoids attacking protected, ghost-immune, or
burrowing targets. Active dash/rocket/gear motion suppresses speculative dives.
It predicts melee contact through the native 0.12-second windup and 0.18-second
active window using the game's actual swept hitbox, including Big Dagger reach.
An available predicted melee hit takes priority over a dive or placement ability.
At close range it pursues the runner's current position directly when the
segment is safe; blocked approaches still use the route planner.

Dive targeting searches predicted lead points along the runner's motion using
native eased displacement and swept hit geometry. It can lead steady lateral
movement and consider reachable targets beyond the old 7.5-stud range cap.
Close targets within eight studs need 0.14 seconds of consistent direction and
contact within 0.22 seconds; wider predictions need 0.25 seconds of consistent
direction. Every candidate must also retain native contact within 0.26 seconds
across both lateral steering changes and position uncertainty derived from
measured reply timing. This suppresses nominal-only catches that depend on a
runner following one exact path. Direction consistency is independent
of straight-line acceleration, while material turns restart observation.
Predictions include bounded observed acceleration and favour centered contact.
Every dive requires native swept-contact evidence and a valid predicted catch
time. Generic distance/alignment fallbacks cannot authorize a dive.
A valid predicted melee remains first. Dives require a clear full travel path,
no shield or evasive motion, no overlapping melee, and the native cooldown.
Additional repeat spacing is native cooldown/recovery plus 0.15 seconds for close
dives or 0.35 seconds for predicted dives (typically 1.25/1.45 seconds total),
replacing the old two/four-second waits. Actions retain native prediction and
server validation. See [dive-notes.md](../archive/reports/2026-10-29/dive-notes.md) for verification and limits.
It lets an active dive finish
without trying to turn it mid-flight.

The script reads the current map, starting side, player roles, and runner state.
It uses a bounded A* search to find short routes around obstacles and detected
hazards, with alternative finish points across the destination safe zone. Routes
include distance and chaser-risk costs; smoothing preserves the safer detours.
Regular edges and final goal connections both sample risk along the segment;
goals compete by total route cost. Shared risk samples are cached within each
search so adjacent edges do not repeatedly rescan the same threats.
It refreshes runner plans every 0.65 seconds and chaser plans every 0.25 seconds,
rechecks the next segment ten times
per second, and replans immediately when detected hazards change or a segment
becomes unsafe. Clear low-risk crossings use the direct route.
Failed coarse searches retry on a finer six-stud grid. If movement is requested
but actual position makes no progress for over 1.1 seconds, it invalidates the
route and attempts finer routing. All searches remain bounded.

When enabled, it also handles normal match prompts: the lead chaser randomly
selects an eligible runner, a challenged runner chooses Hero with five or fewer
currently participating chasers and Chicken with more than five (or an unknown
count), and map
votes choose the configured preferred map when offered, or randomly choose an offered map when Random is selected or the preference is unavailable. HeroMode can force Hero/Chicken or use the configurable chaser threshold (default 5). Existing votes are respected. Requests
are cached for that prompt and retried at most three times, one second apart;
phase changes, Stop, and X discard pending requests. Unsupported special admin game modes
pause crossing/chasing rather than applying normal-map logic to them.

While running, it uses only the equipped, owned ability for the current role,
respecting cooldowns, charges, and match restrictions. Shield timing follows
incoming catches; traps lead runners to a clear placement with predicted cluster
coverage, allowing for arming time. Bowling balls and leashes solve projectile
interception at their native travel speeds and reject unreachable throws. Other
recognized abilities use range, pressure, landing, and target protection checks.
Soul Reap reads the native carried-soul list and available unclaimed soul
records, respecting its configured capacity and range.
It does not buy, equip, or consume inventory gear. Runners avoid replicated
bowling/leash projectiles and chasers route around slowing fart clouds.

While automation and Anti-AFK are enabled, AFK buttons and the physical K shortcut are blocked and lobby AFK is cleared. A paired stationary touch is scheduled on the owned inert IDLE pad once per minute. Menus, typing, active touches and obstructing GUI defer input. No synthetic keyboard, mouse or VirtualUser events are emitted. The native IdleReportClient callback is selectively held when connection inspection is available; foreign and pre-disabled connections are preserved. Stop/X restores held callbacks and AFK controls and releases pending touch. See [AFK behavior and verification](afk-fix.md).

It explicitly avoids replicated bear traps, spring-box blast zones, banana peels,
and rising gravestones, including noncolliding triggers and announced landing
positions. It removes expired hazards and respects which role they affect.
World collision sweeps also include placed physical objects outside the map
model. Ground checks remain limited to the active map's Field. Movement, dash,
and dive paths use the same hazard and collision checks.

Ordinary runner routing now evaluates chaser motion at the runner's estimated
arrival time along each candidate path. Committed motion is finite, and hard
catch-space predictions are limited to 1.25 seconds; later route segments receive
soft uncertainty costs and are checked again as the runner approaches. The same
timing is used for direct routes, A* edges, and shortcut smoothing. Physical
obstacles, missing ground, detected traps and immediate predicted catches retain
hard exclusions. A runner already inside a danger area may move out of it.

Ready-dive costs account for observed facing and cooldown rather than treating
the entire dive range as a solid circle. These are conservative risk estimates,
not guarantees that a chaser cannot turn or use an unobserved ability. Native
active ability trajectories still receive their stronger protection. A viable
existing lane is retained unless a new route improves cost materially; an unsafe
lane is abandoned immediately.

The runner still considers the round timer, route ETA, chaser density and ratio,
stalling, and relative finish pacing toward the front half. Urgency increases
progress preference and reduces detour costs, but keeps a risk-weight floor and
never removes immediate catch clearance, geometry, or trap checks.

Dash is reserved when its net progress benefit is small or another threat will
arrive before native cooldown ends. A safe dash that improves escape from an
incoming attack remains eligible. Prediction follows the native eased RunBoost
curve and entry-speed-scaled distance, then checks recovery and the exit path.
Pumpkin Hunt retains its separate event movement policy.

`getgenv().HussAutoCross:CrossingReport()` returns attempts started, safe crossings,
catches, deadline-confirmed timeouts, interruptions, and up to 30 recent records.
Success rate uses only resolved safe/caught/timeout attempts. Manual Stop,
context changes and ambiguous early exits are interruptions, not assumed losses.
Statistics are local to the loaded controller and reset on re-execution. They
exclude special events and do not establish an improvement without comparable
live samples. See [crossing verification](runner-crossing.md).
Runner avoidance also reads replicated rocket/cannon/Step Over activation and
observed fast movement, predicts finite burst paths and subsequent ordinary
travel, and keeps an active-attack safety margin even under deadline pressure.
Ready native knife abilities contribute a soft predicted risk lane; opponents'
private equipped gear remains uncertainty, not asserted knowledge. Fresh threat
checks run at approximately 30 Hz and can turn sideways out of committed burst
paths while retaining the planned route waypoint and obstacle exclusions.
Bowling/leash paths receive up to 0.8 seconds of continuous lookahead, bounded
by their remaining lifetime. Defensive ability timing uses predicted contact
with these projectiles and fast chasers, rather than distance alone.
`ThreatDiagnostics` and `EvasiveAdjustments` expose fresh threat counts and
steering adjustments. See [burst-avoidance-notes.md](../archive/reports/2026-10-29/burst-avoidance-notes.md) for evidence
and limits; this improves anticipation but cannot guarantee immunity to catches.
It can steer outward if a hunter or new hazard already overlaps the runner; a
safe escape is not guaranteed when surrounded.

Collision checks use the character's collision group so safe zones remain
accessible. It waits when safe, caught, out of a match, or changing maps,
and resumes on the next active crossing. Runners request dash on clear running
turns of at least 35 degrees, with momentum and cooldown checks; the game requires
a turn to activate dash. Clearance covers the full current-profile dash distance,
including intent remembered from before a turn. The preview reproduces native
redirected travel (which can be lateral for a diagonal input) and checks that
actual segment. Reexecution replaces the previous copy.

The search is bounded and uses currently replicated hazards; it cannot guarantee
the globally fastest route, detect hidden server-only traps, or guarantee escape.
Stop prevents further movement and action requests and restores facing
control. Actions already started finish through the game's own controller.

Optional controls:

**TP Assist** is OFF by default. Its Movement toggle enables short automatic
2/3/4-stud dodges, with a 12-second cooldown and at most two uses per round.
It favours safe ordinary movement, and only considers imminent attacks or a
blocked trap/thin-obstacle route after at least 1.1 seconds without progress.
As a chaser, it also considers a stable active runner within 14 studs when a
short move would create a clear predicted melee opportunity with at least
1.5 studs of interception gain. It respects the native melee windup/hitbox,
cooldown and target shields/evasive motion, and conserves TP when melee already
reaches. It uses explicit predicted aim for ordinary combat on a fresh
action check after landing. Correction observation continues through melee.
Landings need clear body space, stable same-height ground, a checked exit and
safe threat predictions. It rejects safe-zone boundaries, thick/unverified
obstacles and nearby bodies; a four-stud jump cannot bypass every trap.
It preserves velocity, moves along the checked exit direction and replans.
Stop prevents new jumps. Native forced movement, attacks, stuns and airborne
states suspend TP use. The next 1.5 seconds are observed for movement resets or
snapbacks. A correction or an observation gap blocks further TP use on that
server, including after script reload. The button and `TPReport()` show why.
`getgenv().HussAutoCross:SetTPAssistEnabled(true)` controls the same toggle;
the older `SetTPDodgeEnabled` API remains an alias.
The feature does not establish an undetectable distance or guarantee escape.
See [tp-notes.md](../archive/reports/2026-10-29/tp-notes.md) for test scope and the limited live trial.

All owned ScreenGuis use the game's `LightsOutKeep` attribute before entering PlayerGui,
so blackout handling preserves the interface.
[blackout.spec.lua](../tests/runtime/blackout.spec.lua) verifies visibility and control lifecycle in
native blackout ownership and lifecycle checks; the event was inactive during the latest run.

While running, the local player's final native movement profile is scaled by
the slider's selected multiplier, from 1.00x to 2.00x in 0.05 steps (default
1.05x). Live trials found corrections at 1.10x and above; 1.05x was clean in the
longer speed-only validation before the instant-acceleration feature. These
changes remain subject to server corrections. Select 1.00x for the native speed
cap; ordinary enabled movement still uses instant acceleration.
Drag the slider with a mouse or touch to change it immediately.
Role, crossing balance, knife perks, consumables, slows, and ability buffs
are resolved by the game first. Ordinary running reaches its current cap in one
native model step using finite high acceleration. Braking, dash distance, dash
timing, stuns, and forced ability motion retain their native controls. Other
players retain native profiles. Stop
returns to native speed; X removes the wrapper. Forced ability motions such as
rocket flight, teleports, and dives retain their native motion controllers.
`getgenv().HussAutoCross:SpeedReport()` returns normal and applied running speed.
`getgenv().HussAutoCross:SetSpeedMultiplier(1.50)` sets the same slider value.

**Smart speed** is ON by default and can be toggled in Movement, or with
`getgenv().HussAutoCross:SetSmartSpeedEnabled(false)`. An active opposite-role
participant within 12 studs and line of sight triggers a burst to
1.10x total speed for 0.4 seconds. It does not multiply the slider again or reduce a higher
manual slider setting. A new burst requires separation to 20 studs and a
12-second start-to-start cooldown, including across round and role changes. Stop, toggle-off, or own movement
suspension cancels the burst. Changing chase targets alone does not cancel it.
A same-phase movement reset during a burst or its four-second post-burst watch cancels it, adds
15 seconds of backoff, and limits future smart peaks to 1.05x on that server.
That learned limit survives script reloads for this burst policy and resets for
a different server. Limits learned for the old three-second policy do not block
this separately authorized short-burst trial.
Movement shows the learned limit and remaining burst time; SpeedReport includes the base
multiplier, effective multiplier, smart state, and remaining time.
[speed.spec.lua](../tests/core/speed.spec.lua) and [speed.spec.lua](../tests/runtime/speed.spec.lua) verify scaling, cleanup,
other-player isolation, and reexecution without stacking.
[speed.spec.lua](../tests/runtime/speed.spec.lua) checks all 21 values and changes while paused.
[wind-input.spec.lua](../tests/runtime/wind-input.spec.lua) checks actual touch title dragging, slider movement and release without changing camera/player pose.
[smart-policy.spec.lua](../tests/core/smart-policy.spec.lua) and [smart.spec.lua](../tests/runtime/smart.spec.lua) check burst
duration/rearming/correction backoff, race pressure, close-target choice, Hero
thresholds, native first-frame speed, toggling, and runtime expiry/cache cleanup.

```lua
getgenv().HussAutoCross:Start()
getgenv().HussAutoCross:Stop()
getgenv().HussAutoCross:Destroy()
```

Verification uses the real Roblox runtime. Load the portion before `-- Runtime`
with `return Core` appended and pass that table to the function returned by
[auto-cross.spec.lua](../tests/core/auto-cross.spec.lua), [routing.spec.lua](../tests/core/routing.spec.lua), [advanced.spec.lua](../tests/core/advanced.spec.lua), and
[strategy.spec.lua](../tests/core/strategy.spec.lua), and [abilities.spec.lua](../tests/core/abilities.spec.lua).
[antiafk.spec.lua](../tests/runtime/antiafk.spec.lua) verifies native AFK control and reporter restoration with an isolated touch sink. [Input checks](../tests/runtime/input.spec.lua) exercise touch-only ownership, obstruction and paired release; no desktop events are injected.
[prompt.spec.lua](../tests/runtime/prompt.spec.lua) drives the retry controller through real Heartbeat
events with isolated phase/token snapshots and sends no remotes.
Pass the full script source to the function returned
by [auto-cross.spec.lua](../tests/runtime/auto-cross.spec.lua) to exercise native module integration, unloading and replacement. WindUI and touch fixtures cover the current controls. The runtime test leaves automation stopped.

[runner.lua](../tests/runner.lua) runs the complete suite when supplied the controller source
and a table mapping test filenames to their source strings. It reports each
suite independently and restores running state, speed, and panel position.
The self-contained Delta copy is [huss-test-suite.txt](../dist/huss-test-suite.txt); it tests the current
[huss-auto-cross.txt](../dist/huss-auto-cross.txt). Startup fault injection verifies partial UI/bindings are
removed, the native shared profile getter is restored, and reexecution works.
The controller publishes its API only after initialization succeeds.

Runtime performance is available as `Plans`, `LastPlanMS`, `MaxPlanMS`, and
`TotalPlanMS` on `getgenv().HussAutoCross`. See the dated full audit report and
JSON test/live results for evidence and remaining validation limits.

Action decisions run at approximately 30 Hz independently of 10 Hz route
checks, subject to rendered frame rate. `ActionTiming` separates request,
local prediction, observed activation, and matched server-reply measurements;
`ActionTimeline` retains the latest 32 requests. Configured windup, local visual
activation, server acceptance, and a successful hit are distinct observations.
See [action-timing-report.md](../archive/reports/2026-10-29/action-timing-report.md) for measured samples, native timing,
hit geometry, and validation limits. The complete suite now includes the native
geometry/cluster fixtures and the isolated timing/lifecycle runtime fixture.

## Pumpkin Hunt

Pumpkin Hunt is detected automatically. While participating, the script seeks pumpkin people, keeps baiting distance, sidesteps telegraphed lunges, and uses native runner dash only along a checked path. It widens spacing on the last life and stops when eliminated or when all pumpkins are gone. Normal crossing/chasing resumes after the event.

No coin donations or reward opening are automated. Smart Speed bursts, player combat, gear use, and TP Assist are suspended during Pumpkin Hunt. The regular speed slider still applies.
