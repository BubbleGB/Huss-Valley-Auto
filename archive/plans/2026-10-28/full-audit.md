# Huss Valley audit implementation plan

> **For agentic workers:** Execute inline using superpowers:executing-plans; request independent review after fixes.

**Goal:** Audit current native game contracts, fix evidenced decision/lifecycle issues, run the full suite, and deliver a verified Delta workspace script.

**Architecture:** Keep the standalone Core/runtime script. Add focused pure decision helpers and real Roblox lifecycle regressions; retain native action controllers and the 1.05 speed default. Fix demonstrated problems rather than adding speculative game mechanics.

**Tech stack:** Luau in the connected Roblox VM; executor filesystem; local test files.

**Spec:** User's full-audit request and existing behavior documented in [usage.md](../../../docs/usage.md).

## Constraints and review focus

- Preserve Start/Stop/X, draggable UI, automatic roles, blackout exemption, and 1–2 speed slider in 0.05 steps.
- Use owned equipped abilities only; respect game cooldowns and restrictions; no purchases or inventory consumption.
- Preserve running/paused state, selected speed, and UI position after verification.
- Overwrite Delta [huss-auto-cross.txt](../../../dist/huss-auto-cross.txt) and verify exact readback after the final version.
- Regression focus: dangerous final route edges, competing goals, partial startup failures, active non-button touch targets, native Soul Reap records, render-time routing cost, round/character changes.

## Tasks

- [x] Run baseline six decision suites and six live runtime suites. Inspect native movement, combat, ability, participant, and blackout contracts. Request independent review.
- [x] Add [audit.spec.lua](../../../tests/core/audit.spec.lua) regressions proving sampled final-edge risk and total-cost goal selection; correct Core.route and recheck all route suites.
- [x] Add input-hit-test regressions for active TextLabels/Frames and hidden UI; keepalive must defer instead of manipulating controls.
- [x] Inject startup failures and verify cleanup, native getter restoration, and successful reload. Initialize runtime transactionally and publish only after successful setup.
- [x] Match Soul Reap capacity and available souls against native SoulReapFrom and Game.SoulReapSouls records, with pure state regressions.
- [x] Profile planning in actual play, bound or reschedule work if measurements show harmful input/render stalls. Cover any scheduling changes with runtime Stop/round-transition tests.
- [x] Build a repeatable complete suite runner, run all suites, record exact pass totals and live observations, obtain follow-up review, update README and audit report, save/readback Delta source, restore user settings.

No commit or external publication is requested. Existing user authorization covers implementation choices and inline execution without another approval step.

## Evidence ledger

- Baseline: six decision suites, six runtime suites passed before changes.
- Route final-edge regression failed before the goal/risk fix; three route regressions passed afterward.
- Active-control predicate regressions and real full-screen active-frame defer/resume test passed.
- Injected startup faults initially left a wrapper behind; transactional initialization passed both fault sites and reload checks.
- Native Soul Reap and trapped-human eligibility regressions failed before their fixes and passed afterward.
- Risk sample duplication regression failed before per-search memoization and passed afterward.
- Ruling: retain the synchronous bounded planner with sample memoization and telemetry — observed final planning averaged 1.54 ms with a 6.27 ms peak — risk if future maps are heavier: render stalls could warrant incremental planning.
- Final review: fresh independent reviewer reported no important findings; unequipped Soul Reap remains fixture-only validation.
- Complete and delivered suite: 15/15 passed, 209 counted decision checks, settings restored; saved source and self-contained test bundle verified by exact Delta readback.
- Live observation: 80.46 seconds, two successful crossings, no recorded controller errors.
