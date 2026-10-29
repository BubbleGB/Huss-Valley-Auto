# AFK reporter and input recovery

The native IdleReportClient forwards LocalPlayer.Idled directly to PlayerPreferences. The prior controller had emitted virtual touches but still observed an idle event, so its late input response did not stop that report.

While enabled, the controller selectively disables connections owned by the actual IdleReportClient instance. It leaves foreign handlers and pre-disabled connections unchanged and restores only its held connections on Stop/Destroy. A five-second scan covers late loading or re-enabled reporters. This requires executor connection inspection; AntiAFKReport exposes whether the reporter was actually held.

An independent, paired F15 input runs every 45 seconds when not typing, touching or in the Roblox menu, even if no empty touch point exists. A pending release is retried before another pulse and during Stop. The existing minute touch pulse and Roblox Idled VirtualUser response remain.

Validation on 2026-10-29: 28 suites passed, 356 Core decision checks, no failures. Reporter ownership, re-enabling, cleanup and partial key-up failure regressions were verified RED/GREEN. The connected client confirmed one native reporter held, successful real touch and key pulses, and exact reporter restoration on Stop. A full 20-minute Roblox idle-kick interval has not been tested.
