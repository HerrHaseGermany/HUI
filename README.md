# HUI

HUI (Hase UI) is a lightweight World of Warcraft Classic Era UI addon focused on speed, simplicity, and a fixed “HC-ready” layout.

It’s intentionally minimal: no config UI and no big dependencies. Most layout is controlled by constants in `src/*.lua`.

## Compatibility

- WoW Classic Era (Interface: `11508`)
- Designed with Hardcore in mind

## Install

1. Close WoW.
2. Copy the `HUI` folder into `World of Warcraft/_classic_era_/Interface/AddOns/`.
3. Launch WoW and enable `HUI` at character select (**AddOns**).

## Quick Start

- If something looks “stuck” after changes: run `/reload`.
- HUI sets a few default CVars automatically (auto-loot, show all bars, always show action bars, max camera distance).

## What HUI Changes (User Guide)

### Unitframes (`src/unitframes.lua`)

- Replaces the Player / Target / TargetTarget frames with a custom layout (health/power/cast, model frames).
- Shows PvP badge and a PvP timer.
- Shows target raid marker and custom combo point display.
- Uses Blizzard aura buttons (so buffs update/cancel correctly in combat), but repositions/restyles them to match HUI.
- Applies rare/elite/worldboss visual behavior on the target level ring.

### Nameplates (`src/nameplates.lua`)

- Custom nameplates with:
  - Health bar + thin resource bar underneath
  - Threat meter bar on top (shows your threat vs that unit; fill = `scaledPercent` 0–100, color = Blizzard threat status)
  - Level badge rules aligned with the target frame
  - HP text compaction (k/M formatting) to prevent overflow
  - PvP badge + raid marker positioning
  - Friendly player guild / friendly NPC title support with auto font shrinking (prevents overlap)

### Actionbars (`src/actionbars.lua`)

- Repositions Blizzard action bars (MainMenuBar + MultiBars) into a fixed stack.
- Hides Blizzard actionbar art and the small performance/tracking bars around the action bar area.
- Pins pet/stance/possess/totem bars above the main stack (when they appear).

### Micromenu (`src/micromenu.lua`)

- Custom vertical micro menu stack.
- Uses the real Blizzard game menu button (to avoid taint/blocked calls) and skins it to match.

### XP Bar (`src/xpbar.lua`)

- Full-width XP bar along the bottom with rested + quest overlays.
- Info bar above it with XP stats and a grind estimate from recent kills.

### Resting Indicator (`src/restingindicator.lua`)

- Adds a subtle, vignette-style light yellow screen glow while resting.

### Flight Timer (`src/flighttimer.lua`, `src/flightdata.lua`)

- Flight progress bar with remaining time centered and destination on the right.
- Built-in flight time database (Horde + Alliance).
- Learns/stores observed times in `HUIDB.flightTimes`.

### Minimap (`src/minimap.lua`)

- Square minimap frame with scrollwheel zoom and a styled clock.
- Re-docks common minimap indicators (mail / LFG / tracking / durability) around the minimap frame.

### Minimap Button Collector (`src/minimapbuttons.lua`)

- Collects addon minimap buttons into a movable window (so the minimap stays clean).

### Mirror Timers (`src/mirrortimers.lua`)

- Custom breath/fatigue/etc timer bars and hides Blizzard mirror timers.

### Tooltip + Errors (`src/tooltip.lua`, `src/errors.lua`)

- Tooltip anchored to a fixed position.
- Red UI error spam hidden (UIErrorsFrame).

### Vendor QoL (`src/autosell.lua`)

- Auto-sells grey items when opening a merchant.
- Hold **Shift** while opening the vendor to skip auto-selling.

## Customization (Hardcoded)

HUI is configured by editing constants in source files:

- Actionbar layout / button size / spacing: `src/actionbars.lua`
- Unitframe sizes/positions + aura layout: `src/unitframes.lua`
- Nameplate sizes/colors/text rules: `src/nameplates.lua`
- XP bar behavior: `src/xpbar.lua`
- Minimap size/position + indicator docking: `src/minimap.lua`
- Flight timer visuals/position: `src/flighttimer.lua`

## Saved Variables

- `HUIDB` (SavedVariables)
  - Used for persistent state (notably `flightTimes`) and per-module enable flags.

## Notes / Limitations

- WoW combat lockdown applies: some frame operations cannot run while in combat; HUI generally re-applies layout when leaving combat.
- If another addon also moves/hides the same Blizzard frames, conflicts can happen depending on load order.
