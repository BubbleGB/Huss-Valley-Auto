# Optional live inspection

Enable the overlay in WindUI's Diagnostics category, or call `getgenv().HussAutoCross:SetInspectionEnabled(true)`. It defaults off. The category shows cached planner, threat, timing and crossing details. The old Info card and side panel have been removed.

While automation runs with fresh planner data, green lines show up to eight route segments and a goal label. Orange labels identify up to four nearest cached threats or runner candidates; short lines forecast 0.35 seconds of movement. These are estimates, not authoritative hitboxes. Offscreen and stale markers are hidden.

The overlay reuses cached planning data at five updates per second. It adds no world scans, raycasts, network requests or physics parts. Stop and snapshots older than 0.25 seconds hide markers. Disabling inspection hides the overlay; Destroy removes all owned GUI and connections. InspectionError records display errors without stopping movement.

The projection fixture uses a detached camera and never replaces the live camera. The current full verification is recorded in [Testing](testing.md).
