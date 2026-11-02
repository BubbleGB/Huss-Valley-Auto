# Pumpkin Hunt adaptation

Use native PumpkinHuntConfig and replicated PumpkinPeople records. Enter only during an active Pumpkin Hunt, stop on HuntOut, and restore normal crossing/chasing afterward. Seek clear bait positions within BreakRange, widen spacing on the final life, reserve the Tell/Lunge corridor, and dodge laterally with existing geometry and dash checks. Do not donate coins or open rewards.

- Add Core activity, threat and goal tests; verify failure against current release.
- Implement Core policies and event branch in planning/actions; keep normal behavior intact.
- Add an isolated event transition/runtime test. Run full suite and compile check.
- Rebuild distribution, review the diff, publish an atomic GitHub commit, verify fetched source.

Review focus: stale NPC observations, overlapping lunges, low health, map changes and return to standard rounds. Temporary development only; no Delta workspace writes.

Validation: compile passed; 27 suites / 352 Core checks / zero failures. Final review findings on moving-NPC prediction and obstacle detours fixed with RED/GREEN regressions. No live hunt available.
