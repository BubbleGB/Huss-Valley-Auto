# Movement and race policy update

Implemented the user's recommendations with these limits and interpretations:

- Ordinary enabled movement reaches its currently resolved cap in one native
  model step, for Runner and Catcher. The implementation uses finite high
  acceleration and keeps the stall speed cap consistent with that speed.
  Native braking, contact physics, stuns, dash recovery, and forced ability
  controllers still apply. Stop restores the native profile completely.
- Front-half pacing uses current eligible runners' approximate remaining ETAs
  and already-safe runners. It aims for ceil(N/2) and raises urgency near or
  behind that cutoff. It does not override traps, walls, or missing ground.
  Future catches, route differences, and opponent actions prevent a guaranteed
  finishing percentile.
- Catchers prioritize nearby opportunities within 12 studs at compatible
  height, retaining invisibility priority and target hysteresis within that
  group. Clear approaches charge directly; blocked approaches still route.
  More distant pursuits retain interception.
- Smart Speed defaults ON and is toggleable in the panel and API. A visible
  active opposite-role participant within 12 studs triggers a three-second
  cap of 1.25x total speed. It does not stack another multiplier on the slider;
  a manual setting above 1.25 remains the user's selected setting.
- Bursts do not continuously renew. Rearming requires 20-stud separation and
  an eight-second start-to-start cooldown. Disabling, Stop, and own suspension
  cancel a burst; target replacement alone preserves it. A detected same-phase
  movement reset during an actual speed increase cancels it with a 15-second
  backoff and learns a 1.05x smart limit for this server. The limit survives
  reloads; a different server starts at 1.25x. Manual slider settings are still
  explicit overrides. This is recovery from corrections, not a detection bypass.
- Challenged runners choose Hero with <=5 currently participating chasers,
  including bots, otherwise Chicken. Unknown counts default to Chicken.

All 17 suites passed, with 238 counted Core assertions and additional runtime
assertions. New tests cover first-frame native movement and turning for both
roles, burst duration and rearming, non-stacking caps, correction backoff,
race-pressure integration, nearby-target priority, Hero thresholds, UI toggle,
runtime getter expiry, target replacement, and Stop restoration. The complete
saved Delta test bundle was executed successfully against the saved controller.

Independent review found no important cap/cache/ranking defects and identified
one minor target-cleanup cancellation issue. Its regression was observed failing
before the fix and passing afterward. Runtime tests instrument the actual local
state/getter without moving real opponents or changing server round attributes.

Initial integration observed three real chaser proximity boosts at 1.25x from
distances 7–12 studs and 93 direct-pursuit observation samples. Those observations
preceded the target-replacement cancellation fix and are not evidence of full
three-second retention; that retention and expiry are covered by regressions.
The final live runner observation lasted 130 seconds and recorded three
crossings, 218 race-policy samples, and no controller errors. It also recorded
one real 1.25x runner burst near a chaser, followed by a movement reset after
about 2.43 seconds. That evidence prompted the learned-limit change: the current
server now uses a 1.05x smart limit rather than retrying the same peak. Burst
limit behavior and runtime cache selection are covered by additional regressions.
The live observation and final suite output are saved in the adjacent dated
JSON files. Hero selection was not forced on the live server.

Earlier overspeed correction measurements still apply as a limitation: this
update does not establish that bursts or instant acceleration avoid enforcement.
