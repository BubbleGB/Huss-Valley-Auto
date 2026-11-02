# Play, Settings, defaults and Ghost Trader

User approved the understanding checks and explicitly requested implementation.

Requirements: merge Runner/Chaser into Play with Revive, Dive, Dash and Target facing. Remove only runner/chaser automation and melee toggles; those mechanics remain always enabled under Stop everything. Delete camera-follow behavior, setting and binding completely. Merge Live decisions into Operation status; move markers and Print report to Settings, remove Diagnostics. Keep map vote map name, Hero/Chicken choice, selected player, dash/dive/ability/consumable labels in Operation status. Combined Gems & Currency priority. Add owned-key Ghost Trader spirit-card automation alongside crates/spins; default off, native cooldown/key/access rules, no purchases or local trader camera/cinematic.

Every visible toggle defaults off, including Smart Speed, seasonal collection, equipped ability/consumable use, Anti-AFK, voting and new Auto-save/Auto-load controls. Stop everything defaults off (core play running). Reset lives in Settings, confirms before any mutation, restores defaults and replaces saved configuration/options even when auto-save is off. Import/export JSON, manual Save/Load remain available.

Architecture/interfaces:
- Core defaults and priority migration owned by parent. Retired AutoRun/AutoChase/AutoMelee/FollowCamera ignored only when migrating old profiles; not supported as current settings. Version2 DefaultProfile() and validated ApplyProfile() owned by parent.
- Preferences agent owns runtime/preferences.lua and its isolated fixture. createPreferences(api,services) uses existing injected storage; new options path persists AutoSave/AutoLoad policy only. AutoLoad false skips saved profile application. AutoSave false prevents profile autosave and unload-save. Enabling AutoLoad saves a current profile once. Methods Boot, Tick, Save(force), Load, Reset, OptionsChanged; suspended tests never write. Reset writes defaults before applying and preserves prior state on storage failure.
- Camera agent owns runtime/combat.lua, loop.lua, lifecycle.lua and camera fixture. Remove camera writes/follow binding; use only PreSimulation target facing. Always core role automation/melee, native dive still toggleable. Parent owns src/main.lua/settings/UI and test-runner movement suppression.
- Ghost agent owns runtime/ghost-trader.lua factory and isolated fixture. createGhostTrader(services): Receive(kind,payload), Tick() -> requestSent bool; runner.createGhostTrader exposes factory. Services enabled,ready,clock,serverTime,send,random,cards,operation. Native State live/keys/nextAt/deal/opened, Flip slot; Result.state/reward. No real sends in tests, no local UI/view/open/camera/body calls.

Tasks:
- [x] Defaults, profile migration and combined priority tests/implementation.
- [x] Parallel isolated preferences, camera removal and Ghost Trader factory work; review/integrate each.
- [x] Rebuild WindUI categories, Settings actions and confirmed reset; preserve diagnostics through Operation status.
- [x] Migrate fixtures for default-off behavior and no public role-disable toggles; suppress live movement only in supplied test source.
- [x] Full native/local/build verification, independent review, GitHub publication and exact-source check.

Ruling: auto-save/auto-load policy flags must persist independently of optional profile autosaving, or turning auto-load on could not survive restart. Existing legacy profiles do not auto-load unless the new explicit AutoLoad policy is enabled. Import validation is atomic and user/account scoped. No executable is saved to Delta; settings JSON only.

Integration review caught and resolved two issues: Ghost pending requests now block equipment/rewards and invalidate on lobby/stop transitions; version 2 imports reject missing/foreign account identity before mutation. Added regressions were observed failing before fixes and passing afterward. Startup fault injection now anchors the Play tab. Touch safety aborted once during native camera motion; an unchanged-camera/body rerun passed without relaxing guards.
