# Crossing evidence and reactions implementation plan

Goal: explain failed crossings with recent observations and refresh routes promptly when danger changes.
Architecture: reuse 30 Hz action snapshots; request a full plan on the next eligible frame with a 1/30-second floor. Keep ordinary 100 ms cadence. Record bounded observations, never assert an unconfirmed cause.
Scope: the two recommended first priorities; other proposed optimizations wait for evidence. User authorized implementation and GitHub publication.

- [x] Add failing core/runtime tests for nearby ability starts, new hazards, displacement, obstacle blockage, distant/unchanged threats, throttling, immutable bounded history, stop/reset and stale evidence.
- [x] Implement pure snapshot/danger comparison helpers and lifecycle recording (20 samples, 0.1 s spacing, last 30 crossings).
- [x] Integrate early plan requests into existing fast checks; invalidate route cache on reactive refresh; preserve immediate steering and geometry safeguards.
- [x] Run focused tests then all Roblox/Python suites and generated build checks. Review diff, publish all changed files atomically, verify GitHub head and executable bytes.

Review focus: distant event floods must not accelerate planning; expired/stopped contexts must not leak samples; returned reports must not mutate internal state; role/map changes must reset requests; observations must not claim causation.

Verification: 33 Roblox suites, 415 Core checks, 16 Python tests. Independent review found projectile projection refreshes and stale dash evidence; both reproduced with failing tests and corrected. Publication/head verification recorded separately after upload.
