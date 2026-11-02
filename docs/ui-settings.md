# UI and settings

The categorized WindUI window is draggable. The top-bar minus minimizes it to a
draggable square labeled Huss / Valley. Tap the square or press Right Shift to
restore. The top-bar X unloads. Dashboard has no duplicate minimize/unload buttons.

| Category | Controls and information |
| --- | --- |
| Dashboard | User card; server status; operation status; client performance; Stop everything |
| Play | Revives, Dive, Dash and Target Facing; melee remains automatic |
| Priorities | Escape, Catches, Revives and Gems & Currency, in your chosen order |
| Voting & Roles | Map names/preference, random map, Hero/Chicken choice and chaser threshold |
| Movement | Speed, Smart Speed and TP Assist controls |
| Performance | Hide Particles, Hide Other Players and Hide Gems/Currency |
| Settings | Auto-save/load, Save, Load, Import, Export, confirmed Reset, markers and report |
| Collection | Gems, seasonal currency, Quests, Journey, Wheel Spin, Ghost Trader, Crates |
| Equipment | Owned runner/chaser abilities and consumables; Abilities and Consumables usage |

All optional toggles default off. Core play starts running; enabling Stop
everything pauses automated work. Reset asks for confirmation, turns every option
off and resumes core play. Existing profiles remain supported. Auto-save and
auto-load are opt-in; manual Save and Load remain available. Invalid/unreadable
profiles report errors rather than silently overwriting a recoverable file.

Target Facing aligns camera yaw before the game's native camera-facing update.
It preserves the existing zoom, pitch and focus, and leaves the normal camera
controller active. Menus, typing, spectating, cinematic cameras and native forced
motion take precedence. Turning Target Facing off or stopping removes steering.

Dashboard measurements include FPS/frame time, ping, Roblox memory, CPU/GPU render
time, traffic, instances/draw calls, planner time and managed visuals. Samples are
cached once per second. CPU/GPU values are render time in milliseconds, not whole
device utilization. Memory belongs to the Roblox process. Unsupported readings
show unavailable; device temperatures and CPU/GPU utilization percentages are not
invented. See [Roblox Stats](https://create.roblox.com/docs/reference/engine/classes/Stats)
and [network ping](https://create.roblox.com/docs/reference/engine/classes/Player#GetNetworkPing).

Performance options affect local rendering, preserving detection, collisions and
pickup data. Recognized gameplay warnings and the local avatar are protected.
Stop restores managed visuals. Original/latest observed native property values
are restored; same-value external assignments cannot be observed.

Collection/equipment uses one serial native workflow. It walks to physical
stations, touches visible prompts and controls, waits for native confirmation and
closes finished menus. Wheel Spin picks x10/x5 when available, then continues
smaller spins while credits remain. It never substitutes a purchase. Quest claims
use earned daily/event controls, excluding paid skips or refreshes. Ordinary world
coin pickups were not found; Pumpkin Hunt rewards are credited by native events.
Gems/currency detours only progress forward along a crossing.

Hero/Chicken and player selection temporarily minimize the script's own window
so it cannot cover native touch targets; other obstructions remain respected.
After a confirmed map vote, an expanded ballot is collapsed. Its collapsed
expand toggle is never repeatedly tapped. Native map voting may show a small
collapsed reminder until the vote ends.

Operation status shows running/stopped and the current named action or blocker.
Role/stat totals remain in user/server status. Server uptime is labeled as a lower
bound since joining because no authoritative start timestamp is exposed. LMS
means Last Man Standing, matching the native leaderboard.

Collection includes **Pumpkins** (off by default), which opens owned pumpkins through the native reveal. Free event crates use the accessible Halloween stand; only native allocations marked free are opened. Ghost Trader uses the post-reward tap-to-continue control. Runner selection uses the native Random button when available.

Pumpkin Hunt uses the native game-mode flag and faces the active pumpkin. Fallen King automation collects bombs and hearts, avoids known native warnings and fog, throws at the boss or active shrines, and uses melee against reachable shrines. Paid revival is never selected. Event outcomes depend on the live game and have not been verified end-to-end for every encounter.
