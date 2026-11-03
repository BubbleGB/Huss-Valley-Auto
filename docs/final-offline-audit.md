# Final offline audit — 2026-11-03

Baseline: `b34a47d12319739b6cdd954e94813a9ca18abfcb`. This phase implements the user's instruction to perform feasible work without a game connection and preserve the remaining live checks for later. No live settings, camera, inventory, player position or game session were accessed.

## Findings and fixes

| Finding | Severity | Resolution and evidence |
| --- | --- | --- |
| Reward confirmation baseline read after touch dispatch | Important | Capture revision/result/deal before dispatch; synchronous spin reply regression failed before the fix and passes afterward. Applies to the shared reward action path. |
| Rejected close discarded pending state | Important | Retain session after rejected/missing close input; regression proves pending confirmation remains and cannot become another primary action. |
| Ended/cancelled job retained UI session entries | Moderate | Explicit session Reset on workflow completion/cancellation; cleanup remains separate from successfully dispatched close. Native-shaped integration coverage and call-path review. |
| Preference serialization on every Heartbeat | Moderate | Sample at most once per .2 seconds before serialization; keep debounce/backoff. Deterministic 60-Hz fixture verifies bounded idle encoding, changed-profile saving and zero work during suspension. This is a work-count reduction, not a measured in-game FPS gain. |
| Terrain and edge caches omitted elevation | Important | Height cache includes ray-origin elevation; edge cache includes both endpoint heights. Lower/upper floor and planner regressions failed before the fix and pass afterward. Native stairs/bridges remain on the live checklist. |
| Failed Reset could leave a new default profile under an old autoload policy | Important | Write policy first, restore both prior contents and prior absence, use optional delete-file capability, and suspend automatic overwrite after rollback failure. Regressions cover options failure, partial profile write, successful rollback and unavailable deletion. Multi-file executor storage still cannot provide filesystem-level atomicity. |

A fresh independent reviewer reproduced the elevation and reset issues, reviewed the reward/cleanup/polling changes, and found no additional Important regression in those changes. The changes deliberately preserve game-dependent tuning until it can be measured.

## Scope and requirement coverage

| Audit area | Offline work | Deferred evidence |
| --- | --- | --- |
| Requirement history and UI | Reconciled optional defaults, core run/stop behavior, simplified controls, collection/equipment placement and stable executable access | Native widget/gesture regression |
| Runner/chaser behavior | Reviewed core policy boundaries, active participants/bots, close targeting, invisibility/cluster rules, prediction and action guards; detached policy coverage | Catch/crossing rates and native hitboxes/timings |
| Routing and collection | Geometry/planner review and elevation fixes; forward-only detour policy, terrain and navigation fixtures | Real stairs, slopes, traps and dynamic geometry |
| Events | Reviewed Fallen King and Pumpkin Hunt mode/lifecycle paths | Initial event gameplay validation |
| Lobby jobs | Reviewed serial scheduler, fairness, timeouts, free/owned guards, result/reveal flow, cooldowns, input ownership and cancellation | Actual server/UI acceptance after this release |
| Settings | Profile validation, persistence policy, reset rollback and polling review; isolated storage regressions | Native JSON, executor files, UI-driven persistence |
| Stop/reload/lifecycle | Reviewed release paths, stale async path tickets, UI/window ownership and bounded recent histories | Engine signals, pending native actions, long-session restoration |
| Touch and camera | Native-shaped touch/obstruction checks and camera guard review | Insets, actual input dispatch, blackout and manual intervention |
| Performance | Polling reduction, bounded queues/history, scan/cache inventory and compilation | Native frame/memory/connection measurements; full field scan per plan remains a candidate for measured optimisation |
| Tests and repository | Explicit offline runner, native fixture inventory, syntax compilation, updated test docs and live checklist | Engine-dependent fixtures remain required |

The user's verification of existing features is accepted as baseline evidence. It does not imply the offline substitutes provide new proof of native gameplay.

## Remotes and dependencies

Lobby reward operations use native touch controls with passive remote responses. The remaining direct `FireServer` sites are gameplay melee, revive Begin/Finish/Cancel, anti-AFK's preference update, and the initial Armory state request. Gear/ability actions also use native prediction modules. These do not all have an equivalent GUI action established offline; converting them without inspecting the live game could regress behavior. Their input-path review is preserved in the deferred checklist.

WindUI remains pinned to release 1.6.66 with vendored source/license and size/compatibility anchors. This is not a cryptographic authenticity guarantee. No new runtime network dependency was added. CLI Luau is an optional development tool, not part of the executable.

## Verification boundary

The offline runner explicitly allows eight Core fixtures and twelve detached runtime fixtures, plus focused offline regressions. It uses a limited mathematical substitute for Vector2/Vector3/CFrame and symbolic enums. It does not implement Roblox Instances, physics, native vector hashing/precision, networking or input. Native-dependent fixtures are not silently counted as passing.

The machine-readable results include the exact executable SHA256, suite names, counts and compilation result. Compilation of the assembled executable covers `main.lua`/`runtime/start.lua`, which intentionally form an opening/closing lexical fragment and cannot compile separately.

See [offline results](../archive/results/2026-11-03/offline-audit.json) and [the deferred live checklist](final-audit-live-checklist.md). Overall live release acceptance remains pending those checks; the offline phase does not certify every feature end to end.

## Recorded offline results

23 fixtures passed with 465 counted checks; 17 Python tests passed; 131 standalone Lua files compiled, including the assembled executable; distribution consistency passed.

Executable size: 313066 → 314044 bytes; 6528 → 6553 lines. The additional code implements the confirmed correctness and storage fixes. No native FPS or catch-rate improvement is claimed.
