# Testing

## Run the game tests

Copy both files from [dist/](../dist/) into the Delta workspace:

1. [huss-auto-cross.txt](../dist/huss-auto-cross.txt)
2. [huss-test-suite.txt](../dist/huss-test-suite.txt)

Execute [huss-test-suite.txt](../dist/huss-test-suite.txt) while connected to the compatible Roblox game.
The runner reports each suite, then restores running state, speed, Smart Speed,
TP Assist and panel position. These tests require Roblox's native modules and
executor APIs; a desktop Lua interpreter cannot run them.

The latest verified game run passed **30 suites and 394 Core decision checks**,
plus runtime assertions. Dated [archived results](../archive/results/) retain
their original counts and may describe older script versions.

## Check generated files locally

```sh
python3 tools/build.py --check
```

This verifies the source mirror, fixture registration, embedded test bundle and
distribution checksums. It does not execute Roblox gameplay tests.

See the [test index](../tests/README.md) for individual fixtures.

Pumpkin Hunt update verified on 2026-10-29: all 27 suites passed, including isolated event planning, fresh lunge reactions, obstacle detours and NPC cleanup. The event had ended before development; live hunt survival and reward performance remain unverified.

Run `python3 tools/test_build.py` for the 7 Python build-contract tests. Ten assertions for unused legacy helpers were retired; targeting/intercept checks now exercise the active policies, and three checks cover exact arrival-time cost caching.
