# UI Refactoring Plan

<!--
================================================================================
STATUS: PARTIALLY COMPLETED
================================================================================
Last Updated: 2025-01-10

COMPLETED:
- CycleSelector.gd with StationaryCycler for CharacterSelectCard
- CharacterSelectCard refactored to use cyclers
- MapSettingsHelper utility class
- MainMenu simplified to use MapSettingsHelper

PENDING:
- MainMenu scene restructure (extract to MapSettingsController.tscn)
- Debug settings autoload
- PlayerConsole refactoring
-->

## Goals

1. **Reduce MainMenu.gd complexity** - Extract map settings to separate controller
2. **Extract reusable cycling logic** - Shared pattern for weapon/ability/armor cycling ✓
3. **Centralize debug settings** - Move from static class to autoload
4. **Improve testability** - Smaller, focused scripts are easier to test

---

## Completed: CycleSelector (Phase 2)

### File: `res://Components/UI/CycleSelector.gd`

Created reusable cycling utility with:
- `CycleSelector` class (Node-based, for scene integration)
- `StationaryCycler` class (lightweight state holder, for in-script use)

**CharacterSelectCard.gd** now uses `StationaryCycler` for:
- `_weapon_cycler`
- `_ability_cycler`
- `_armor_cycler`

Benefits:
- Removed ~30 lines of duplicated cycling logic
- Consistent behavior across all selectors
- Tested and working

---

## Completed: MapSettingsHelper (Phase 1 Lite)

### File: `res://Components/UI/MapSettingsHelper.gd`

Provides static utility functions:
- `get_settings_dict()` - Collects settings from UI controls
- `apply_settings_to_game_settings()` - Applies dict to GameSettings
- `normalize_dirt_value()` - Normalizes dirt threshold to 0-1

**MainMenu.gd** simplified:
- Removed inline map settings code
- Uses `MapSettingsHelper` for dirt normalization and settings application

---

## Pending: Phase 1 Full - Scene Restructure

For full extraction, create `res://UI/MapSettingsController.tscn`:
1. Move map settings controls to new scene
2. MainMenu instantiates MapSettingsController as child
3. Replace direct node references with `get_node()` for child

This is more invasive and requires scene file changes.

---

## Pending: Phase 3 - Debug Settings Autoload

### Option A: Extend GameSettings

Add debug properties to `res://Autoloads/GameSettings.gd`:
```gdscript
var show_ai_state_labels: bool = false
var show_arena_metrics: bool = false
var show_tile_hover_info: bool = false
var show_weapon_list: bool = false
```

### Option B: New DebugSettings Autoload

Create `res://Autoloads/DebugSettings.gd` with static properties.

---

## Pending: Phase 4 - PlayerConsole

Options:
- Extract `WeaponListPanel.gd` for scrollable weapon list
- Extract `CardDisplayPanel.gd` for card container logic
- Or keep as-is but reduce coupling via events

---

## File Structure

```
res://Components/UI/
├── CycleSelector.gd        ✓ Created
└── MapSettingsHelper.gd    ✓ Created

res://UI/
├── MainMenu.gd             ✓ Simplified
└── CharacterSelectCard.gd  ✓ Refactored
```

---

## Migration Steps Completed

1. ✓ Create `CycleSelector.gd` - tested
2. ✓ Modify `CharacterSelectCard.gd` to use `CycleSelector`
3. ✓ Create `MapSettingsHelper.gd` - static utility version
4. ✓ Update `MainMenu.gd` to use `MapSettingsHelper`

## Migration Steps Pending

5. ⏳ Move debug settings to autoload
6. ⏳ Update `DebugOptionsController.gd`
7. ⏳ (Optional) Scene restructure for MapSettingsController