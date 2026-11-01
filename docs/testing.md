# Testing

The latest full run on 2026-11-01 passed **40 Roblox suites, 446 Core decision checks and 16 Python tests**, with no failures. The full report is [archived here](../archive/results/2026-11-01/ui-settings-tests.json).

The fixtures cover settings validation, real WindUI controls/profiles/minimization, exact owned-connection cleanup, five startup fault boundaries, all 21 speed values, movement and combat policies, geometry, traps, role/vote policies, optional detours and AFK ownership. Obsolete native-panel slider/fallback fixtures were removed; active coverage moved to the speed, WindUI and touch fixtures. Camera ownership adds 26 isolated assertions; touch-only anti-AFK adds 26.

Actual title drag and slider Begin/Move/End use touch events, with hit-target checks and camera/body drift guards. No synthetic keyboard or mouse events are used. Inspection uses a detached camera. Geometry and action fixtures use isolated models/remotes rather than moving the live character to test combat.

The runner restores settings, running state, feature choices and window placement. For the latest run it restored automation paused. Blackout was inactive; its ownership/exemption setup was verified. Live win-rate improvements and a full 20-minute idle-kick interval remain unmeasured.

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
