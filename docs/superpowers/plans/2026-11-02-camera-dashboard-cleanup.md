# Camera alignment, Dashboard metrics and repository navigation

User authorized camera movement to make facing work, requested metrics on Dashboard, useful hardware/network stats and GitHub cleanup; then reported native Hero/Chicken touch selection failure. Standing request delegates routine implementation choices and direct GitHub publication.

Approach: preserve the native Custom camera and turn only its yaw around the existing focus before the native camera/body-facing render step. Keep current zoom, pitch and ordinary occlusion updates. Yield to native presentation cameras, spectator/menu/input states and forced character motion. Retain Target Facing toggle and body/action logic. Isolated camera tests plus native render-order evidence establish the conflict and regression coverage.

Move the existing metrics paragraph to Dashboard. Cache Stats/Player samples once per second: frame time/FPS, network ping, Roblox memory, CPU/GPU render time, traffic and scene counters where accessible. Unknown or unsupported metrics stay unavailable; do not invent utilization, hardware memory or temperatures. Performance tab keeps visual toggles only.

Investigate role touches using native hierarchy/callbacks and hit testing. Keep touch-only native controls, handle the script's own overlay without hiding unrelated menus, and confirm native selection before reporting success.

Clean active entry docs into a small navigation hub, archive superseded feature notes, update affected links and preserve executable/loadstring and historical evidence. Verify local link targets, manifest/build and relevant native tests before GitHub publication.

Additional steering: drain remaining wheel credits instead of stopping after one; never repeatedly toggle a collapsed ballot. Confirmed native close toggles expansion, and live hit tests show the own window over role buttons. Shared window minimization leases prevent prompt/progression overlap. Focused tests passed after regression fixes; publication and live evidence are archived with the release.
