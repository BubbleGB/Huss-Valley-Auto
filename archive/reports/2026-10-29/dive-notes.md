# Dive interception revision

The previous native-geometry path still inherited a roughly 7.5-stud range cap,
very early contact windows, near-zero lateral-motion tolerance and added two/
four-second spacing. Those restrictions excluded reachable stable trajectories.

The revised native path searches nine lead points over a bounded prediction
window, using TackleMotion.distance, native HitReplayMath sweeps and the current
speed-selected profile. Native TacklePrediction.request was inspected afresh:
it takes direction from root facing and chooses the same profile from current
horizontal speed and the current movement profile. Full native request gates,
cooldown and server validation remain unchanged.

Close targets within eight studs require at least 0.14 seconds of consistent
direction and early contact within 0.22 seconds. Wider cases require at least
0.25 seconds of consistent direction, with contact no later than 0.30 seconds
and within native dive duration. Search reach is bounded by native travel plus
contact reach. Straight acceleration can retain direction confidence; turns,
stops, target switches and observation gaps restart it. Existing speed-stability
history remains for other consumers and cannot override a newly reset heading.

Prediction includes bounded observed target acceleration. A narrower predictive
box and centered-contact test leave a margin inside the actual native geometry;
the game hitboxes are not modified. Every candidate uses full-travel collision,
ground and hazard checks. Immediate predicted melee remains first, and shields,
protected/evasive motion and overlapping attacks still prevent a dive.

Added retry spacing is max(native cooldown, movement plus recovery), then 0.15
seconds for close dives or 0.35 seconds for predicted dives. In the inspected
long profile this totals 1.25/1.45 seconds. A refused local native request gets
a bounded 0.25-second local retry delay; the native controller remains decisive.

Verification: 17 new Core fixtures run against actual native profile/motion/hit
modules. They cover fleeing targets beyond the old cap, lateral leading,
stationary targets, short direction confidence, unreachable targets, protection,
blocked paths, melee priority, native retry spacing and heading-change resets.
The actual runtime closure was exercised with isolated geometry and a stubbed
request; the saved old source failed to dispatch the reachable nine-stud case,
and the new source passed. Runtime tests also check repeat spacing, blocked
paths, shields and removal of synthetic telemetry. Independent review verified
native integration and identified the heading-authority edge case; its new
fixture first failed and then passed after correction.

More predicted opportunities are not proof of a higher catch rate. A runner may
change direction after commitment, and dive recovery still costs free movement.
No opponents' behavior or cooldowns were forced for testing.

After final saved-bundle verification, ordinary chaser play recorded an accepted
close dive with no rejection or controller error. Its first simulation was
observed after 24.927 ms and its matching reply after 125.734 ms. This confirms
a live eligible request, not a successful catch or a catch-rate improvement.
Raw follow-up observations are in [dive-live.json](../../results/2026-10-29/dive-live.json).

Follow-up requirement: every dive must predict a catch. All generic approximate
dive fallbacks have been removed from combatAction. Runtime dispatch also rejects
a dive without a finite valid contact time inside its native movement window.
Both guards have regressions that failed before the change and passed after it.
This is a prediction requirement, not a guarantee against a later runner reaction.
