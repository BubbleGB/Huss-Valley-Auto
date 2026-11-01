# Optional live inspection

Press **Info** beside X, or call `getgenv().HussAutoCross:SetInspectionEnabled(true)`. It defaults off. It adds a compact side panel showing route status, latest planning reason/cost, reactive update count, round time, current dash decision and crossing results.

When the script is running with fresh planner data, green lines show up to eight route segments and a goal label. Orange labels identify up to four nearest cached threats (or runner candidates while chasing); short orange lines forecast 0.35 seconds of movement. Forecasts use the existing finite-motion model. They are estimates, not authoritative game hitboxes. Markers outside the camera view are hidden; segments are hidden when either endpoint is offscreen.

The display reuses cached planning data at five updates per second. It adds no world scans, raycasts, network requests, physics parts or external drawing dependencies. Stop/waiting states hide world markers immediately; snapshots older than 0.25 seconds are hidden. Turning Info off hides the card and overlay. Destroy removes all GUI objects and the existing heartbeat connection. Display errors are recorded in `InspectionError` and do not stop movement.

## Comparison notes

The authenticated TITANIC HUB interface was inspected through MCP using normal runtime access. Only public feature descriptions and UI were observed; its Luraph-protected source was not recovered, modified or copied. Its feature labels advertise automatic running/chasing, speed scaling, threat prediction, automatic combat, camera following, revive/gem detours, rewards, saved settings and debug/goal/threat visuals.

This release independently implements the diagnostic/visual ideas. Existing movement/combat policies are retained. There is no measured evidence that TITANIC movement is better. Revive/gem detours can compete with completing a crossing, so they were not added in this pass. Reward spinning/claiming and saved config behavior are also unchanged.

Verified: 34 Roblox suites, 415 Core decision checks, 16 Python tests, compile/build checks and independent code review. Live crossing success improvements are not established by these UI additions.
