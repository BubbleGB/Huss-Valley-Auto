# Short Smart Speed trial

User authorized testing 1.10x bursts for 0.4 seconds with a 12-second cooldown,
while retaining instant ordinary acceleration. Kept the 12-stud line-of-sight
trigger, 20-stud separation requirement, non-stacking manual slider, toggle,
and learned 1.05x fallback with 15-second correction backoff.

The new policy has its own identifier: short-110-040-12-v1. A limit learned from
the former three-second/1.25x policy does not prevent this authorized experiment.
A correction under this policy saves its fallback for reloads on the same server.

Cooldown now survives round, role, and character context changes. The active
speed cap expires after 0.4 seconds, while correction monitoring remains armed
for another four seconds. Same-phase movement resets can therefore cause
fallback after the burst ends, including if temporarily airborne or in forced
motion. A movement reset is treated conservatively as a signal, not proof of
anti-cheat action. Native braking and forced controllers remain intact.

Verification: 17 suites passed, with 245 counted decision assertions and further
runtime assertions. New coverage includes short duration, 12-second cooldown,
separation and round-change bypass attempts, delayed correction backoff,
policy-specific learned-limit migration, and actual runtime fallback on a
detached airborne fixture. The fixture restores shared references and learned
state and does not modify real players or server round attributes.

Independent review identified the transient-eligibility observation gap; the
new runtime regression failed before the detector fix and passed afterward.
The delivered Delta test bundle was executed against its saved controller file.
These tests do not establish that shorter bursts are undetectable or stable in
every server situation.

An initial integration run saved a fallback while the older slider tests also
ran real frames at higher manual values; that was a confounded observation.
Slider profile checks now run without real frames at those test settings, and
the runtime speed test returns to 1.05x before its yielding observation. The
smart toggle test enables smart mode while paused. Instant acceleration remains
unchanged.

The isolated live run kept a 1.05x baseline and observed one real 1.10x burst
near a runner's chaser at 9 studs. Observed duration was 0.39944 seconds. No
controller errors or corrections were detected through the four-second
post-burst window; the complete observation lasted 165.62 seconds. This is one
clean sample, not proof of general stability. The short-burst trial remains
enabled at 1.10x with its 1.05x fallback ready for a future correction.
