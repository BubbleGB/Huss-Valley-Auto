# TP Assist chaser extension

TP Dodge is now labelled TP Assist in the panel and LastAction telemetry.
SetTPAssistEnabled and TPAssistEnabled expose the renamed control; older
SetTPDodgeEnabled/TPDodgeEnabled remain compatible aliases. Existing correction
blocks, cooldowns and per-round budgets are preserved across the rename.

Chasers may use a two-to-four-stud TP when a stable, active runner within
14 studs is outside current melee reach, but a checked landing would create a
predicted native melee contact. This uses actual melee geometry and its
windup/active window, requires an available attack and at least 1.5 studs of
distance improvement, and skips shielded, protected or evasive runners.
Landing body separation and the existing full geometry/hazard/exit checks remain.
The script faces the predicted contact after landing and lets the next fresh
combat check dispatch the native attack. Melee no longer interrupts TP's
correction observation; forced movement and round/context transitions still do.

The new policy case first failed without chaser utility and passed after the
extension. Runtime fixtures use the game's actual HitReplayMath against an
isolated runner model: a short approach creates a native-box melee opportunity;
shielded/evasive/unstable targets, cooldown and existing reach reject the move.
UI events verify the new label, paused behavior and old/new property agreement.
Independent review reported no important correctness findings.

No new forced teleport trials against live players were performed. A predicted
hit remains an estimate; the runner can change direction and server validation
can reject movement or combat. The four-stud cap, 12-second cooldown, two uses
per round, default OFF and correction/observation-gap blocking are unchanged.
