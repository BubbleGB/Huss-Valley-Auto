# Lightweight runtime and delivery

User goal: lower overhead and download size with equivalent or better decisions. Keep the same loadstring path, features, reaction frequency, safety checks and no Delta writes. Implement inline using test-driven development and final review.

- [x] Add regressions for steering trig reuse, allocation-free threat interval checks and numeric parity with the previous sweep. Optimize Core.threatApproach/runnerEdge and fixed steering candidates; benchmark the identical route/steering scenarios before/after.
- [x] Add build tests for token-preserving compaction, quoted/long string contents, comments, number/operator boundaries, newline/source-map preservation and fail-closed unsupported syntax. Compact only generated delivery; keep editable modules formatted. The executable has no runtime decompressor or extra requests.
- [x] Compile and run the full native suite on the shipped compact executable. Run Python build tests, freshness checks, token equivalence, line-map validation, and independent review. Preserve current route/ability thresholds and native timing.
- [x] Document measured sizes/call counts/timings honestly; no claim of higher live catch/cross rates without comparable samples. Publish atomically to GitHub and verify fetched executable matches the tested artifact.

Review focus: numeric edge contacts, burst expiry/offset handling, shared candidate mutation, source-map drift, lexical boundaries and multiline literals. Optimization caches must not retain stale player/hazard state.

Final validation: 31 native suites / 395 Core checks, 16 Python tests, 300 seeded sweep replays, 8 native literal cases, 12 route scenarios with identical paths, and five paired benchmark runs. Independent review findings on expiry endpoints and CR-only comments fixed with RED/GREEN regressions. No game thresholds or reaction rates changed.
