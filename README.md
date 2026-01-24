# HUI
Hase UI (HUI) is a lightweight World of Warcraft Classic (Hardcore) UI addon focused on speed and simplicity.

## Features
- Custom unitframes: Player, Target, and TargetTarget
- Actionbar layout tweaks (moves primary bars, hides some default art)
- Custom minimap container (position + size)
- Chat layout (position + size) and hides some default chat buttons
- Micromenu layout (position + scale)
- Per-element toggles: switch each element between Blizzard and HUI
- In-game options panel for editing positions/sizes/scales

## Install
1. Close WoW.
2. Copy the `HUI` folder into:
   - `World of Warcraft/_classic_era_/Interface/AddOns/`
3. Launch WoW and enable `HUI` at the character select AddOns button.

## Usage
Open the options panel:
- `/hui`

Reset HUI settings to defaults:
- `/hui reset`

Reload the UI (useful after making lots of changes):
- Click `Reload UI` in the HUI options panel, or run `/reload`.

## Options
Find HUI at:
- `Esc` → `Options` → `AddOns` → `HUI`

### Enable/disable modules
Each major element can be toggled independently:
- Custom Unitframes
- Custom Actionbars
- Custom Minimap
- Custom Chat
- Custom Micromenu

When a toggle is disabled, HUI attempts to restore Blizzard positioning/visibility for that element.

### Layout editing
The options panel lets you edit:
- Global scale
- Unitframe positions and sizes (player/target/targettarget)
- Minimap position and size
- Chat position and size
- Actionbars position and scale
- Micromenu position and scale

Edits apply immediately. Some secure UI pieces (notably actionbars) may only fully update after leaving combat.

## Saved variables
HUI stores settings in:
- `HUIDB` (SavedVariables)

## Notes / Compatibility
- Designed for WoW Classic Era (Hardcore).
- Actionbar changes are restricted by WoW’s combat lockdown rules; HUI defers some updates until you are out of combat.
- If another addon also moves/hides the same Blizzard frames, load order and conflicts may affect results.

## Support / Development
- This addon is intentionally minimal; requests should include screenshots and your desired layout/behavior.
