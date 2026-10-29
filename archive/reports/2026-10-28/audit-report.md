# Huss Valley full automation audit — 2026-10-28

Audited the standalone controller against the connected client's native game
modules, inspected its decision/runtime code, ran the complete real-VM suite,
and requested independent reviews before and after the fixes. This covers the
automation's game interactions; it does not claim access to server-only code.

## Game behavior checked

- Match phases, starting side, safe/caught/active states, role changes, random
  eligible hero selection, Chicken responses, and bounded map-vote retries.
- Movement profiles, base and role speeds, round balance, knife perks, boosts,
  slows, native acceleration/braking, turn-triggered dash, and action cooldowns.
- Tackle variants, melee timing and geometry, prediction/acknowledgement,
  protected/shielded/evasive actors, human and client-bot target sampling.
- Equipped/owned ability state, native ability restrictions, charges and ready
  times, throw/landing direction, server validation, and rejection backoff.
- Replicated traps, projectiles, gravestones, slowing clouds, obstacle collision
  groups, ground checks, multi-goal A*, risk-preserving smoothing, time pressure,
  chaser density, and route recovery.
- AFK controls, virtual touch lifecycle and hit testing, Stop/X cleanup, shared
  profile restoration, script replacement, startup failures, and blackout UI.

Native evidence included MovementConfig/MovementModel/MovementProfiles,
BoostInput/ControlGate, GameConfig/TackleProfile/TacklePrediction,
ContactCatchConfig/CombatPrediction, GearCatalog/GearPredictionClient,
AbilityRule, ParticipantDirectory, SoulReapClient and replicated soul records,
and LightsOutClient. No purchases, equips, or inventory consumables were added.

## Changes delivered

1. **Route costs include the finish.** The old A* returned the first reachable
   goal within its connection radius, ignoring that final edge's risk and
   length. It now queues goal transitions with full cost and samples risk on
   regular edges too. Regressions cover a narrow dangerous finish strip, risk
   between vertices, and competing nearby finish points.
2. **Risk sampling reuses work.** Stable samples are cached by Vector3 position
   within each route search. Shared vertices no longer repeatedly rescan the
   same threats. Searches retain their node bounds.
3. **Initialization is transactional.** Cleanup exists before UI/resource
   mutations. The shared movement getter and global API are installed only
   after successful initialization. Injected failures after UI creation and
   getter installation restore resources and allow immediate reexecution.
   Legacy incomplete globals no longer block startup.
4. **Keepalive avoids active non-button UI.** Hit testing follows GUI ancestors,
   visibility, and active/input-catching controls. It now defers over frames
   and text drag handles instead of inadvertently manipulating them. A real
   full-screen active-frame test verifies both deferral and resumption.
5. **Soul Reap uses native state.** Capacity comes from the player's
   SoulReapFrom comma-separated list. Available souls come from
   Game.SoulReapSouls records (Victim, Body, TakeBy), respecting range, ownership,
   claims, and the configured cap. The old guessed count/actor attributes
   could waste casts or miss souls.
6. **Trapped human runners remain targetable.** Native contact sampling does
   not exclude a human merely for MovementLocked. Targeting now follows that
   distinction while retaining native exclusions for anchored roots and
   movement-locked client bots, plus separate immunity checks.
7. **Verification is repeatable.** A unified suite reports individual failures
   and restores the user's enabled state, speed setting, and panel position.
   Per-plan count, duration, maximum, and total timing are exposed for future
   performance diagnosis.

## Verification

All **15 suites pass**, including **209 counted decision assertions**, plus the
runtime suites' own assertions. Decision suites cover steering, targeting,
combat, routing, abilities, time pressure, speed modifiers, and the new audit
regressions. Runtime suites cover real Heartbeat prompt retry state, native
dash, Start/Stop/X, dragging, replacement, 21 slider steps and mouse/touch input,
profile isolation/restoration, blackout exemption, AFK control restoration,
active-overlay avoidance, and startup fault injection.

The baseline suite passed before changes. New regressions were observed failing
before the corresponding fixes. The final independent reviewer reported no
important findings. Raw suite results are in
[audit-test-results.json](../../results/2026-10-28/audit-test-results.json).

The delivered Delta bundle was also executed against its saved controller file:
15/15 suites passed with 209 decision assertions. One earlier packaged rerun
produced an intermittent active-overlay assertion; the test now explicitly
waits for native hit-test registration before starting. The final bundle's
results are in [audit-delivered-test-results.json](../../results/2026-10-28/audit-delivered-test-results.json).

The final live observation ran for **80.46 seconds**, sampled 308 controller
states, and observed **two successful crossings** across normal match phases.
It recorded no controller movement, ability, anti-AFK, or prompt errors.
Across 138 plans, average planning duration was **1.54 ms**, with a **6.27 ms**
maximum. These timings are one server/workload sample, not a benchmark claim
against the old version. Raw transitions are in
[audit-live-observation.json](../../results/2026-10-28/audit-live-observation.json).

## Limits and next improvements

- Soul Reap is not currently equipped/owned in the live loadout. Its mapping
  and decisions have native-source and fixture coverage; live server acceptance
  of that ability path remains unverified. Other unequipped ability combinations
  likewise cannot all be exercised live without changing the user's inventory.
- Server-only hazards, missing replication, changed native contracts, opponents'
  decisions, and all map/event combinations cannot be exhaustively simulated in
  one live session. Geometry checks use currently replicated information.
- Routing remains synchronous and bounded. Current measurements did not justify
  a risky scheduler rewrite. Incremental/time-budgeted searches are the next
  option if future telemetry shows material render stalls on heavier maps.
- Special admin modes BladeBall, CrossyRoad, DonkeyKong, and FFACatchers still
  pause the normal crossing controller; they need separate game strategies.
- The speed default stays 1.05x. Earlier speed trials remain documented
  separately; this audit does not establish undetectability or future stability
  of client speed changes. Forced ability motion retains native controllers.

The UI uses the game's own LightsOutKeep exemption.
