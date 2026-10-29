# Huss Valley Auto Play

## [Open the executable .lua script](src/auto-play.lua)

**[Get raw .lua — copy or save](https://raw.githubusercontent.com/BubbleGB/Huss-Valley-Auto/main/src/auto-play.lua)** · [Delta .txt version](dist/huss-auto-cross.txt)

This is the complete, standalone script. Open it and copy the contents into your
executor, or save it as `auto-play.lua` and execute it.

Automatic runner crossing and chaser pursuit, with a draggable control panel.

[Usage guide](docs/usage.md) · [Tests](tests/README.md)

## Run

Execute [auto-play.lua](src/auto-play.lua), or download the identical
[huss-auto-cross.txt](dist/huss-auto-cross.txt) into your Delta workspace.
The panel starts paused; press **Start**.
**Stop** pauses play, **X** unloads it, and the title bar is draggable.

## Find what you need

| Folder | Contents |
| --- | --- |
| [`dist/`](dist/) | Ready-to-use script and self-contained test bundle |
| [`src/`](src/) | Editable Lua source |
| [`tests/`](tests/) | Core and runtime fixtures, runner and test index |
| [`docs/`](docs/) | Usage, testing and development guides |
| [`tools/`](tools/) | Distribution build command |
| [`archive/`](archive/) | Dated reports, results and implementation history |

## Development

Edit [src/auto-play.lua](src/auto-play.lua), then rebuild the downloadable files:

```sh
python3 tools/build.py
python3 tools/build.py --check
```

[Development guide](docs/development.md) · [How to run tests](docs/testing.md)

Latest game-runtime verification: **27 suites passed, 352 decision checks**.
Historical reports live in the archive. This is the automation project, not the
game's server source or a Roblox place export.

## Pumpkin Hunt

Pumpkin Hunt is detected automatically. While participating, the script seeks pumpkin people, keeps baiting distance, sidesteps telegraphed lunges, and uses native runner dash only along a checked path. It widens spacing on the last life and stops when eliminated or when all pumpkins are gone. Normal crossing/chasing resumes after the event.

No coin donations or reward opening are automated. Smart Speed bursts, player combat, gear use, and TP Assist are suspended during Pumpkin Hunt. The regular speed slider still applies.

Pumpkin Hunt update verified on 2026-10-29: all 27 suites passed, including isolated event planning, fresh lunge reactions, obstacle detours and NPC cleanup. The event had ended before development; live hunt survival and reward performance remain unverified.
