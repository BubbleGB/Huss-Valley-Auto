# Burst and ranged ability avoidance

User authorizes improving avoidance autonomously, preserving automatic crossing,
deadline urgency, the existing UI/settings, and the same Delta delivery path.

Evidence: runner threats only model ordinary dive reach plus observed velocity;
projectile zones cover 0.36 seconds; shield timing only sees player closing speed.
Native RocketShoes moves at 64 studs/s for 0.42 s plus 0.6 s carry. Cannon
launch speed includes momentum and its native flight/carry. Step Over has an
initial fake before a faster lateral burst. Opponents' equipped gear is generally
not replicated, so unavailable inventory must remain uncertainty, not knowledge.

- [x] Add failing trajectory/ability fixtures covering fast crossing attacks,
  finite burst/carry, active safety floors, vertical separation, cooldowns,
  sparse projectile attributes, perpendicular evasion and blocked escape routes.
- [x] Implement Core threat snapshots and analytic piecewise closest approach /
  first-contact estimates, preserving static-threat behavior and urgency.
- [x] Integrate native knife configuration, longer continuous projectile lanes,
  ready-ability soft risk, active-burst route zones, and fresh 30 Hz emergency
  steering/defensive ability timing. Retain collision/ground/trap exclusions.
- [x] Run complete native-client suite; review latest code, observe eligible
  live gameplay without forcing opponents' abilities, document limits.
- [x] Overwrite Delta [huss-auto-cross.txt](../../../dist/huss-auto-cross.txt) and [huss-test-suite.txt](../../../dist/huss-test-suite.txt), execute saved
  suite, read back exact source, and preserve enabled/UI/speed/Smart settings.

Implementation stays in the standalone [auto-play.lua](../../../src/auto-play.lua). New fixtures live in
[threats.spec.lua](../../../tests/core/threats.spec.lua) and [threats.spec.lua](../../../tests/runtime/threats.spec.lua). No changes to movement
caps, cooldowns, attack hitboxes or inventory ownership are needed.

Final: fixed review finding (fast steering discarded planned detours). Runtime
detour fixture RED then GREEN; final saved-bundle suite 21/21, 283 Core checks,
zero failures. Exact Delta source/bundle readback verified, paused state and
1.05x slider/Smart setting preserved. No commits or remote publication requested.
