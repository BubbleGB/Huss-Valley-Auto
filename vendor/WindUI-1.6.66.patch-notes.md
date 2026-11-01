# WindUI 1.6.66 compatibility adapter

The MIT upstream asset `WindUI-1.6.66.lua` remains unchanged (274078 bytes). `src/runtime/wind-compat.lua` transforms its source in memory before compilation. The adapter belongs to this integration, not upstream.

The adapter checks the pinned byte count, exact source anchors and occurrence counts, then requires only one direct `:Connect(` to remain: the connection inside `Creator.AddSignal`. Any mismatch raises an initialization error and triggers transactional cleanup before executing library code.

All 24 other direct connection sites route through `Creator.AddSignal`. This covers window dragging; top-level input ownership; scrollbar dragging; toggle dragging; slider RenderStepped/InputEnded during active dragging; keybind capture; color picker input; tooltip mouse movement; camera property changes; and GUI instance signals. Existing widget-local disconnects still work. `Creator.DisconnectAll` removes signals in reverse order so array removal cannot skip adjacent entries.

An owner object is available before library execution. Cleanup marks it closed and synchronously disconnects its Creator registry, including when initialization fails after library callbacks are registered. Late additions disconnect immediately. This affects only connections created by this library instance; production does not enumerate game connections, require `getconnections`, or hook signal methods/metamethods.

The integration clears window callbacks before destroying an incomplete window, and callback guards ignore cleanup. No fallback panel is created. Minimized state is maintained by the library's open/close callbacks; Refresh does not poll the delayed `Window.Closed` flag.

Native regression tests verify failure after first Tab creation, actual saved connection objects disconnected on initialization failure, same-length anchor drift rejection, immediate Refresh during Restore, unload during active slider drag, and preservation of an unrelated input connection. Test-only connection inspection uses the executor's `getconnections` API. Each library instance compiles with a unique diagnostic chunk name `HussWindUI_1_6_66_<GUID>`; tests derive its exact executor-prefixed source from Creator.AddSignal and freshly enumerate all live global functions from that scope, including connections outside its registry. Saved actual Creator RBXScriptConnections must all be disconnected. Unrelated handlers registered both before and after UI initialization and a concurrent independent library instance must remain connected.

Owned ScreenGuis receive LightsOutKeep before parenting to PlayerGui, permitting cleanup under ordinary thread identity. SliderContainer is the active touch receiver; SliderIcon remains passive. No synthetic desktop input is used.
