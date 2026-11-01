# Accepted scope update — 2026-11-01

The user's subsequent instructions supersede earlier fallback/camera/input details below: remove the native panel and backend switch entirely; fail transactionally if WindUI cannot initialize; default camera follow and continuous body facing off; allow only necessary native dive aim rotation; use touch-only synthetic input on a checked owned sink. All owned library ScreenGuis live in PlayerGui for ordinary-thread cleanup. Obsolete panel/fallback fixtures are retired; speed coverage is migrated and touch/camera coverage added. Final verification passed 40 Roblox suites / 446 Core checks, 16 Python tests and build checks. Implementation and read-only review are complete.

---

# Categorized settings and UI implementation plan

Goal: expose validated functional automation settings through a polished categorized UI.
Spec: docs/superpowers/specs/2026-11-01-ui-settings.md

- [ ] Task 1: implement/test settings and policies independently of UI: runtime/settings + core/settings; wire prompt/map/hero selection, detour ranks, ability/action/camera/antiAFK/role toggles. Preserve defaults and public legacy APIs.
- [ ] Task 2: replace visible native panel with pinned WindUI tabs, bound to APIs; adapt diagnostics/detour UI bindings; native fallback and transactional cleanup; keyboard/minimized badge, mouse/touch dragging; UI-specific fixtures updated to actual adapter.
- [ ] Task 3: integrated native tests including dropdowns, callbacks, priority order, minimize/restore/close/reload, fallback and hook restoration; build/Python checks; independent review; docs/publish/verify source/head.

Review focus: zero side effects on UI initialization; canceled callbacks after Destroy; no conflicting UI/native state; unknown map options; duplicate priorities; native UI hidden by event; minimized controls remain accessible; library load failure restores native hooks.
