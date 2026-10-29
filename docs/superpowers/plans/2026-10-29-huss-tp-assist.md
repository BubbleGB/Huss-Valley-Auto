# TP Assist chaser extension

User requests renaming TP Dodge to TP Assist and using it to catch runners.
Existing autonomous implementation preferences remain in force.

- [x] Add failing policy/runtime cases for an unobstructed melee opportunity
  created by a short TP; reject existing melee reach, cooldown, shields,
  evasive/unstable targets, invalid target and unsafe landing/exit.
- [x] Extend TP candidate utility for chasers using native melee sweep/window,
  current target velocity, a stable pursuit and real cooldowns. Require a
  meaningful distance gain, preserve full landing/body separation and limits.
- [x] Face the selected runner after committing and let ordinary native combat
  dispatch on a fresh action check. Keep correction observation during melee.
- [x] Rename UI to TP Assist, expose SetTPAssistEnabled/TPAssistEnabled while
  retaining old API aliases and existing persistent correction blocks.
- [x] Full native-client suite and review. Update docs/Delta test bundle,
  overwrite huss-auto-cross.txt and verify exact readback; restore all settings.

The existing four-stud cap, 12-second cooldown, two-use budget and server block
remain. A predicted melee opportunity is not a guaranteed hit or server approval.

Final: policy RED then GREEN (31 Core TP checks); native runtime chaser/alias
fixtures passed. Independent review found no important issues. Final saved
Delta bundle passed 23 suites/314 decision checks, zero failures. Exact source
and suite readback verified, enabled TP/speed/Smart/UI state restored.
