# Testing

The latest full run on 2026-11-02 passed **46 Roblox suites, 479 Core decision checks and 16 Python tests**, with no failures. The full report is [archived here](../archive/results/2026-11-02/collection-forward-tests.json).

The fixtures cover settings validation, real WindUI controls/profiles/minimization, exact owned-connection cleanup, five startup fault boundaries, all 21 speed values, movement and combat policies, geometry, traps, role/vote policies, optional detours and AFK ownership. Obsolete native-panel slider/fallback fixtures were removed; active coverage moved to the speed, WindUI and touch fixtures. Camera ownership adds 26 isolated assertions; touch-only anti-AFK adds 26.

Actual title drag and slider Begin/Move/End use touch events, with hit-target checks and camera/body drift guards. No synthetic keyboard or mouse events are used. Inspection uses a detached camera. Geometry and action fixtures use isolated models/remotes rather than moving the live character to test combat.

The runner restores settings, running state, feature choices and window placement. For the latest run it restored the prior running state. Test-only startup suppression prevents preference file writes and automatic startup inside fixtures. Blackout was inactive; its ownership/exemption setup was verified. Live win-rate improvements and a full 20-minute idle-kick interval remain unmeasured.

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
