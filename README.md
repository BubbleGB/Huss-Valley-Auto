# Huss Valley Auto Play

Standalone Roblox client script, regression tests, development notes and audit
evidence for the Huss Valley automatic crossing and chasing project.

## Run

Execute `huss-auto-cross.lua` in the compatible game client, or use the identical
`huss-auto-cross.txt` Delta workspace copy. The panel starts paused and provides
Start, Stop, X, dragging, dynamic speed, Smart Speed and TP Assist controls.

See [the complete usage guide](huss-auto-cross-README.md) for behavior, settings,
cooldowns, cleanup and limitations. Every dive requires a native swept-contact
prediction and valid catch time; predictions do not guarantee a catch.

## Test

Tests run in the actual Roblox client and require its native modules and executor
APIs. They are not ordinary desktop Lua tests.

Place `huss-auto-cross.txt` and `huss-test-suite.txt` in the Delta workspace, then
execute the latter. The self-contained runner exercises the current script,
reports failures separately and restores running state, UI position and settings.
`huss-test-suite.lua` is the source runner; `huss-*.spec.lua` are its source fixtures.

Latest verified source/bundle: **25 suites passed, 332 Core decision checks,
zero failures**, plus runtime assertions. Older dated reports preserve their
original results and should be read as historical evidence.

## Project contents

- `huss-auto-cross.lua` — canonical standalone script.
- `huss-auto-cross.txt` — exact delivery mirror.
- `huss-test-suite.lua` / `.txt` — source and self-contained test runner.
- `huss-*.spec.lua` — routing, combat, abilities, UI, input and lifecycle tests.
- Dated Markdown/JSON files — audits, validation and live observations.
- `docs/superpowers/plans/` — implementation plans.
- `huss-speed-trial.lua` — historical speed-testing utility; normal use does not require it.
- `MANIFEST.sha256` — SHA-256 checksums for this upload snapshot.

This repository contains the automation project developed in this workspace.
It does not contain the game's server source or a Roblox place export.
