Live speed trials, 2026-10-28

Tested 1.00, 1.05, 1.10, 1.15, 1.20, and 1.25 multipliers using the active
autoplayer. Recorded horizontal displacement against velocity integration,
backward jumps, MovementReset changes, active movement time, and native
MovementGuardEvent messages. These are client observations, not access to the
server's enforcement code or thresholds. No guard events were suppressed.

The exploratory sweep was clean at 1.00 and 1.05 for about 12 seconds of active
movement each. The short 1.10 sample was also clean, but longer validation
recorded a 14.36-stud residual and a backward jump with MovementReset changing
within GroupRun, round 1, as Runner. The 1.15 exploratory sample had a
20.47-stud residual; 1.20 had a 10.17-stud residual before its test was stopped.
Exploratory results did not exclude all phase transitions, so those alone are
insufficient to attribute a jump to enforcement.

A speed-only variant preserved native acceleration, braking, dash distance,
and dash timing. At 1.25 it still recorded two same-round Runner corrections
(9.04 and 13.47 studs, both with MovementReset changing). Keeping native burst
motion did not establish a bypass.

At 1.05, the speed-only variant ran for 69.28 seconds with 30.00 seconds of
active movement, 1,813 eligible samples, and 15.29 seconds near its selected
speed cap. It recorded zero large residuals, zero backward snapbacks, zero
MovementReset changes during eligible frames, and zero guard warnings. Maximum
position/velocity residual was 0.77 studs. Native round/role changes and forced
ability motion were excluded from this validation's comparison.

Final default: 1.05, applying the multiplier only to the fully resolved native
MaxSpeed. This is the tested default, not a guarantee of future stability or
undetectability. 1.00 remains available for exact native movement profiles.
The slider still spans 1.00–2.00 in 0.05 steps. Raw validation data is in
`huss-speed-live-results-2026-10-28.json`.
