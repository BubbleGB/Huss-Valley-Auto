# Huss Valley Auto Play

Automatic runner crossing and chaser pursuit, with a draggable control panel.

**[Get the script](https://raw.githubusercontent.com/BubbleGB/Huss-Valley-Auto/main/dist/huss-auto-cross.txt)** · **[Usage guide](docs/usage.md)** · **[Tests](tests/README.md)**

## Run

Download [huss-auto-cross.txt](dist/huss-auto-cross.txt) into your Delta workspace
and execute it in the game. The panel starts paused; press **Start**.
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

Latest game-runtime verification: **25 suites passed, 332 decision checks**.
Historical reports live in the archive. This is the automation project, not the
game's server source or a Roblox place export.
