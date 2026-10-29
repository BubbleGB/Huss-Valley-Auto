# Source index

Edit [main.lua](main.lua) and the units below. [auto-play.lua](auto-play.lua) is the generated executable used by the loadstring. Build with `python3 tools/build.py` from the repository root.

The includes share one lexical scope and compile into one file. Each unit has a focused responsibility; there are no runtime module downloads.

## Decision policies

| Source unit | Lines |
| --- | --- |
| [core/abilities.lua](core/abilities.lua) | 139 |
| [core/combat.lua](core/combat.lua) | 167 |
| [core/hazards.lua](core/hazards.lua) | 39 |
| [core/intercept.lua](core/intercept.lua) | 30 |
| [core/motion.lua](core/motion.lua) | 44 |
| [core/participants.lua](core/participants.lua) | 80 |
| [core/profiles.lua](core/profiles.lua) | 14 |
| [core/prompts.lua](core/prompts.lua) | 38 |
| [core/pumpkin.lua](core/pumpkin.lua) | 63 |
| [core/routing.lua](core/routing.lua) | 188 |
| [core/runner.lua](core/runner.lua) | 156 |
| [core/speed.lua](core/speed.lua) | 31 |
| [core/strategy.lua](core/strategy.lua) | 30 |
| [core/threats.lua](core/threats.lua) | 147 |
| [core/tp.lua](core/tp.lua) | 36 |

## Game integration

| Source unit | Lines |
| --- | --- |
| [runtime/abilities.lua](runtime/abilities.lua) | 125 |
| [runtime/actions.lua](runtime/actions.lua) | 106 |
| [runtime/actors.lua](runtime/actors.lua) | 36 |
| [runtime/anti-afk.lua](runtime/anti-afk.lua) | 152 |
| [runtime/combat.lua](runtime/combat.lua) | 105 |
| [runtime/events.lua](runtime/events.lua) | 115 |
| [runtime/lifecycle.lua](runtime/lifecycle.lua) | 60 |
| [runtime/loop.lua](runtime/loop.lua) | 127 |
| [runtime/movement.lua](runtime/movement.lua) | 20 |
| [runtime/participant-state.lua](runtime/participant-state.lua) | 57 |
| [runtime/planner.lua](runtime/planner.lua) | 286 |
| [runtime/prompts.lua](runtime/prompts.lua) | 61 |
| [runtime/pumpkin.lua](runtime/pumpkin.lua) | 21 |
| [runtime/routing.lua](runtime/routing.lua) | 77 |
| [runtime/sensing.lua](runtime/sensing.lua) | 63 |
| [runtime/timing.lua](runtime/timing.lua) | 46 |
| [runtime/tp-assist.lua](runtime/tp-assist.lua) | 98 |
| [runtime/tp-geometry.lua](runtime/tp-geometry.lua) | 110 |
| [runtime/ui.lua](runtime/ui.lua) | 139 |

