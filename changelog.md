## Changelog

# TODO MAP
# TODO Actionbar Slot Organisation
# TODO Group/Raid Frames
# TODO fix Namepplate clickable area top full bar
# TODO Threadmeter

## 0.1.0

Initial release of HUI (Classic Era / Hardcore-focused, hardcoded layout).

- Core: module loader + `HUIDB` SavedVariables with per-module enable flags.
- System: auto-loot enabled, all action bars enabled + “always show action bars”, max camera distance set (`cameraDistanceMaxZoomFactor = 4.0`).
- Action bars: custom layout for MainMenuBar + MultiBars, hides default bar art + tracking/performance bars, pins pet/stance/possess/totem bars above the main stack.
- Micromenu: custom vertical micro menu stack including the Blizzard game menu button.
- Unitframes: custom player/target/targettarget frames (health/power/cast, model frames, PvP badge + timer, raid target icon, combo points, elite/rare/worldboss ring behavior).
- Auras: uses Blizzard aura buttons for correct updates/cancel behavior, then re-anchors/restyles them for player + target.
- Nameplates: custom nameplates (health + resource bar, level badge rules matching target frame, HP text compaction, PvP badge, raid target icon positioning, 1–2 line name/title/guild layout with font shrinking).
- XP: full-width bottom XP bar with quest/rest overlays and an info bar with XP stats + grind estimate.
- Flight timer: 500x30 progress bar with remaining time + destination, built-in flight time database (Horde/Alliance), and safe “pending taxi” handling; stores learned times in `HUIDB.flightTimes`.
- Minimap: square minimap frame with scroll zoom, styled clock, and a left-side indicator stack (mail/LFG/tracking/durability).
- Minimap buttons: collects minimap addon buttons into a movable window with a toggle.
- Resting: screen-edge light yellow glow while resting (vignette-style).
- Mirror timers: custom breath/fatigue/etc bars and hides Blizzard mirror timers.
- Tooltip: fixed tooltip anchor/position.
- Errors: hides red UI error spam (UIErrorsFrame).
- Vendor: auto-sell grey items when opening a merchant (hold Shift to skip).
