# Final offline audit implementation plan

Goal: complete all feasible offline review and regression work; preserve a durable live validation checklist for the user's next MCP session.
Architecture: retain the manifest-based Lua modules, build distribution and existing fixture suite. Add a CLI Luau runner with explicit supported fixtures and isolated mathematical substitutes; no game access or live-state mutations.
Spec: the comprehensive final maintenance audit agreed in conversation, with game-dependent validation deferred by the user.

## Constraints
- Preserve user settings and stable GitHub executable path.
- No production Lua comments, synthetic desktop input, paid reward alternatives, or unrequested game interaction.
- Do not claim a substitute proves native physics, UI dispatch, catch rates, network behavior or FPS improvements.

## Tasks
- [x] Verify published baseline and produce an offline test runner; compile all Lua and run eligible fixtures.
- [x] Review every source module for lifecycle, bounded state, stale action/confirmation, resource, settings, interaction and performance risks.
- [x] Reproduce confirmed findings, fix with focused regressions, and rerun appropriate checks.
- [x] Review historical requirements, dependencies/remotes, repository usability, and test documentation.
- [x] Produce severity/evidence report, coverage inventory and precise deferred live scenarios.
- [x] Obtain final independent review, address substantive findings, rebuild, verify and publish tested artifacts to GitHub.

## Evidence ledger
- Baseline: b34a47d12319739b6cdd954e94813a9ca18abfcb, tree 8710b8225fb4f29900f1438607bc008543549baa.
- No Roblox/MCP operations permitted for this phase; user verification remains baseline evidence, not a new test result.

- Final review: two Important findings reproduced independently (elevation cache and reset rollback); fixed with failing-then-passing detached regressions. No re-review required after the focused fix pass.
- Ruling: retain native gameplay prediction/remotes and game-dependent tuning until an actual game input alternative or measured improvement can be demonstrated. Incorrect speculative replacement risks gameplay regressions.
- Ruling: offline math is deliberately limited; native vector hashing/precision, physics, UI input, actual FPS/catch rates and storage APIs remain deferred.
- Verified: 23 offline fixtures, 465 counted checks; assembled executable and 131 standalone files compile; Python and distribution checks recorded separately.
- Publication: final verification and upload are recorded by the GitHub commit and result checksum; live acceptance remains pending docs/final-audit-live-checklist.md.
