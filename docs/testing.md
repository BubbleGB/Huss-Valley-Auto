# Testing

The Operation status cleanup passed the actual WindUI fixture plus Operation/User/Server status fixtures and 16 Python tests. Exact text checks cover Stopped, named chasing, currency collection, trap avoidance, batch spinning and a blocking reason, without duplicate stats or planner diagnostics. [Focused report](../archive/results/2026-11-02/operation-status-trim-tests.json). No physical input was injected for this cleanup.

The preceding full run on 2026-11-02 passed **47 of 48 Roblox suites, 494 Core decision checks and 16 Python tests**. The remaining touch fixture aborted on its camera-drift guard twice; further touch attempts were stopped. New batch-specific tests passed. The full report is [archived here](../archive/results/2026-11-02/batch-rewards-tests.json).

The fixtures cover settings validation, real WindUI controls/profiles/minimization, exact owned-connection cleanup, five startup fault boundaries, all 21 speed values, movement and combat policies, geometry, traps, role/vote policies, optional detours and AFK ownership. Obsolete native-panel slider/fallback fixtures were removed; active coverage moved to the speed, WindUI and touch fixtures. Camera ownership adds 27 isolated assertions; touch-only anti-AFK adds 26.

Actual title drag and slider Begin/Move/End use touch events, with hit-target checks and camera/body drift guards. No synthetic keyboard or mouse events are used. Inspection uses a detached camera. Geometry and action fixtures use isolated models/remotes rather than moving the live character to test combat.

The runner restores settings, running state, feature choices and window placement. For the latest run it restored the previous enabled state and feature selections. Test-only startup suppression prevents preference file writes, automatic startup, live movement planning and native role prompt sends inside fixtures. Blackout was inactive; its ownership/exemption setup was verified. Live win-rate improvements and a full 20-minute idle-kick interval remain unmeasured.

The layout release also checks all-off defaults, retired-control migration, version 2 account identity, JSON import/export, a real reset confirmation dialog, and isolated storage policy/reset failure handling. Ghost Trader has 70 isolated assertions plus progression integration checks for request serialization and stop/round invalidation. No real Ghost Keys were spent. The latest unrelated touch fixture aborted on detected camera motion; the guard was retained. The preceding layout release had passed this fixture.

Batch reward verification adds affordable x10/x5/single selection, invalid/empty balance rejection, exact native dispatch arguments, batch status/confirmation, hold and Stop guards. The progression fixture has 77 isolated assertions; the core progression fixture has 31. Native clients were inspected read-only: Spin supports x5/x10; free crates use one token per opening, while native crate batch buttons prompt paid purchases. Journey already sends the native ClaimAll command. Tests spend no real spin credits or crate allocations.

## Run the Roblox suite

The self-contained [test bundle](../dist/huss-test-suite.txt) embeds the current executable and registered fixtures. Execute it in a compatible connected client. It requires native Roblox modules and executor APIs; it is not a desktop Lua test. Development validation uses MCP without writing executable versions to the user's Delta workspace.

[runner.lua](../tests/runner.lua) also accepts the executable source and a filename-to-fixture-source table. See the [fixture index](../tests/README.md).

## Local generated-file checks

```sh
python3 tools/build.py
python3 tools/build.py --check
python3 -m unittest discover -s tools
```

These verify fixture registration, compact output, source maps, mirrors and distribution checksums. They do not run gameplay tests. Dated older reports retain their original results.

New progression fixtures verify role-filtered ownership, depleted inventory, Journey entitlement, fresh crate tokens, available spin credits, native equip confirmation and stop gating against isolated remotes. Preferences fixtures use isolated storage to check automatic saving/loading, persisted stop state, corrupt or unreadable files, and write failures. Important review findings for equip toggle retries and settings read failures were reproduced RED, fixed and verified GREEN before the full run.

Live read-only native snapshots confirmed Journey tier/season, available spin credits, crate allocation state and inventory. No earned rewards or consumable charges were spent to validate tests; successful rewarded crate/spin outcomes were tested with isolated native-shaped replies.

Seasonal pickup update: seven additional Core checks cover automatic candy with gems off, seasonal disablement, unchanged gems, urgency, geometry, threats and deadline vetoes. Runtime checks cover visible/hidden/collected native-shaped candy and actual absence of duplicate Dashboard actions. The final43-suite run passed without camera/input safeguard changes.

Dashboard status: isolated factory tests verify humans/bots and role filtering, deduplication, pause-independent script runtime, truthful server-uptime lower bound, one-second caching, report isolation and long duration formatting. The actual WindUI fixture verifies the status paragraph is rendered. Final full run44/44 suites,471Corechecks,16Python tests.

User card: isolated native-shaped leaderstats tests cover identity, role mapping, changed values, late/unloaded statistics, attribute fallback, cached copy isolation and the current-user headshot URI. Actual WindUI checks verify the user card, @username and circular headshot. Full45/45native suites and16Python tests passed.

Collection update: Core tests reject behind/passed/past-finish pickups and check axis direction. A detached native planner/guard fixture verifies forward-only route/action geometry, immediate cancellation before reverse movement, collected/disabled/blocked targets, retry backoff, and the opposite crossing direction. WindUI checks verify Collection and Equipment placement. The native FallenKing introduction temporarily disabled script screens during the first run; the touch test aborted before input. After visibility returned, the complete46-suite rerun passed with all safeguards unchanged.

Operation status: bounded channel priority, stopped override, expiry, report isolation, named combat and older/previous-session reply rejection pass. Native-shaped progression tests distinguish pending/confirmed equipment, spin State results and crate Result ids, including rejection of unloaded/malformed confirmations. Actual fresh-threat fixtures verify named evasion and truthful obstacle/trap labels. Full final47/47suites,479Corechecks and16Python tests passed. Read-only review found no important issues; native message shapes were checked against SpinWheelClient and CrateClient without spending live rewards.
