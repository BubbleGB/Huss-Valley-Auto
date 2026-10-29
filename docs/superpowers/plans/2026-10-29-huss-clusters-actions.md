# Cluster targeting and native action optimization

User authorizes implementing cluster priority and optimizing dash, dive, melee,
and equipped ability use after checking their timing and hit geometry.

1. Add bounded density-weighted runner selection, retaining close-opportunity
   and invisibility tiers, with 12/14-stud entry/exit hysteresis and meaningful
   switching margins. Close opportunities require a clear approach.
2. Predict melee/dive contact using native HitReplayMath sweeps, native melee
   windup/active windows and TackleMotion distance. Prefer guaranteed melee;
   retain conservative dive commitments and independent path clearance.
3. Preview the native dash's redirected travel vector, validate its actual
   swept route, and avoid treating dash as an attack hitbox.
4. Separate lightweight action checks from 10Hz route planning. Add bounded
   request/prediction/server-reply timing telemetry and respect all native
   cooldowns, recovery, and ownership gates. Ready melee takes priority over
   placement abilities. Improve predicted trap placement for clusters.
5. Regression-first Core/native tests, full saved-bundle verification, live
   samples where gameplay provides eligible actions, timing/hitbox report,
   exact Delta readback, and restore user settings. Distinguish configured
   timings from actual measured replies; do not invent missing samples.

Preserve Smart Speed 1.10x/0.4s/12s, instant ordinary acceleration, front-half
pacing, Hero threshold, native blackout exemption, and Stop/X cleanup.
