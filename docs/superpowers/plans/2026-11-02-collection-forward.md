# Collection tab and forward-only pickup routes

Rename Rewards to Collection and keep existing free reward toggles there. Move Collect Gems from Runner into Collection. Add saved AutoSeasonalCurrency toggle (default true to preserve existing candy behavior), currently native Halloween Candy Corn.

Collection must never cause backwards travel. Use a stable crossing axis from the native start/finish safe-zone centers. Reject gem/candy goals behind the runner or beyond the finish. Enforce nonnegative forward progress on collection route edges, walking, native dash checks and TP candidate/exit segments. Cancel any passed/collected/disabled/blocked pickup and clear stale navigation before it can issue reverse movement, checking before planning and immediately before movement each frame. Time Warp cannot rewind toward a collection target. Ordinary threat avoidance and revival behavior remain independent; do not weaken geometry/threat/timer checks.

- [x] Observe RED policy tests for behind/passed/overshot goals and seasonal setting; implement forward collection helpers.
- [x] UI/settings integration and runtime guards with isolated body fixtures; validate stale directions, blocked/hidden/passed pickup cancellation and re-planning.
- [x] Touch-only native suite and local checks; focused independent review, publish GitHub and verify exact source.

Validation: focused Core detour28 checks and actual detached planner/guard/UI fixtures passed. Full initial46-suite run:44passed/2UI visibility failures during native FallenKing (all owned ScreenGuis disabled externally); touch guard aborted before input. All16Python/build checks passed. Read-only review found no important issues. After native intro visibility returned, the full rerun passed46/46suites,479Corechecks. No input safeguards were weakened.
