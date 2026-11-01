# Optional gems and revives

The panel has independent **Gems** and **Revives** buttons below Start/Stop. Both default off and only operate while the controller is started as an active runner in GroupRun, HeroRun or FinalRun. APIs: `SetAutoGemsEnabled(boolean)` and `SetAutoReviveEnabled(boolean)`.

Gems targets visible native `LocalRunnerGems` within 36 studs. It physically routes through their pickup area; no collection result or inventory update is forged. Collected gems still showing their reward animation are excluded.

Revives prefers a downed character with native RescueAvailable/Ragdolled flags and no competing helper. It approaches within native range, checks geometry and threats, sends Begin, stays still for the native HoldSeconds (currently 0.3 seconds), then sends Finish once. It cancels when danger, range, target, phase or controller state becomes invalid. Native Cancelled replies clear the hold and impose retry backoff. Stop/X and role/map changes cancel an unfinished hold. A Finish dispatch consumes the local crossing attempt budget (currently one), even if the server rejects it; this conservative limit avoids repeated rescue attempts. Native server validation remains authoritative.

Safe revives take priority over gems when both are enabled. Detours are skipped near the finish, at urgency 0.65 or above, when time cannot cover onward travel plus a 1.5 second margin, when either direct leg is obstructed, or when predicted chaser danger makes the approach/hold unsafe. Maximum added straight-line distance is 12 studs for gems and 20 for revives; revive search range is 48 studs. These conservative checks may skip reachable goals that would require a more complex detour. Default-off operation adds no gem/candidate scans.

These are independent implementations based on native game clients/configuration and the observed public feature descriptions. No TITANIC protected source was copied. Reward claims, wheel spins and saved configuration were not added in this release.

Validation: 36 Roblox suites / 428 Core checks, 16 Python tests and build/compile checks passed. Two earlier runs hit live input fixture failures (touch resumption and title drag); focused reruns and the final complete run passed with no input safeguard weakened. The comparison UI was temporarily hidden during the reruns and restored afterward. Native revive dispatch/timing is tested against an isolated remote fixture; live rewarded revives/gem pickup rates have not been measured.
