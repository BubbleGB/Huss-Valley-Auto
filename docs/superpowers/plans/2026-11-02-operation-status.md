# Operation status

Rename Dashboard Controller status to Operation status. Always show Running or Stopped, plus the actual current action/target. Keep raw API.Status compatible; visible status uses structured fresh events with bounded lifetime and explicit priority.

Cover crossing, collection item, revive target, chase target, current evasive threat/hazard, checked obstacle/unsafe-ground avoidance, native dash/dive/melee/ability/consumable requests, TP assistance, native map/role choices, equipment changes and reward workflows (polling/claiming/spinning/free crate requests and replies). Show pending confirmation distinctly; never claim a catch/reward succeeded just because it was requested. No invented enemy identity or obstacle type.

Use a fixed four-channel display state (avoidance, combat, progression, prompt), monotonic short TTLs and stopped/context filtering. No additional world scans/raycasts/remotes/input. Diagnostics retain counts and details. Pausing clears events; late old combat replies cannot overwrite newer work.

- [x] Isolated status priority/expiry/stopped/correlation tests RED then implement aggregator.
- [x] Instrument existing decisions/requests/replies only; verify display evidence with native-shaped fixture replies and actual UI assertions.
- [x] Local/native suite, focused review, publish GitHub and verify source.

Validation: focused operation/progression30/threat/UI checks and full final47/47native suites passed (479Corechecks);16/16Python tests andbuildchecks passed. Reset/late-reply and malformed/unloaded confirmation regressions observed RED then GREEN. Read-only review found no important issues; native SpinWheelClient State.result/results/message and CrateClient Result.id/crate shapes confirmed by read-only decompilation. No live rewards were spent to validate status.
