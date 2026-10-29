# Tests

[Run the full suite](../docs/testing.md) · [Runner](runner.lua) · [Fixture manifest](manifest.json)

Core fixtures test decision policies. Runtime fixtures exercise Roblox modules,
UI, geometry and lifecycle behavior. The self-contained [Delta bundle](../dist/huss-test-suite.txt) includes both groups.

## Core policies

| Fixture | Coverage |
| --- | --- |
| [abilities.spec.lua](core/abilities.spec.lua) | Abilities |
| [action-policy.spec.lua](core/action-policy.spec.lua) | Action policy |
| [advanced.spec.lua](core/advanced.spec.lua) | Advanced |
| [audit.spec.lua](core/audit.spec.lua) | Audit |
| [auto-cross.spec.lua](core/auto-cross.spec.lua) | Auto cross |
| [dive.spec.lua](core/dive.spec.lua) | Dive |
| [routing.spec.lua](core/routing.spec.lua) | Routing |
| [smart-policy.spec.lua](core/smart-policy.spec.lua) | Smart policy |
| [speed.spec.lua](core/speed.spec.lua) | Speed |
| [strategy.spec.lua](core/strategy.spec.lua) | Strategy |
| [threats.spec.lua](core/threats.spec.lua) | Threats |
| [tp.spec.lua](core/tp.spec.lua) | Tp |

## Roblox runtime

| Fixture | Coverage |
| --- | --- |
| [action.spec.lua](runtime/action.spec.lua) | Action |
| [antiafk.spec.lua](runtime/antiafk.spec.lua) | Antiafk |
| [auto-cross.spec.lua](runtime/auto-cross.spec.lua) | Auto cross |
| [blackout.spec.lua](runtime/blackout.spec.lua) | Blackout |
| [dive.spec.lua](runtime/dive.spec.lua) | Dive |
| [input.spec.lua](runtime/input.spec.lua) | Input |
| [prompt.spec.lua](runtime/prompt.spec.lua) | Prompt |
| [smart.spec.lua](runtime/smart.spec.lua) | Smart |
| [speed-slider.spec.lua](runtime/speed-slider.spec.lua) | Speed slider |
| [speed.spec.lua](runtime/speed.spec.lua) | Speed |
| [startup.spec.lua](runtime/startup.spec.lua) | Startup |
| [threats.spec.lua](runtime/threats.spec.lua) | Threats |
| [tp.spec.lua](runtime/tp.spec.lua) | Tp |

