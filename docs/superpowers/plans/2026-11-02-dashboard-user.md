# Dashboard user card

Add a read-only WindUI Dashboard card with a circular native headshot, @username, level, wins, catches, current role and LMS. Native leaderstats provides Level/Wins/Catches/LMS; Level attribute is a fallback while stats load. LeaderboardConfig Boards.LMS.Title explicitly says LAST MAN STANDING. Expand the label without inventing stat meanings. Map native Catcher role to Chaser.

Use one-second cached reads, show missing data as unavailable instead of invented zeros, and keep card updates running while automation is stopped. Use a native rbxthumb AvatarHeadShot image with circular UICorner, no live camera, input or pose changes. No extra gameplay remotes or files.

- [x] Isolated tests: current identity/stats, role mapping, live changes, missing/late leaderstats, level fallback, independent copied reports, headshot URI.
- [x] WindUI card/circular image and actual GUI fixture checks; register source/test units.
- [x] Native/local/build verification, publish to existing GitHub and verify exact executable.

Validation:45/45native suites,471Corechecks,16/16localPython tests and build checks. Native leaderstats at inspection contained Level24/Wins48/Catches110/LMS8. Card verification reads current values rather than hardcoding that sample. Read-only code review confirmed no new input/camera/movement or gameplay remote behavior.
