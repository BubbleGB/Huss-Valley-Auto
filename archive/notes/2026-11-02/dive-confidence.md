# Dive confidence

Problem: a single projected trajectory can intersect the native dive box even though a small lateral change makes the fixed-direction dive miss. Live request acceptance does not prove a catch.

Use the existing native sweep, travel profile, and nominal prediction. Require the same aim to retain contact across both lateral movement changes and replicated position uncertainty. Bound catch horizon, prioritize earlier robust contact, retain full-travel obstacle checks and melee priority. Do not alter dash behavior, cooldowns, native hitboxes or other game modes.

Verification: reproduce a nominal false positive in a native-geometry regression, keep assured close and stationary catches, exercise runtime dispatch with a blocked and an assured case, run all suites, rebuild distribution, review, and publish to GitHub. No Delta writes. Live catch-rate improvement requires enough comparable rounds; do not claim guaranteed catches.

Validation: the nominal-only miss regression failed against the previous release and passes with the uncertainty check. Compile and 27 suites / 356 Core decision checks passed. Close and slower-target predictions remain eligible; farther fast-fleeing cases now wait. No measured live catch-rate comparison yet.

Replication uncertainty uses target speed times inferred one-way reply latency, capped at two studs. Separate regressions verify that a borderline higher-latency approach waits while its low-latency equivalent remains eligible. The latency estimate is a heuristic, not a measurement of a particular target update age.
