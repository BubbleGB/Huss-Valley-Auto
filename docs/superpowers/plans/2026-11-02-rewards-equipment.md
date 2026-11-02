# Rewards, equipment and persistent controls implementation plan

The user approved the interpretation in conversation and explicitly requested implementation. Continue inline without additional approval pauses.

Goal: replace minimized controls with a draggable Huss/Valley square, add free reward toggles and owned equipment selectors, name maps, persist settings automatically and start unless Stop everything is saved on.

Architecture: retain pinned WindUI. Add bounded reward/equipment state and native dispatch, validated profiles and debounced persistence. Native inventory snapshots are authoritative; equipment selection queues outside matches and only dispatches owned items. No purchases, synthetic desktop input or camera/pose manipulation.

- [x] Add isolated policy tests for ownership/role filtering, consumable timing, earned Journey claims, free crate token requirements and stale-state rejection; watch RED then implement Core policies.
- [x] Add runtime progression service with native state listeners, rate limits, one request at a time, lobby-only operations, stop gating and state-confirmed equipment. Exercise against fake remotes.
- [x] Update profile/autoload/autosave and stop lifecycle, minimized square and named-map/equipment/reward UI. Update current UI fixtures and add persistence tests using isolated storage.
- [x] Run build, Python and all native suites with fixture startup isolated from auto-start, file writes and reward dispatch. Only touch injection. Review whole change, fix important findings, publish to existing main and verify exact source.

Review focus: stale tokens/replies; depleted ownership; malformed profiles and account isolation; stop preventing queued remote dispatch; startup failures before automatic play.

Interpretation: spins consume available spin credits without requesting purchases; native snapshots do not identify whether existing credits originated from gifts or purchases. Crates use OpenFree only, never keys/currency purchases. Earned premium Journey rewards are eligible only when already entitled. Persist Stop everything and equipment preferences; temporary teardown during reload must not overwrite the saved running preference.

Review fixes: delayed equip replies now hold outstanding changes and query fresh armory state before retry; unreadable existing settings fail closed and remain preserved. Both regressions observed RED then GREEN. Full final native run:43/43 suites,464 Core checks; local16/16 and build verified. Touch drift safeguard aborted an earlier run, then the final full run passed without weakening it.
