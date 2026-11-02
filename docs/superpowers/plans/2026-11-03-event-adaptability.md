# Event adaptability implementation plan

Goal: implement the user's approved understanding check: player-list obstruction handling, smooth quick camera facing, mode-gated Pumpkin Hunt fixes and survival improvements, relocated reachable stations with backoff, and conservative useful consumables.

Architecture: keep the existing native movement/planner and touch workflows. Add bounded camera yaw interpolation without delaying body/actions. Give Pumpkin Hunt an explicit NPC gaze and route threat scoring; mode remains Session.AdminMatchMode, verified against PumpkinPeopleClient. Broaden native station discovery, rank current reachable-height candidates and retain unreachable backoff. Close only an obstructing player list; other obstructions still block input. Derive consumable benefit from threats/timing and avoid unconfirmed repeated expenditure.

Constraints: no production Lua comments; touch only for injected UI; preserve profiles; optional settings unchanged; publish to the established GitHub main and stable loadstring, never Delta executable storage. The approved chat understanding check is the spec. This is an isolated copy of published afcaab95; publication is already authorized.

Tasks:
1. Write failing camera-smoothing and event facing/mode/survival tests. Add native state age and swept route checks where supported. Verify RED then implement and verify GREEN.
2. Write obstruction test for player list versus unrelated CoreGui. Implement temporary scoped player-list disable with restoration, leaving other UI blocking intact.
3. Write moved/duplicate-station and unreachable route regressions. Discover prompts outside old lobby subtree, prefer eligible locations, propagate exhausted route failures into bounded workflow backoff.
4. Write consumable policy and pending-ack regressions. Require a meaningful boost opportunity, safe predicted use, native availability, and no duplicate use while an earlier item request is pending.
5. Build and run Python plus relevant native fixtures through the preserving runner. One fresh final whole-change review; fix meaningful findings with regressions. Publish and verify exact raw source.

Ledger: investigation confirms native event detection uses AdminMatchMode, while current camera snaps and current event facing follows travel rather than NPC. Current station scanning prefers only Lobby.Interactables and returns first duplicate. Current Adrenaline policy can spend solely because a distant chaser target exists or urgency is high. Investigation and RED tests in progress.

Steering and findings:
- Auto Fallen King added after explicit user request, then native melee on healing shrines requested and added. Native paid revival is never clicked. Boss schema/config/controls were decompiled read-only; isolated controller tests pass. Reviewer found stationary evasion, shrine arrival radius, disabled optional-facing attack ownership, and bridge elevation defects. All reproduced RED; fixes and GREEN focused run recorded in runtime fixtures.
- Real moving client bots have anchored render roots while native source:isActive() is true and pose() updates. Core filter now permits only native-confirmed active render bots; frozen humans remain excluded. Reproduced RED in core/audit fixture.
- User corrected visible crate interaction. Old regular CratePrompts are at Y~-318, but live HalloweenStore has a separate accessible ProximityPrompt and HalloweenShopEvent State/free + Bought. Added all free seasonal crate types with both fresh native free count and FREE label checks, no paid opening. Keep ordinary owned/free crate support.
- User requested AutoPumpkins toggle default off. Native Pumpkins panel Open / PumpkinEvent State/Opened / eight-touch PumpkinTap reveal integrated. Stop everything moved above Server status.
- Actual HeroChoice telemetry captured repeated blocker: 'current thread cannot access CoreGui (lacking capability Plugin)'. UI adapter now scopes executor UI thread identity around API calls and restores original context. Regression reproduces callback identity2 failure; native Heartbeat smoke result stored as HussHeartbeatTouchResult.
- Current active source is loaded through preserving test runner. Source builds at 61 registered fixtures. Full suite initial batches0..3 passed6 each before latest additions; must rerun final source appropriate suite. Current docs/publication still pending. Never overwrite settings or Delta executable; publish main afcaab95 expected head after verification.
