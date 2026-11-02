# Seasonal pickups and dashboard cleanup

The user requests automatic candy corn/pumpkin collection without a new toggle, optional coin collection if native pickups exist, gems retained, and Minimize/Unload only in the top bar.

Native evidence: LocalRunnerCandyCorn is a runner crossing layout with CandyCorn BillboardGui/Candy image. Collected images become hidden. CandyCorn.active() gates Halloween expiration. Pumpkin heads are automatically credited for native enemy breaks; head/coin flight is cosmetic. No ordinary world coin pickup client/config was found. Preserve existing Pumpkin Hunt bait/dodge behavior rather than chase cosmetic drops.

- [x] Extend existing safe detours with separately gated candy candidates, independent of Auto Gems. Keep threat/geometry/deadline vetoes and current gems/revives priority behavior.
- [x] Add visible/collected/hidden candy fixture and policy guards; remove Dashboard duplicate actions and verify actual visible button absence.
- [x] Run build, native suite with touch-only input, local tests; review changes, publish GitHub only and verify exact source.

Validation:43/43native suites,471Corechecks,16/16Python tests andbuildchecks. Pickup-specific runtime fixtures use isolated parts rather than moving the live character or issuing collection remotes.
