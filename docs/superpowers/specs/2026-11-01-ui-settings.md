# Accepted scope update — 2026-11-01

The user's subsequent instructions supersede earlier fallback/camera/input details below: remove the native panel and backend switch entirely; fail transactionally if WindUI cannot initialize; default camera follow and continuous body facing off; allow only necessary native dive aim rotation; use touch-only synthetic input on a checked owned sink. All owned library ScreenGuis live in PlayerGui for ordinary-thread cleanup. Obsolete panel/fallback fixtures are retired; speed coverage is migrated and touch/camera coverage added. Final verification passed 40 Roblox suites / 446 Core checks, 16 Python tests and build checks. Implementation and read-only review are complete.

---

# Categorized WindUI settings

User intent: replace cramped panel with a clean, functional library UI; expose map voting, hero/chicken threshold, task ordering and other meaningful toggles; keep touch/mouse dragging, minimize/restore, Start/Stop/X.

Chosen approach: pinned WindUI 1.6.66 (MIT, 274078 byte library asset) loaded separately from a vendored GitHub path or pinned official release. A local native fallback remains available if library loading fails. Avoid coupling safety and gameplay to the UI library. Library runtime under Delta was verified earlier in this session. Alternatives: rebuilding all native widgets costs more bespoke UI code; another untested library has no established Delta evidence. User explicitly delegated choosing/designing/implementing, so proceed directly.

Categories: Dashboard, Runner, Chaser, Priorities, Voting & Roles, Movement, Diagnostics. Dark teal theme, compact persistent status, touch-friendly sliders/dropdowns, minimize badge and keyboard restore. All controls must call validated APIs and reflect external/API changes without callback recursion. Minimize preserves operation; Close unloads and restores owned hooks/input. Native fallback must expose Start/Stop/restore even on library errors.

Settings defaults preserve behavior: AutoRun/AutoChase/AutoDash/AutoDive/AutoMelee/UseAbilities/AntiAFK/AutoVote/AutoSelectRunner/FollowCamera/AutoFaceTarget true; MapPreference Random; HeroMode Auto; HeroThreshold 5; Priorities Escape, Revives, Gems, Catches. Existing speed, Smart Speed, TP Assist, Gems, Revives and Info API remain authoritative. No mode selector: runner/chaser stays automatic. HeroMode can force Hero/Chicken; Auto compares active chasers to configurable threshold. Map voting resolves current native option IDs and never votes unavailable choices.

Priority semantics: rank eligible tasks, never perform an unavailable task for the current role. Catches applies as chaser; gems/revives as runner. Ordinary crossing is runner fallback. Escape rank controls whether optional goals can take precedence under moderate pressure; immediate danger, physical obstacles and insufficient timer always veto unsafe detours. Under clear conditions, enabling extras still allows small safe detours even if Escape ranks first. Each priority list is a permutation, and UI slot changes swap existing entries.

Scope: implement meaningful toggles above, configurable map/hero/prompts, priority policy, clean library UI, fallback/lifecycle and tests. No reward spending or new game exploit mechanics. GitHub-only version delivery; unchanged loadstring. Pin vendor attribution/version, no user secrets in repository. Diagnostics stay bounded and no new per-frame world scans.
