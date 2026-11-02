# Optional gems and revives

Collection contains **Collect Gems**; Runner contains **Revive runners**. These are independent toggles. Both default off and only operate while the controller is started as an active runner in GroupRun, HeroRun or FinalRun. APIs: `SetAutoGemsEnabled(boolean)` and `SetAutoReviveEnabled(boolean)`.

Gems targets visible native `LocalRunnerGems` within 36 studs. It physically routes through their pickup area; no collection result or inventory update is forged. Collected gems still showing their reward animation are excluded.

Revives prefers a downed character with native RescueAvailable/Ragdolled flags and no competing helper. It approaches within native range, checks geometry and threats, sends Begin, stays still for the native HoldSeconds (currently 0.3 seconds), then sends Finish once. It cancels when danger, range, target, phase or controller state becomes invalid. Native Cancelled replies clear the hold and impose retry backoff. Stop/X and role/map changes cancel an unfinished hold. A Finish dispatch consumes the local crossing attempt budget (currently one), even if the server rejects it; this conservative limit avoids repeated rescue attempts. Native server validation remains authoritative.

Safe revives take priority over gems by default; the Priorities category can swap their order. Detours are skipped near the finish, at urgency 0.65 or above, when time cannot cover onward travel plus a 1.5 second margin, when either direct leg is obstructed, or when predicted chaser danger makes the approach/hold unsafe. Maximum added straight-line distance is 12 studs for gems and 20 for revives; revive search range is 48 studs. These conservative checks may skip reachable goals that would require a more complex detour. Default-off operation adds no gem/candidate scans.

These are independent implementations based on native game clients/configuration and the observed public feature descriptions. No TITANIC protected source was copied. Reward claims and wheel spins are not automated. Settings profiles are described in the UI guide.

Validation: the current full run passed 40 Roblox suites / 446 Core checks and 16 Python tests. Native revive dispatch/timing uses an isolated remote fixture; rewarded live pickup/revive rates have not been measured.

The **Collect Seasonal Currency** toggle in Collection uses the same checked runner detour policy for Candy Corn, independently of Collect Gems, and defaults on. It reads the native LocalRunnerCandyCorn layout only while the native Halloween currency/config is active, and ignores hidden or already-collected icons. Gem collection behavior remains controlled by the existing Gems toggle. Pumpkin Hunt heads and restricted-mode coins are native break rewards, not ground pickups to chase.

Gem and seasonal-currency routes only advance along the crossing axis. Passing a pickup, collecting it, disabling its toggle, or finding the forward route blocked abandons the target instead of turning back. Normal threat avoidance and revive policy are separate.
