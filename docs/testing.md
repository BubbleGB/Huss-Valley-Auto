# Current offline audit

The [final offline audit](final-offline-audit.md) records the new regressions, fixes and validation limits. The [live checklist](final-audit-live-checklist.md) preserves engine-dependent checks for the next MCP session.

With the official Luau CLI and compiler available:

```sh
python3 tools/test_offline.py --luau /path/to/luau --compiler /path/to/luau-compile --report /tmp/huss-offline-results.json
```

This runs an explicit subset of detached fixtures plus offline regressions. The mathematical substitutes do not replace native engine, physics, input or JSON/filesystem validation. The command exits nonzero on fixture or compilation failure. `main.lua` and `runtime/start.lua` compile through the assembled executable because they are complementary lexical fragments.

# Testing

The camera/Dashboard/reward followup passed **15 focused Roblox fixtures and 17
Python tests**. Coverage includes native-shaped four-credit spin draining,
confirmed ballot collapse without reopening, prompt overlay preparation, shared
window ownership, camera yaw/zoom/pitch guards, metric units and unavailable
values, actual WindUI Dashboard placement, startup rollback, profiles and input.

[Latest results](../archive/results/2026-11-02/camera-dashboard-tests.json) ·
[Previous full audit: 53 selected fixtures / 477 Core checks](../archive/results/2026-11-02/full-audit-tests.json)

There are 61 registered native fixtures. Physical window-drag tests inject real touch
and are deliberately excluded from focused runs during active matches. Detached
fixtures do not synthesize desktop input or spend real rewards. Native-shaped
regressions establish sequencing and guards; they do not establish catch rates,
FPS improvement, or every live reward outcome.

## Build checks

```sh
python3 tools/build.py
python3 tools/build.py --check
python3 -m unittest discover -s tools
```

The builder validates the ordered source manifest, comment-free production Lua,
fixture registration, deterministic compaction, source maps and artifact hashes.
Python checks do not substitute for native Luau/game tests.

## Native suite

Use [the self-contained bundle](../dist/huss-test-suite.txt), which fetches the
current GitHub executable. [tests/runner.lua](../tests/runner.lua) also accepts an
executable string and a table mapping registered fixture names to source strings.
See the [fixture index](../tests/README.md) and [manifest](../tests/manifest.json).

Always use the preserving runner for destructive controller/UI fixtures. It
suspends preference writes, restores the live profile and running state and
preserves corrupt-file protection. The WindUI fixture blocks unsafe standalone
execution. Do not run the physical drag fixture during gameplay that changes the
camera or character pose. Older dated results remain in [the archive](../archive/README.md).
