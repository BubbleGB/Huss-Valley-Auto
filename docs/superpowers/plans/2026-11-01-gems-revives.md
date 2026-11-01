# Optional gem and revive detours

Goal: expose separate usable gem/revive toggles, independently implementing the native mechanics advertised in the inspected UI.
Architecture: pure conservative detour selection, opt-in runtime sensing, current geometry/threat routing, native 0.3 second rescue hold, physical gem pickup. Both default off. Prefer eligible safe revives over gems. Ordinary GroupRun/HeroRun/FinalRun only.

- [x] Core failing tests: toggles/urgency/timer/proximity limits, threat/obstacle vetoes, revive priority, bounded detour and hold safety.
- [x] Runtime failing tests: visible local gem detection, collected exclusion, native rescue Begin/Finish timing, cancellation/dedup on danger/Stop/role change, independent toggles and cleanup.
- [x] Implement policy and opt-in runtime, integrate planner/action/lifecycle, add two compact buttons without changing existing slider/button positions. Preserve choices across suite restoration.
- [x] Run all native suites, Python/build checks, review, docs and GitHub publication with content verification.

Constraints: no protected source copied, no forged gem collect, no shortened hold, no reward/spin spending, no Delta script writes. Detours never override immediate escape checks. Maximum extra straight-line distance: gem 12 studs, revive 20; search distance gem36/revive48. Skip urgency>=0.65, finish<8, or insufficient round time (+1.5 sec margin). Each leg and stationary hold must retain threat clearance and geometry checks.

Final verification: 36 suites, 428 Core checks, 16 Python tests. Native cancellation reply and select/act hold retention tested. Review: no blocking findings; local rescue budget counts Finish attempts conservatively. Two initial input fixture failures resolved in focused/final full reruns without production input changes. GitHub publication verified separately.
