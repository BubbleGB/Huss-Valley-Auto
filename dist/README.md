# Executable and test artifacts

Use [src/auto-play.lua](../src/auto-play.lua) through the existing GitHub loadstring.
New versions are published to GitHub; no executable needs to be copied to Delta.

| Artifact | Purpose |
| --- | --- |
| [huss-auto-cross.txt](huss-auto-cross.txt) | Identical executable text for download |
| [huss-test-suite.txt](huss-test-suite.txt) | Self-contained fixtures; fetches the GitHub executable |
| [source-map.json](source-map.json) | Generated-line mapping to source units |
| [SHA256SUMS](SHA256SUMS) | Distribution checksums |

Core play starts running unless saved settings stop it. Optional features default
off. Stop everything pauses automation. Minimize and unload are in the top bar.
Build these artifacts with `python3 tools/build.py`.
