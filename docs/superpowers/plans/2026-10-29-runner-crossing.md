# Runner crossing improvements

> Implement inline, using executing-plans and test-driven-development. Publish to GitHub after verification; no Delta workspace writes.

Goal: improve crossing choices while retaining automatic roles, native abilities, full geometry/trap checks, dive confidence, Pumpkin Hunt and AFK protection.

Architecture: optional arrival times in existing bounded A*, direct-path and smoothing callbacks. A runner-specific finite-motion threat model reserves immediate catch space and scores ready dive corridors by heading/cooldown. Keep the existing fast steering override. Compare viable old/new lane costs before switching. Dispatch dash only for improved escape or a genuine progress benefit, checking the entire native dash/recovery interval. Track observable crossing outcomes locally without guessing unknown failures.

1. [x] RED/GREEN Core tests: approaching/departing threats, finite attacks, directional dive/cooldown, arrival-time routing/smoothing and late-round safety floor. Extend src/auto-play.lua; new tests/core/crossing.spec.lua.
2. [x] RED/GREEN dash tests: hold on clear low-benefit ground, escape an incoming attack, reject bad recovery, allow useful early progress when ready again before danger. Same Core fixture, runtime dispatch fixture.
3. [x] Integrate runner planning/actions and lane retention. Test actual closures in isolated geometry, including obstacle/trap rejection and emergency lane abandonment.
4. [x] Track starts, Safe, explicit catches, deadline-confirmed timeouts and interrupted attempts exactly once, including Stop/map/role/respawn; expose CrossingReport. Add Core and runtime tests, no fake live telemetry.
5. [x] Run full native suite, compile, build/check distribution, fresh review, short live observation, update usage/test docs and publish an atomic GitHub commit. Verify fetched source equals tested source.

Review focus: uncertainty beyond the short prediction horizon, escaping an existing catch zone, time-dependent route smoothing, dash recovery collisions, and ambiguous terminal round states. No guaranteed rate claims; a comparable live sample is required.

Completed: native compile and full 30-suite / 401-check run passed. Final review completed; tests cover deadline extension, character replacement, expired recovery threats, native dash curve and true cooldown start. No Delta files written. Release uses one atomic GitHub commit; live success-rate gain remains unproven.
