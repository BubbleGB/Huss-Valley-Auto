# Dashboard server status

Add one Dashboard paragraph showing script runtime, server uptime, humans/bots, chasers and runners. Refresh once per second independently of automation. Runtime resets on execution, uptime does not. Count current in-match roles, including visible native bots, excluding hidden/removed bots and lobby occupants; show human and bot totals separately.

Native session/workspace/game attributes and server browser current-row metadata expose no start timestamp. Official Workspace.DistributedGameTime docs describe client connection duration, not exact server age. Label it explicitly as the lower bound 'at least ... since you joined'; never present it as exact uptime. Production needs no extra remote requests, inputs, position or camera writes.

- [x] Isolated factory tests for count filtering/deduplication, pause-independent runtime, one-second cache, returned copy, long duration and truthful uptime labeling.
- [x] Bind Dashboard paragraph, test actual rendered status and validate current native counts.
- [x] Build/local/native checks; publish to existing GitHub main and verify exact executable.

Verified44/44Roblox suites,471Corechecks,16/16localPython tests andbuildchecks. Read-only review confirmed no new network/input/camera/movement actions and bounded one-second roster sampling.
