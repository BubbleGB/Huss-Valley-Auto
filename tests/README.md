# Tests

[Run the full suite](../docs/testing.md) · [Runner](runner.lua) · [Fixture manifest](manifest.json)

The 43 registered fixtures include 18 Core suites and 25 runtime suites. Actual injected input is touch only; camera and player pose are guarded during UI interaction.

## Core policies

| Fixture |
| --- |
| [abilities.spec.lua](core/abilities.spec.lua) |
| [action-policy.spec.lua](core/action-policy.spec.lua) |
| [advanced.spec.lua](core/advanced.spec.lua) |
| [audit.spec.lua](core/audit.spec.lua) |
| [auto-cross.spec.lua](core/auto-cross.spec.lua) |
| [crossing.spec.lua](core/crossing.spec.lua) |
| [detours.spec.lua](core/detours.spec.lua) |
| [dive.spec.lua](core/dive.spec.lua) |
| [pumpkin.spec.lua](core/pumpkin.spec.lua) |
| [reactions.spec.lua](core/reactions.spec.lua) |
| [routing.spec.lua](core/routing.spec.lua) |
| [settings.spec.lua](core/settings.spec.lua) |
| [smart-policy.spec.lua](core/smart-policy.spec.lua) |
| [speed.spec.lua](core/speed.spec.lua) |
| [strategy.spec.lua](core/strategy.spec.lua) |
| [threats.spec.lua](core/threats.spec.lua) |
| [tp.spec.lua](core/tp.spec.lua) |

## Roblox runtime

| Fixture |
| --- |
| [action.spec.lua](runtime/action.spec.lua) |
| [afk-reporter.spec.lua](runtime/afk-reporter.spec.lua) |
| [antiafk.spec.lua](runtime/antiafk.spec.lua) |
| [auto-cross.spec.lua](runtime/auto-cross.spec.lua) |
| [blackout.spec.lua](runtime/blackout.spec.lua) |
| [camera-ownership.spec.lua](runtime/camera-ownership.spec.lua) |
| [crossing.spec.lua](runtime/crossing.spec.lua) |
| [detours.spec.lua](runtime/detours.spec.lua) |
| [dive.spec.lua](runtime/dive.spec.lua) |
| [input.spec.lua](runtime/input.spec.lua) |
| [inspection.spec.lua](runtime/inspection.spec.lua) |
| [performance.spec.lua](runtime/performance.spec.lua) |
| [prompt.spec.lua](runtime/prompt.spec.lua) |
| [pumpkin.spec.lua](runtime/pumpkin.spec.lua) |
| [reactions.spec.lua](runtime/reactions.spec.lua) |
| [settings-api.spec.lua](runtime/settings-api.spec.lua) |
| [smart.spec.lua](runtime/smart.spec.lua) |
| [speed.spec.lua](runtime/speed.spec.lua) |
| [startup.spec.lua](runtime/startup.spec.lua) |
| [threats.spec.lua](runtime/threats.spec.lua) |
| [tp.spec.lua](runtime/tp.spec.lua) |
| [wind-input.spec.lua](runtime/wind-input.spec.lua) |
| [wind-ui.spec.lua](runtime/wind-ui.spec.lua) |

Legacy panel slider and fallback tests were removed. Speed API coverage lives in speed.spec.lua; current widget lifecycle and actual touch routing live in wind-ui.spec.lua and wind-input.spec.lua. The frozen numeric performance oracle and geometry/action fixtures remain.

Progression: [policies](core/progression.spec.lua), [native service fixture](runtime/progression.spec.lua), and [isolated preferences storage](runtime/preferences.spec.lua).
