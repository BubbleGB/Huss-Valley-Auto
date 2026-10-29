# Dive interception revision

User requests more frequent dives at predicted runner positions, especially
close targets with consistent velocity direction, and authorizes choices.

- [x] Native geometry fixtures first: later but reachable contact, lateral lead,
  close consistent chase, unreachable/high-speed targets, changing motion,
  protected/evasive targets, blocked paths, melee priority and retry timing.
- [x] Add bounded native-trajectory lead search with centered-contact margins,
  acceleration-aware target paths and independent direction stability. Keep
  legacy generic geometry fallbacks for existing helper callers.
- [x] Replace fixed 7.5-stud/early-contact gates in the native path. Use 0.14s
  direction stability for close dives, 0.25s for wider predictions; retain
  short prediction horizons and collision/hazard clearance for full dive travel.
- [x] Reduce added four/two-second spacing to native cooldown/recovery plus
  0.15s close or 0.35s predicted margin. Keep native server validation and
  overlapping-attack restrictions. Bound failed local request retries.
- [x] Full native-client suite and review, observe eligible ordinary gameplay,
  document evidence/limits, overwrite and verify Delta source/test bundle,
  restore all UI/toggle/speed/running settings.

More accepted dive opportunities do not prove a higher catch rate. No hitboxes,
native cooldowns, movement caps or remote validation rules are changed.

Verification: native policy17checks; actual runtime old-source RED/new-source
GREEN. Review heading-authority finding RED then GREEN. Saved bundle25suites,
331 Core checks, zero failures plus runtime assertions. Exact Delta source and
bundle readback passed; all settings restored. Ordinary runner observation had
no controller errors and nine dash requests. Subsequent chaser observation
recorded an accepted close dive with no rejection; first simulation24.927ms,
reply125.734ms. Catch-rate improvement is not asserted.
