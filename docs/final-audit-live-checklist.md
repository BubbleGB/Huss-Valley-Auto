# Deferred game-environment verification

Offline audit date: 2026-11-03. No Roblox MCP actions were performed during this audit. The user's confirmation remains the baseline for previously working features. These checks validate the final changes and engine-dependent behavior; they are not assertions that those features are broken.

## Session preparation

- Record the loaded GitHub revision, profile and window state. Suspend persistence during destructive tests and restore it afterward.
- Use touch input only. Preserve actual inventory ownership and free/paid distinctions. Reward tests may consume owned credits/items only within the user's existing automation choices.
- Use the preserving native runner for controller/UI fixtures; avoid physical drag tests during gameplay.
- Run the native suites omitted by the offline allowlist, especially preferences JSON/filesystem, actual UI lifecycle, input permissions, visual restoration and facing. Report exact results and restore state even if a fixture fails.

## Highest priority: changes in this audit

1. Stacked-floor navigation: traverse Map 7 stairs and Haunted Ship; check bridges with walkable ground above and below. Repeat lower/upper path queries at identical X/Z with different obstacles. Require correct floor selection and no movement into upper obstacles. Repeat with moving geometry.
2. Rewards: open a free crate, spin, owned pumpkin, completed quest and Ghost card when available. Check prompt, result, reveal, Continue and close. Require one accepted action per request, no duplicate spending and no premature completion. Include fast and delayed replies.
3. Blocked close: cover the close button with a native overlay/player list and remove it. Require pending result ownership to survive the rejected touch and bounded recovery without duplicate primary actions.
4. Stop/restart during reward animation: stop before response, during reveal, during Continue and during close. Require immediate release of owned input/movement, no action after Stop, and sensible behavior when a late response arrives. Restart and reload with a native menu already visible.
5. Settings: verify saved profile loading, import/export, confirmed reset, then reload. Test storage failure in isolated test paths only. Require prior runtime/profile preservation on failure, explicit rollback errors, and suspended automatic overwrite when recovery is uncertain. Verify the actual executor's delete-file capability.
6. Autosave: change settings through controls and direct API; require persistence after debounce, no idle write churn and correct resume after suspension. Observe actual serialization and frame overhead.

## Event work still awaiting initial live validation

- Fallen King: entry/cutscene, hearts, bomb pickup/aim/throw, melee on healing shrines, attack telegraphs, fog, downed/revive, death and exit. Check camera/facing ownership and Stop throughout.
- Pumpkin Hunt: detect mode independently of map, enemy motion/state transitions, target changes, collection/bait routing, facing, knockback, elimination and transition to normal rounds. Compare gameplay outcomes over representative attempts.

## Integrated regression and endurance

- Runner/chaser transitions, native bots, invisibility priority, target retention, clusters, interception and close pursuit; judge dives against recorded outcomes rather than request counts.
- Ability/consumable ownership, cooldown, active defenses, restrictions, resource conservation, denied actions and equipment changes.
- Forward-only gem/seasonal collection in both crossing directions, revived targets and end-of-round urgency.
- Selection/voting: native random runner, Hero/Chicken threshold, configured map fallback, confirmed dismissal without reopening, round results and player-list obstruction.
- Touch/camera: mobile insets, scrolling/clipping, manual touches, menus, camera replacement, lights-out entry/exit, minimisation and restoring the window. Confirm anti-AFK UI queries and touch dispatch work from actual callbacks.
- Stop, unload, repeated execution, respawn and character replacement: no lingering touches, movement, owned visuals, camera locks, callbacks or async paths.
- Long session: compare memory/connection counts and planner timings across repeated matches, lobby jobs and reloads. Exercise anti-AFK over time. Measure actual FPS and gameplay outcomes under comparable loads.

## Completion evidence

Record scenario, build, relevant settings, native acceptance/state evidence, outcome and remaining limitation. Distinguish automated native fixtures, observed live outcomes, user verification and unavailable scenarios. Do not mark unavailable events passed. Keep the previous release available for rollback.
