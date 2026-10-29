# Modular source and measured cleanup

Use the planning, inline execution and test-driven development skills. Keep current loadstring URL src/auto-play.lua, all current features and transactional cleanup. Develop in temporary files and publish one GitHub commit; do not write Delta copies.

Architecture: src/main.lua is an ordered build template that includes focused source units under src/core and src/runtime. The Python standard-library builder expands these at build time, preserving lexical scope and avoiding runtime requires, HTTP requests or wrapper overhead. src/auto-play.lua remains the generated standalone executable. Add a deterministic source map and module index so generated errors can be traced to editable source. Runtime units deliberately share the main lexical scope; they are not independent Roblox ModuleScripts.

1. [x] Add build tests for deterministic expansion, edits, cycles, path escape, duplicate/missing/unregistered source units and stale outputs. See RED before implementing the compiler. Extract source units by coherent function groups; prove initial assembled code byte-identical to the release.
2. [x] Retire selectRunner, intercept, canCommitDive and shouldDash: no production callers remain. Port useful legacy tests to actual active policies; keep the native combat, targeting, motion, dash and runtime suite intact.
3. [x] Measure participants/hazard/threat/route counts and costs in the client. Optimize demonstrated duplicate scans with tightly bounded, correctly invalidated sharing; retain fresh attack and hazard checks. Add a regression first and verify cached lists cannot outlive removal/reload/role changes.
4. [x] Run Python build tests, full Roblox suite, compile and distribution checks. Check generated source map and docs links. Review the whole diff and publish atomically to GitHub; verify executable content and branch head.

Review focus: include lexical ordering, duplicate compilation, generated/source drift, stale actor or hazard data, startup/Stop/reload cleanup. Do not imply smaller source units shrink the standalone feature set or claim measured runtime gains from module splitting alone.

Measured choice: scans were inexpensive (roughly 0.02–0.13 ms each); optimize duplicate route-cost evaluation instead of caching live actor/hazard lists. The cache is per search and keyed by exact position/time, so input freshness is retained.

Validation completed: initial byte-identical extraction, 7/7 Python tests, final 30/30 Roblox suites / 394 checks, source compile, distribution check, full source-map coverage, and independent review. The unchanged UI fixture passed in isolation and on the final full rerun after one transient live failure.
