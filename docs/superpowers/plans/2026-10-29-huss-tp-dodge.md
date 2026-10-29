# TP Dodge implementation plan

User authorizes a toggleable short teleport for traps, thin obstacles and
imminent attacks, with conservative decisions and limited live testing. Earlier
instructions authorize implementation choices and require Delta overwrite.

Implementation stays in huss-auto-cross.lua, with Core policy tests in
huss-tp.spec.lua and UI/real collision/lifecycle fixtures in huss-tp-runtime.spec.lua.

- [x] Test first: OFF/paused/cooldown/forced-motion gates, maximum displacement,
  genuine utility, preference for safe walking, thin-obstacle requirement,
  landing/exit hazards, persistent correction block and round-limit behavior.
- [x] Implement 2/3/4-stud candidates, shortest useful choice, 12-second cooldown,
  at most two uses per round, no chained teleports. Preserve orientation and
  native velocity; invalidate route/history after moving.
- [x] Probe full landing body, stable same-height ground and immediate exit;
  refuse boundaries/safe zones, thick or unverified blockers, nearby bodies and
  dangerous landing points. Permit only verified thin-obstacle bypasses.
- [x] Add OFF-by-default UI toggle/report. Monitor MovementReset and unexplained
  short-term discontinuity for 1.5 seconds; block further use on that server if
  corrected. Context transitions invalidate observations instead of retrying.
- [x] Full native-client suite, independent review, one bounded 2-stud clear-floor
  live trial only when eligible. No repeated size probing after rejection.
- [x] Update docs/test bundle, overwrite Delta huss-auto-cross.txt, test saved
  bundle and verify exact readback; preserve original running/settings/UI state.

Native source exposes MovementReset but not hidden server acceptance rules.
There is no established undetectable distance. Default OFF and correction
blocking trade fewer dodges for avoiding repeated corrections. A four-stud cap
cannot cross every trap footprint or wall; those cases keep ordinary routing.

Review fixes: observation gaps now block further use rather than losing possible
snapbacks; a second sweep checks beyond the certified thin blocker. Both
regressions RED then GREEN. Post-TP exit direction also RED then GREEN.
One two-stud live trial completed a clean watch; MovementReset remained 97.

Final saved-bundle verification: 23 suites, 308 Core checks, zero failures plus
runtime assertions. Exact Delta source/bundle readback passed; original enabled,
speed, Smart and panel position restored; TP Dodge remains OFF. Trial helper
removed from delivered runtime. No commits or external publication requested.
