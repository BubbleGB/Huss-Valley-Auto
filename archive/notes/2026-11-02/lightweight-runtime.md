# Lightweight runtime and compact delivery

The release keeps the existing loadstring URL, source units, features, reaction rate, path safety margins, native ability timing and validation. The optimization does not shorten the search budget or remove obstacle/trap checks.

## Runtime work removed

- Swept threat checks use scalar 2D arithmetic rather than temporary flattened vectors and a per-call segment closure. Future intervals are evaluated directly without cloning every threat table. Overlap escape still uses the full edge endpoint even if a threat expires mid-edge.
- The 24 fixed steering directions are computed once and reused, eliminating repeated trigonometry and candidate-array allocation.
- A* skips risk evaluation for blocked edges and for moves whose best possible nonnegative cost already cannot improve the known route. Exact position/time memoization remains scoped to each search.

In a five-pair, nine-chaser benchmark, baseline median route-search time was 17.48 ms versus 7.75 ms for this release (about 56% lower). Every pair returned the same path. Twelve additional seeded layouts, including obstacles and finite burst motion, also returned identical paths. These are controlled measurements; device, geometry and scene affect real frame time, and no higher live crossing rate is claimed.

## Download size

Generated size fell from 167,904 bytes to 147,036 bytes (about 12.4%), or 143.6 KiB. The executable retains 3,143 physical lines to preserve error-line mapping; shorter download size does not require putting everything on one line. Editable source is unchanged in formatting.

The build removes only redundant whitespace/comments and verifies unchanged code tokens and line endings. Quoted/long literals, escaped newlines, compiler directives and the test/runtime boundary are preserved. Unknown syntax fails closed. There is no runtime decoder or additional network request. Source-map hashing describes the compact executable.

## Validation

31 Roblox suites passed with 395 Core decision checks and zero failures. The performance fixture includes 300 seeded comparisons with the previous vector sweep, including offset intervals and finite motion. Eight native-executed literal examples preserve their results after compaction. Sixteen Python tests cover the build, source map and lexical compactor, including CR-only comments, multiline strings, numeric/operator boundaries and stale artifacts.

Review identified two edge cases: an expiry-clipped overlap endpoint and CR-only comment termination. Both were reproduced by failing regressions, corrected and included in the final green test runs. The tested compact executable is the shipped artifact.
