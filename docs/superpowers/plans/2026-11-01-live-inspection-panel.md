# Live inspection panel implementation plan

Goal: independently add the useful diagnostic ideas observed in TITANIC HUB's public UI, without copying protected code or changing gameplay policy.
Architecture: one optional Info toggle, compact side panel, and bounded native GUI route/threat markers. Reuse existing planner/action snapshots at 5 Hz, no extra world scans, raycasts, HTTP calls, Drawing APIs or physics parts. Default off; hide immediately on Stop, Destroy, waiting state, stale context or disabled diagnostics.

- [x] Write failing runtime tests: toggle behavior, route/goal projection, behind-camera suppression, bounded threats/routes, throttle, stale/Stop cleanup and no leftover GUI on Destroy.
- [x] Implement runtime/inspection.lua using a table namespace to avoid extra top-level local pressure; include after UI and before lifecycle. Add Info button/API, consume cached navigation and action context, expose panel fields for route/timing/ability/crossing evidence.
- [x] Add 5 Hz heartbeat update and lifecycle hiding; display failures without stopping movement. Preserve test runner's diagnostics setting.
- [x] Verify focused/full Roblox suites, Python/build checks, review, and publish GitHub atomically after checking current head. Update source index and tests docs.

Constraints: no auto-revive/gem/reward spending changes, no license bypass, no protected-source copying. Native camera/body-facing behavior remains unchanged. Visual predictions are estimates, not native hitboxes. Keep current loadstring URL.

Verified 34 native suites, 415 Core decisions, 16 Python tests; independent review found no important bugs. GitHub source/head verification follows publishing.
