# HUI
Hase UI (HUI) is a lightweight World of Warcraft Classic (Hardcore) UI addon focused on speed and simplicity.

## Features
- Actionbar layout tweaks (moves primary bars, hides some default art)
- Micromenu layout (position + scale)
- Per-element toggles: switch each element between Blizzard and HUI

## Install
1. Close WoW.
2. Copy the `HUI` folder into:
   - `World of Warcraft/_classic_era_/Interface/AddOns/`
3. Launch WoW and enable `HUI` at the character select AddOns button.

## Usage
Reload the UI (useful after making lots of changes):
- Run `/reload`.

## Options
HUI is hardcoded: there is currently no in-game options UI.

## Saved variables
HUI stores settings in:
- `HUIDB` (SavedVariables)

## Notes / Compatibility
- Designed for WoW Classic Era (Hardcore).
- Actionbar changes are restricted by WoW’s combat lockdown rules; HUI defers some updates until you are out of combat.
- If another addon also moves/hides the same Blizzard frames, load order and conflicts may affect results.

## Support / Development
- This addon is intentionally minimal; requests should include screenshots and your desired layout/behavior.
