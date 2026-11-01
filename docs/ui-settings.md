# Categorized interface and settings

The default interface uses WindUI 1.6.66 with a dark teal theme. It starts paused, supports mouse/touch dragging, resizing and scrolling categories. Use the minus button to minimize without pausing. A draggable status badge restores the window and contains Start/Stop; Right Shift also toggles it. X unloads the controller and restores owned movement/input state.

| Category | Controls |
| --- | --- |
| Dashboard | Status, Start/Stop, minimize, unload, Save/Load/Reset settings |
| Runner | Runner automation, gem collection, revives, dash |
| Chaser | Chaser automation, predicted dive/melee, body facing, camera follow |
| Priorities | Four ordered task slots; choosing an existing task swaps slots |
| Voting & Roles | Auto vote, preferred map, current offered map names, Auto/Hero/Chicken, chaser threshold, automatic runner selection |
| Movement | Speed slider (1–2 by 0.05), Smart Speed and its learned cap, TP Assist and blocked status, equipped abilities, Anti-AFK |
| Diagnostics | Cached goal/threat forecasts, live route/timing/crossing details, print crossing report |

Map IDs are resolved against the live ballot. Selecting an unavailable map falls back to a randomly offered option; existing votes are respected. The dropdown includes known numeric Map IDs and expands when the ballot advertises newer ones. Current names appear below the preference. Auto Hero mode chooses Hero with at most the configured number of chasers (default 5), otherwise Chicken. Forced Hero/Chicken ignores the threshold.

Default priorities are Escape, Revives, Gems, Catches. Tasks apply to their native role: gems/revives while running, catches while chasing. Under clear conditions optional safe detours remain available even with Escape first. When pressure increases, Escape suppresses lower-ranked detours. Swapping Gems above Revives changes which safe optional goal is preferred. Immediate catch clearance, physical obstacles, traps and insufficient round time remain vetoes regardless of order. Runner/chaser role selection stays automatic.

All new settings are validated and exposed through `GetSettings()`, `SetSetting(name,value)` and `SetPriorities({'Escape','Revives','Gems','Catches'})`. Existing speed/Smart Speed/TP Assist/gem/revive/inspection methods remain supported. The window reflects API changes; rejected toggle changes revert to the actual state.

Save settings writes `HussValleyAutoUI/settings.json` only when clicked. It saves validated settings and existing feature choices, never the executable. Load applies it without starting automation; Reset restores defaults. Profiles exclude learned server correction state. No automatic profile load is performed.

WindUI is loaded from its explicit upstream release URL. The original source and MIT license are retained in vendor for auditing. A narrow compatibility adapter handles owned signal cleanup. The library source is cached in executor memory across reloads. All owned ScreenGuis are marked LightsOutKeep before parenting to PlayerGui. Download, compile or initialization failure removes partial UI, connections and the movement-profile wrapper before reporting an error. The old panel, fallback backend and backend selector have been removed.

Camera follow and continuous body facing both default off. They can be enabled separately in Chaser. A native dive requires a one-time aim rotation immediately before dispatch; a rejected dive restores rotation while preserving any intervening native position change. Melee and equipped gear receive explicit aim without rotating the character. Default-off TP Assist remains an explicit movement feature.

Synthetic input is touch only. Anti-AFK uses a stationary paired touch on an owned inert IDLE pad, with menu, typing, active-touch and obstruction checks. It defers when a safe pad hit cannot be established. It does not inject mouse or keyboard events. Physical mouse dragging and keyboard shortcuts remain available to the user. See [AFK behavior](afk-fix.md).

UI changes do not establish better live crossing/catch success rates. Verification details are in [Testing](testing.md).
