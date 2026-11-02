# Huss Valley Auto Play

## [Open the executable .lua script](src/auto-play.lua)

**[Get raw .lua — copy or save](https://raw.githubusercontent.com/BubbleGB/Huss-Valley-Auto/main/src/auto-play.lua)** · [Delta .txt version](dist/huss-auto-cross.txt)

This is the executable entry point. Run it with the loadstring below; new versions are published here on GitHub.

Automatic runner crossing and chaser pursuit, with a categorized WindUI window, touch/mouse dragging and a minimized control badge.

[Usage guide](docs/usage.md) · [Tests](tests/README.md)

## Run

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/BubbleGB/Huss-Valley-Auto/main/src/auto-play.lua"))()
```

The [standalone .lua](src/auto-play.lua) and optional [Delta .txt mirror](dist/huss-auto-cross.txt)
contain the same automation executable. The categorized interface separately loads pinned WindUI 1.6.66 and caches its source in memory; initialization failures clean up and report the error. There is no legacy panel or fallback interface.
Settings load automatically for your account. A fresh configuration starts running; **Dashboard → Stop everything** pauses every automated action when enabled. Its saved state is restored on re-execution. The minus button minimizes to a draggable square labeled **Huss / Valley**; tap it or press **Right Shift** to restore. **X** unloads.

[UI and settings guide](docs/ui-settings.md) · [Gems and revives](docs/gems-revives.md)

## Find what you need

| Folder | Contents |
| --- | --- |
| [`dist/`](dist/) | Ready-to-use script and self-contained test bundle |
| [`src/`](src/README.md) | Source index, focused editable units and generated executable |
| [`tests/`](tests/) | Core and runtime fixtures, runner and test index |
| [`docs/`](docs/) | Usage, testing and development guides |
| [`tools/`](tools/) | Distribution build command |
| [`archive/`](archive/) | Dated reports, results and implementation history |

## Development

Edit the [focused source units](src/README.md) through [src/main.lua](src/main.lua), then build the standalone executable:

```sh
python3 tools/build.py
python3 tools/build.py --check
python3 -m unittest discover -s tools
```

[Development guide](docs/development.md) · [How to run tests](docs/testing.md)

Latest verification is recorded in [Testing](docs/testing.md), including real touch controls, startup rollback and camera ownership checks.
Historical reports live in the archive. This is the automation project, not the
game's server source or a Roblox place export.

## Pumpkin Hunt

Pumpkin Hunt is detected automatically. While participating, the script seeks pumpkin people, keeps baiting distance, sidesteps telegraphed lunges, and uses native runner dash only along a checked path. It widens spacing on the last life and stops when eliminated or when all pumpkins are gone. Normal crossing/chasing resumes after the event.

No coin donations or reward opening are automated. Smart Speed bursts, player combat, gear use, and TP Assist are suspended during Pumpkin Hunt. The regular speed slider still applies.

Pumpkin Hunt update verified on 2026-10-29: all 27 suites passed, including isolated event planning, fresh lunge reactions, obstacle detours and NPC cleanup. The event had ended before development; live hunt survival and reward performance remain unverified.

Halloween candy corn is collected automatically through safe runner detours, independently of the Gems toggle. Pumpkin Hunt heads are already credited natively when enemies break; restricted-mode coin rewards use the same event. The script does not chase cosmetic reward animations or invent coin pickups.
