# Source organization and measured cleanup

The source now has an editable entry template and 34 focused units. The largest unit is 286 lines. They are assembled at build time, preserving lexical scope; the executable remains at the existing src/auto-play.lua loadstring URL with no new runtime dependencies or network requests. The initial extraction reproduced the previous executable byte for byte before intentional cleanup.

Four old helpers had no production callers: selectRunner, intercept, canCommitDive and shouldDash. They were removed. Relevant targeting and interception tests now use the active policies; ten assertions for obsolete decision gates were retired. Current native combat, dive confidence, tactical dash and runtime coverage remain.

Profiling found average participant scans around 0.021 ms, hazard scans around 0.037 ms, threat snapshots around 0.134 ms, and route searches around 9 ms in the sampled scene. Keeping attack/hazard data fresh was preferable to adding broad-lived scan caches. The optimization instead memoizes identical position-and-exact-arrival-time costs within each individual route search. The cache cannot survive into another search or round.

In one identical nine-chaser benchmark, cost evaluations dropped from 2,661 to 1,599 (about 40%) and the exact same path was returned. Single-run time fell from about 22.46 ms to 15.90 ms. Timing varies by device and scene; this is not an overall FPS or crossing-rate claim. Three regression checks verify reuse and distinct arrival times.

The standalone executable changed from 3,174 lines / 169,771 bytes to 3,127 lines / 167,904 bytes. Splitting authoring files does not remove the feature set from the executable. The benefit is navigable source, traceable generated errors, less obsolete code, and less repeated route work.

Validation: 7 Python build tests cover deterministic expansion, changed modules, source mapping, cycles, duplicates, missing/unregistered sources, path escape, newlines and read-only stale detection. The Roblox suite contains 30 suites and 394 decision checks. A transient live title-drag failure passed in isolation on unchanged code; the final full rerun passed all 30 suites / 394 checks with zero failures.
