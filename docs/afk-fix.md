# AFK reporter and touch input

While automation and Anti-AFK are enabled, the controller selectively holds connections owned by the native IdleReportClient. It preserves foreign and already disabled handlers, rescans for late reporters and restores only the connections it held on Stop/Destroy. AntiAFKReport reports effective enablement and ownership status.

Synthetic input uses only a stationary touch Begin/End on the controller's inert IDLE pad. The first pulse is scheduled after one second, subsequent pulses after one minute. The pad has no gameplay or drag handler. No keyboard, mouse or VirtualUser input is emitted. Roblox menu, typing, existing touches, hidden UI, obstructing GUI or unavailable safe hit testing defer a pulse. Logical GUI coordinates are converted using the current GUI inset at Begin; End uses the same captured coordinates. Stop and toggle-off finish pending touch and hide the pad.

Native AFK controls remain locked only while enabled and are restored on Stop. Idled schedules a touch check rather than emitting an immediate world input. MCP's independent VirtualUser idle guard was disabled during verification and remains disabled in this client.

The 2026-11-01 full run passed all 40 Roblox suites. Isolated touch ownership, obstruction, inset conversion and cleanup checks passed, together with real native reporter/control restoration. Actual UI touch dragging and slider release passed without camera/player pose changes beyond resting noise. No full 20-minute idle interval was tested.
