# Native lobby collection interactions

User requests actual station/menu interactions for spins, Ghost Trader, Journey, crates and related equipment actions. Replace custom reward/equip remote dispatch with a serial native UI workflow, using ordinary walking and touch/prompt input. Keep existing feature settings, defaults, save data and concise labels. Never modify the live camera; native presentations own their normal camera behavior.

Architecture:
- runtime/lobby-workflow.lua: injectable serial job factory (Tick/Cancel/Report); services clock, enabled, ready(job), allowed(job), jobs(), reach(job), open(job), inspect(job), act(job,token), close(job), halt(), operation(text,action,target), changed(job,active). Jobs {key,kind,name,cooldown}. Inspect returns visible, waiting, done, action token, description. Only input after reach/open; no blind repeat while waiting; bounded deadlines, fair per-job backoff, cancellation.
- runtime/lobby-input.lua: injected guarded touch/prompt factory. Methods Tick, Tap(button), TapCard(hitPart), Prompt(prompt,root), Release, Busy. UI touch hit testing and native card ray checks; paired touch begin/end; ordinary InputHoldBegin/End only within enabled prompt range; no direct events/remotes/callback injection or camera writes.
- runtime/lobby-navigation.lua: injected path navigation factory. SetGoal(position,range), Step(character,humanoid,root)->direction,jump,status, Cancel. Pathfinding asynchronous/rate-limited/versioned, bounded recovery and ordinary movement/jumps only. Native lobby movement integrates in loop after release, isolated from match planner.
- runtime/lobby-ui.lua: native selectors, per-job inspection and safe action tokens. Native wheel Spin10/Spin5/Spin, Journey ClaimAll, crate Free/Continue, Ghost projected card taps and Leave, owned gear Equip. Never purchase keys, skips, crates or gear. Respect native controls/ownership/cooldowns; passive remote replies provide confirmation only.
- runtime/progression.lua: retain owned equipment API/passive state receivers/operation reporting; replace its remote send worker with workflow wiring and job creation.
- Retire remote-driven ghost runtime/factory tests once replaced. Preserve GhostTraderReport API from passive state/workflow.

Validation:
1. Factory and input/navigation isolated regressions (RED then GREEN), fake services/remotes, no live spending.
2. Integration tests assert no collection/equip FireServer dispatch; correct native targets and x10/x5/single/ClaimAll; stop/disabled/menu/round/path/timeout gating.
3. Distribution checks/Python/native compile and relevant suites through settings-preserving runner. No unsafe standalone UI tests. Check current settings/file remain unchanged around any live integration.
4. Independent review, documentation, publish GitHub and verify exact executable bytes. No executable saved to Delta workspace.
