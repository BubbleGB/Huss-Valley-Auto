# Tests

[Run the full suite](../docs/testing.md) · [Runner](runner.lua) · [Fixture manifest](manifest.json)

The 61 registered native fixtures include 18 Core suites and 43 runtime suites. Actual injected input is touch only; camera and player pose are guarded during UI interaction.

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
| [progression.spec.lua](core/progression.spec.lua) |
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
| [client-metrics.spec.lua](runtime/client-metrics.spec.lua) |
| [collection.spec.lua](runtime/collection.spec.lua) |
| [consumables.spec.lua](runtime/consumables.spec.lua) |
| [crossing.spec.lua](runtime/crossing.spec.lua) |
| [detours.spec.lua](runtime/detours.spec.lua) |
| [dive.spec.lua](runtime/dive.spec.lua) |
| [facing-camera.spec.lua](runtime/facing-camera.spec.lua) |
| [facing.spec.lua](runtime/facing.spec.lua) |
| [fallen-king.spec.lua](runtime/fallen-king.spec.lua) |
| [input.spec.lua](runtime/input.spec.lua) |
| [inspection.spec.lua](runtime/inspection.spec.lua) |
| [lobby-input.spec.lua](runtime/lobby-input.spec.lua) |
| [lobby-navigation.spec.lua](runtime/lobby-navigation.spec.lua) |
| [lobby-ui.spec.lua](runtime/lobby-ui.spec.lua) |
| [lobby-workflow.spec.lua](runtime/lobby-workflow.spec.lua) |
| [operation.spec.lua](runtime/operation.spec.lua) |
| [performance.spec.lua](runtime/performance.spec.lua) |
| [preferences.spec.lua](runtime/preferences.spec.lua) |
| [progression.spec.lua](runtime/progression.spec.lua) |
| [prompt-inputs.spec.lua](runtime/prompt-inputs.spec.lua) |
| [prompt.spec.lua](runtime/prompt.spec.lua) |
| [pumpkin.spec.lua](runtime/pumpkin.spec.lua) |
| [reactions.spec.lua](runtime/reactions.spec.lua) |
| [server-status.spec.lua](runtime/server-status.spec.lua) |
| [settings-api.spec.lua](runtime/settings-api.spec.lua) |
| [smart.spec.lua](runtime/smart.spec.lua) |
| [speed.spec.lua](runtime/speed.spec.lua) |
| [startup.spec.lua](runtime/startup.spec.lua) |
| [terrain-geometry.spec.lua](runtime/terrain-geometry.spec.lua) |
| [threats.spec.lua](runtime/threats.spec.lua) |
| [tp.spec.lua](runtime/tp.spec.lua) |
| [ui-obstructions.spec.lua](runtime/ui-obstructions.spec.lua) |
| [user-status.spec.lua](runtime/user-status.spec.lua) |
| [visual-performance.spec.lua](runtime/visual-performance.spec.lua) |
| [wind-input.spec.lua](runtime/wind-input.spec.lua) |
| [wind-ui.spec.lua](runtime/wind-ui.spec.lua) |
| [window-lease.spec.lua](runtime/window-lease.spec.lua) |

Legacy panel slider and fallback tests were removed. Speed API coverage lives in speed.spec.lua; current widget lifecycle and actual touch routing live in wind-ui.spec.lua and wind-input.spec.lua. The frozen numeric performance oracle and geometry/action fixtures remain.

Progression: [policies](core/progression.spec.lua), [native service fixture](runtime/progression.spec.lua), and [isolated preferences storage](runtime/preferences.spec.lua).

Dashboard status: [isolated runtime snapshot/cache/format tests](runtime/server-status.spec.lua), plus actual paragraph rendering in the WindUI fixture.

Dashboard user card: [native-shaped stats/cache/identity tests](runtime/user-status.spec.lua), with actual card/username/circular avatar assertions in the WindUI fixture.

Forward-only collection: [detour policy](core/detours.spec.lua) and [actual planner/final guard with detached geometry](runtime/collection.spec.lua), including reversed crossing direction, passed/hidden/disabled/blocked pickups and backoff. WindUI checks verify Collection/Equipment control placement.

Operation status: [bounded state/priority/expiry/correlation tests](runtime/operation.spec.lua); progression fixtures verify pending/result labels; threat fixtures verify named evasion and actual trap/clearance causes; WindUI verifies the visible title and stopped state.

New fixtures: [reversible visuals](runtime/visual-performance.spec.lua), [native prompts and dismissal](runtime/prompt-inputs.spec.lua), [movement and target facing](runtime/facing.spec.lua).

Current followup: [camera alignment](runtime/facing-camera.spec.lua), [client metrics](runtime/client-metrics.spec.lua), [shared window ownership](runtime/window-lease.spec.lua).

Offline development: [runner](../tools/test_offline.py), [limited math substitutes](offline/math.lua), and [validation scope](../docs/final-offline-audit.md). Additional offline regressions are not included in the game bundle.
