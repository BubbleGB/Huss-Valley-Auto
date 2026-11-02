# Source index

Edit [main.lua](main.lua) and the focused units below. [auto-play.lua](auto-play.lua) is the generated executable used by the loadstring. Build with `python3 tools/build.py` from the repository root.

Units share one lexical scope and compile into one automation file. The categorized UI separately loads pinned WindUI 1.6.66; original source and license are in vendor. There is no legacy panel or fallback backend.

## Decision policies

| Source unit | Lines |
| --- | --- |
| [core/abilities.lua](core/abilities.lua) | 139 |
| [core/combat.lua](core/combat.lua) | 167 |
| [core/detours.lua](core/detours.lua) | 52 |
| [core/hazards.lua](core/hazards.lua) | 39 |
| [core/intercept.lua](core/intercept.lua) | 30 |
| [core/motion.lua](core/motion.lua) | 44 |
| [core/participants.lua](core/participants.lua) | 80 |
| [core/profiles.lua](core/profiles.lua) | 14 |
| [core/prompts.lua](core/prompts.lua) | 41 |
| [core/pumpkin.lua](core/pumpkin.lua) | 63 |
| [core/reactions.lua](core/reactions.lua) | 62 |
| [core/routing.lua](core/routing.lua) | 188 |
| [core/runner.lua](core/runner.lua) | 156 |
| [core/settings.lua](core/settings.lua) | 38 |
| [core/speed.lua](core/speed.lua) | 31 |
| [core/strategy.lua](core/strategy.lua) | 30 |
| [core/threats.lua](core/threats.lua) | 147 |
| [core/tp.lua](core/tp.lua) | 36 |

## Game integration

| Source unit | Lines |
| --- | --- |
| [runtime/abilities.lua](runtime/abilities.lua) | 122 |
| [runtime/actions.lua](runtime/actions.lua) | 113 |
| [runtime/actors.lua](runtime/actors.lua) | 36 |
| [runtime/anti-afk.lua](runtime/anti-afk.lua) | 143 |
| [runtime/combat.lua](runtime/combat.lua) | 124 |
| [runtime/detours.lua](runtime/detours.lua) | 132 |
| [runtime/events.lua](runtime/events.lua) | 86 |
| [runtime/inspection.lua](runtime/inspection.lua) | 91 |
| [runtime/lifecycle.lua](runtime/lifecycle.lua) | 89 |
| [runtime/loop.lua](runtime/loop.lua) | 136 |
| [runtime/movement.lua](runtime/movement.lua) | 24 |
| [runtime/participant-state.lua](runtime/participant-state.lua) | 57 |
| [runtime/planner.lua](runtime/planner.lua) | 297 |
| [runtime/prompts.lua](runtime/prompts.lua) | 62 |
| [runtime/pumpkin.lua](runtime/pumpkin.lua) | 21 |
| [runtime/routing.lua](runtime/routing.lua) | 77 |
| [runtime/sensing.lua](runtime/sensing.lua) | 63 |
| [runtime/settings.lua](runtime/settings.lua) | 31 |
| [runtime/timing.lua](runtime/timing.lua) | 46 |
| [runtime/tp-assist.lua](runtime/tp-assist.lua) | 98 |
| [runtime/tp-geometry.lua](runtime/tp-geometry.lua) | 110 |
| [runtime/ui.lua](runtime/ui.lua) | 50 |
| [runtime/wind-compat.lua](runtime/wind-compat.lua) | 70 |
| [runtime/wind-ui.lua](runtime/wind-ui.lua) | 296 |

Account settings persistence: [runtime/preferences.lua](runtime/preferences.lua). Reward/equipment requests: [runtime/progression.lua](runtime/progression.lua). Ownership, reward eligibility and consumable policy: [core/progression.lua](core/progression.lua).
