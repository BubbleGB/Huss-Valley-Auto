# Full audit and Performance controls

User approved the understanding check and requested execution first, then the full audit and changes. Current GitHub executable was launched successfully before audit work. Baseline commit is f21d153a98375d4ccaefdd43b78a89fbd2c44f92.

Scope: full static/runtime audit followed by overhead, effectiveness, improvements, compactness/readability/modularity, bugs/dead code and remote-use passes. Add a Performance tab with reversible Hide Particles, Hide Other Players and Hide Gems/Currency, all default off. Preserve existing settings, detection, collisions, collection and native gameplay warnings. Own production Lua contains no comments. Keep the same executable/loadstring and publish to GitHub only; settings JSON remains local.

Measured baseline: 17 human players; 531 ParticleEmitters, 80 Trails, 235 Beams in workspace; planner 150 calls totaling 345.76 ms, last 1.76 ms, max 7.83 ms. Twelve explicit UI refresh calls averaged .060 ms, max .203 ms. Measurements are contextual, not a win-rate or FPS comparison.

Tasks:
1. Audit inventory and evidence: enumerate modules, loops, scans, API consumers, remotes and native controls. Record risks and measured priorities in the report. Do not change gameplay policies without a reproduced defect.
2. Add isolated visual performance ownership factory and runtime integration. Queue bounded updates, discover relevant visuals on demand, react to descendants/character changes, preserve gameplay effects, restore original/latest observed native values and clean up on disable/unload. Add default-off settings and concise Performance tab with meaningful metrics. TDD fixtures exercise toggles, original values, dynamic additions, native changes, safety exclusions and cleanup.
3. Replace reliable map-vote/role GUI interactions with the existing touch adapter where native identities are established. Keep only justified metadata/native prediction/AFK uses; no blind fallback purchases or synthetic desktop input. Audit/test any retained effect commands explicitly.
4. Remove demonstrated unused state/aliases and redundant UI updates; cache owned equipment by inventory snapshot if verified safe. Keep actor/threat/geometry freshness. Measure changes without claiming unmeasured outcomes.
5. Replace source comment include directives with a validated ordered JSON manifest. Split core preamble/runtime startup naturally; strip production comments with the existing lexer. Migrate fixtures to the first runtime assertion boundary. Preserve code tokens and standalone delivery; retain third-party original licenses separately. Update build-contract tests and GitHub test bundle loading.
6. Run build/Python/native compile and registered fixtures through the preserving runner. No destructive standalone UI fixtures. Verify saved settings and default-off compatibility; use detached visual models for testing, plus a reversible live smoke check only if it preserves the current profile.
7. Fresh whole-change review when available, fix findings, finish audit report/docs and publish. Verify raw executable byte-for-byte.

Rulings:
- Comment restriction applies to our production Lua. Documentation/tests and upstream vendor originals/licenses remain distinct audit material.
- Protect attack/ability/trap effects. Hide Other Players affects local rendering only; actors remain detectable and physical objects remain present.
- Native controls are preferred where stable, available and unambiguous. Existing native prediction APIs and read-only inventory synchronization may remain.
- Standing user authorization covers direct GitHub publication; no new approval checkpoint is needed.
- Preserve legacy profile migration: it was needed for the user's settings recovery and is not dead code.

Additional approved scope: dismiss native round-result popup, dismiss ballot after confirmed own vote, expand body facing to route/lobby movement and targets while keeping the normal camera controller, and claim earned daily/event quests through native controls.

Ledger:
- Execution first and baseline inventory: complete.
- Implementation and fresh read-only review: complete; gameplay visual protection and ancestry findings fixed with regressions.
- Verification: 53 selected native fixtures/477 Core checks and 17 Python checks passed. Physical drag fixture deferred in active match.
- Live visual smoke: physics unchanged; all managed visuals restored after toggles disabled. Native camera mode changed during the live round, so this is not a controlled camera-mode comparison. Detached camera-write guards passed.
- Publication tracked in the audit report and commit.
