# Full audit and Performance update

Historical report for commit `4a7a1b9`. The current [UI guide](ui-settings.md) describes the later camera alignment, Dashboard metrics and reward fixes.

The executable remains [src/auto-play.lua](../src/auto-play.lua), with the same
GitHub loadstring. New versions are published to GitHub; local settings storage
remains available. No executable was copied into the Delta workspace.

## Changes

- Performance tab: Hide Particles, Hide Other Players, Hide Gems/Currency and
  approximate frame rate/planner/managed-visual metrics. All three options default
  off. Rendering changes restore on disable, Stop everything and unload.
- Native touch input replaces map-vote and runner/role selection effect remotes.
  The map ballot closes only after the server snapshot confirms this controller's
  selected map. Visible round results close through their native Close button.
- Collection → Quests claims earned daily and event rewards through the native
  topbar menu, including selecting an earned event knife card. It waits for native
  state/UI confirmation, continues to other earned rewards, then closes. It never
  selects paid skips, refreshes or auto-complete. New option defaults off.
- Target Facing covers hunted runners, attack aim, runner movement and lobby
  movement. It changes body rotation at the current position and yields to native
  ability motion, locked characters and Stop. Camera properties are not assigned;
  Roblox retains its ordinary camera controller and native presentation cameras.
- Programmatic toggle synchronization uses silent updates, preventing delayed
  toggle callbacks from replaying an older value over a newer setting.
- Owned equipment lists cache by authoritative inventory snapshot and return
  independent copies. Unchanged equipment status text is no longer reassigned.
- Removed unused reward helpers, redundant progression revision state and the
  unused LiveDecisions alias. OperationReport and legacy profile migration remain.
- Comment-free production units compile from an ordered JSON manifest. Source
  boundaries, build validation, source maps and fixtures follow the new manifest.

## Audit decisions

| Area | Finding and action |
| --- | --- |
| Overhead | Keep fresh actor/threat/geometry data. Rendering observers exist only while needed. Candidate processing is limited to 120 objects or about 1.5 ms per tick; initial descendant enumeration is separate. No scan occurs when all visual features stay off. |
| Gameplay effectiveness | Existing route, ability, interception, collection and dive policy tests remain. Avoid changing combat tolerances without new evidence. No win-rate improvement is claimed. |
| Visual safety | Local rendering only: no destruction, collisions, touch, query or collection-data changes. Local avatar and recognized attack/trap/ability warnings are protected. Dynamic descendants, avatars, tag changes and reparenting are handled. |
| Restoration | Restore original/latest observed differing native property values. Same-value native writes while a property is forced cannot be detected without invasive hooks; do not assume exact recovery of such unobservable changes. |
| Compactness | Removed dead logic and all own production comments. Features add code: final executable is 276,932 bytes / 5,857 lines versus baseline 260,318 bytes / 5,576 lines. Smaller text alone is not a runtime-performance result. |
| Modularity | 59 explicit units share one lexical scope, with no extra module HTTP loads. Pinned WindUI remains separately loaded. Vendor source/license stay intact. |
| Settings | Batch tests restore the profile, running state and preferences ownership. New options default off. Live user settings are not replaced with an old session snapshot. |

Retained remote calls have specific purposes: Armory Get synchronizes owned data;
Melee carries timing/position/direction metadata for native prediction without
camera aim; revive uses the native timed Begin/Finish/Cancel protocol; SetAFK false
remains an intentional fallback. Rewards and equipment continue through native
menus and touch controls rather than direct reward/equipment effect commands.

## Verification and limits

53 selected Roblox fixtures passed, including 477 Core decision checks. All 17
Python build tests pass. There are 54 registered fixtures; the physical window-drag
fixture was deferred during an active match. The final focused rerun passes native
menu checks (90), popup input (14 in the broader run), facing (9), camera ownership
(27), and actual WindUI/settings/lifecycle checks.

Fresh read-only review found two visual protection/reparenting defects; detached
regressions reproduced them and pass after fixes. A further review checked native
quest paths and the new popup/facing logic. Event selection and sequential claims
received additional regressions after review.

A reversible live smoke test managed 527 visuals, then restored zero managed
visuals with all three settings off and no pending work. The first smoke observed
zero collision/touch/query changes. Native camera mode changed during the live
round, so it was not a controlled camera-mode comparison; detached camera-write
guards pass. Live popup/quest completion was not observed end-to-end. Native paths
were inspected in the connected client and their sequencing is regression tested.

Baseline planner mean was about 2.30 ms over 150 calls. Later samples ran under
different roles/round conditions and are not a controlled comparison. FPS and
crossing-success gains remain unmeasured.

[Detailed test results](../archive/results/2026-11-02/full-audit-tests.json).
