# Development

## Edit

- Main script: [src/auto-play.lua](../src/auto-play.lua).
- Core fixtures: [tests/core/](../tests/core/).
- Roblox runtime fixtures: [tests/runtime/](../tests/runtime/).
- Suite runner: [tests/runner.lua](../tests/runner.lua).
- Fixture registration: [tests/manifest.json](../tests/manifest.json).

The main script is intentionally standalone so it can be executed directly.
Keep changes in the source and rebuild the delivery files afterward.

## Build

Python 3.9 or newer is sufficient; no packages need installing.

```sh
python3 tools/build.py
python3 tools/build.py --check
```

The build writes the main script mirror, self-contained test bundle and
checksums into [dist/](../dist/). Test names in the runner are stable identifiers;
the manifest maps each identifier to its organised fixture path. New fixtures
must be registered in both places. Unregistered or duplicate fixtures fail the build.

## Verify

Run the [Roblox suite](testing.md) after behavior changes. Distribution checks
alone do not validate movement, abilities or UI interaction in the live game.
Keep historical evidence under [archive/](../archive/README.md).
