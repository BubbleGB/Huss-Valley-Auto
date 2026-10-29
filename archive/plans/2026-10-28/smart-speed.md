# Huss movement and race policy plan

Implement the user's requested behavior in the existing standalone controller,
using regression-first Core decisions and real native-model/UI verification.
User authorizes implementation choices and assessment without another approval.

- Ordinary enabled running reaches its profile cap in one native model step
  using a large finite acceleration. Native stops, restrictions, action motion,
  dash recovery, and role/round/item caps remain part of the native controller.
- Runner urgency targets the front half of current eligible finishers: compare
  approximate remaining ETAs and already-safe runners; aim for ceil(N/2).
  This is a pacing objective, not a guarantee. Traps/walls remain hard exclusions.
- Chase directly within 12 studs with a clear path and compatible height;
  otherwise retain obstacle routing and longer-range interception.
- Smart Speed is ON by default and has a UI toggle. Near an active opposite
  role (12 studs, line of sight), boost to at most 1.25x total for three seconds.
  Manual slider values are not multiplied again. Require separation to 20 studs
  and an eight-second start-to-start cooldown before another burst.
- Toggle/Stop cancels the burst. Same-round movement resets during a burst
  cancel it with a longer backoff; do not suppress or bypass game corrections.
- Hero for a known chaser count <=5; Chicken for >5 or unknown count. Count
  currently participating chasers including bots, rather than stale round attrs.

Verification: new policy/Core and native-model/UI tests, update existing
manual-speed tests for Smart Speed isolation and instant-acceleration semantics,
run all suites, review, observe live behavior, regenerate both Delta text files,
verify exact readback, and restore running state/base speed/panel position.

Completed: regression-first implementation and native runtime verification;
17/17 suites passed with 238 counted Core assertions. Final saved Delta source
and test bundle were both executed/verified. The reviewer identified a minor
target-cleanup cancellation issue, fixed with a failing-then-passing regression.

Ruling: nearby catch opportunities outrank distant pursuits, with existing
invisibility/hysteresis rules applied inside the nearby group — this follows the
new close-charge recommendation — a distant invisible runner may be released
for a close visible runner.

Ruling: preserve native braking and forced motion despite instant ordinary
acceleration — avoids rewriting action/physics controllers — physical movement
cannot be guaranteed to remain at the numeric cap during collisions/recovery.

Ruling: learn a 1.05x smart limit after a live burst correction and preserve it
for this server — a 1.25x burst was corrected after 2.43 seconds — smart mode may
offer no additional increase when the manual baseline is already at that limit.
