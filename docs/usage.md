# Usage

Run the [executable Lua](../src/auto-play.lua) through the repository loadstring:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/BubbleGB/Huss-Valley-Auto/main/src/auto-play.lua"))()
```

Core runner/chaser play starts running unless a saved profile stops it. Optional
features default off. **Dashboard → Stop everything** pauses automated actions.
Use the top-bar minus to minimize, the Huss / Valley square to restore, and X to
unload. See the [UI guide](ui-settings.md) for every category and profile controls.

## Crossing and chasing

Runners plan routes around detected chasers, obstacles and traps. Round time,
current speed profiles, urgency and available defenses influence route choices.
Safe direct crossings avoid unnecessary searching. Dash requires a checked travel
path. Gems/currency detours progress forward; passed pickups are abandoned.
Revives use native timing and are governed by their toggle and priority.

Chasers hold a catchable target until it becomes invalid or another is materially
closer. Selection considers close catches, invisible runners, nearby clusters and
interception cost. Interception uses observed motion and current speed profiles.
Melee remains automatic; dives require predicted native swept contact and a clear
travel path. Prediction does not guarantee a catch against changing input, latency
or unobserved effects. Native forced motion is allowed to finish.

**Play → Target Facing** aligns body and camera yaw with the hunted runner or
current movement direction. It preserves zoom, pitch and the default camera
controller, yielding to native cinematic/menu/spectator states. Disable it or
stop automation to release steering.

Equipment lists owned runner/chaser abilities and consumables. Selecting an owned
item equips it through native Armory controls in the lobby. Ability/consumable
usage respects native restrictions and cooldowns; consumables may spend charges.

## Prompts and collection

Voting follows the configured named map if offered, otherwise an offered map is
chosen randomly. Hero/Chicken follows the selected mode and chaser threshold.
The lead chaser can automatically select an eligible runner. Native touches
briefly minimize the script window to uncover controls. After a confirmed vote,
the expanded ballot collapses and stays collapsed; its small native reminder can
remain until voting ends.

Collection features use normal native controls. Physical stations are approached
by walking/pathfinding and in-range touch prompts. Wheel Spin uses x10/x5 when
available, then spends remaining credits through smaller spins before closing.
Quests and Journey claim earned rewards. Crates uses free allocations. Ghost
Trader spends owned Ghost Keys through its native card flow. Purchases, paid
skips, rerolls and paid progression are excluded. Unrelated menus, typing,
missing controls, Stop and round changes defer collection work.

Pumpkin Hunt is detected automatically and uses event-specific bait/dodge play.
Native events credit broken pumpkin heads and restricted-mode coin rewards;
cosmetic reward animations are not chased. Smart Speed, player combat, gear and
TP Assist are suspended during that event. Unsupported special modes pause
ordinary crossing/chasing behavior.

## Dashboard and performance

Dashboard separates user/server totals, current operation and client performance.
Ping, Roblox memory, CPU/GPU render times and traffic come from native readings
when available; these are not device utilization percentages or temperature
readings. Performance contains reversible visual hiding options. Those preserve
physics and detection data, and Stop restores managed visuals.

Movement retains the speed, Smart Speed and TP Assist controls. The server remains
authoritative: prediction and local movement changes can be corrected or rejected.
Runtime reports describe observations, not guaranteed hitboxes, reward outcomes
or future safety. [Testing and current limits](testing.md) records what was checked.
