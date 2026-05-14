# UI System Reference Guide

<!--
================================================================================
VERSION CONTROL
================================================================================
Document Version: 1.0
Last Synced:     2025-01-10
Godot Version:   4.2+

SYNC RULE: When modifying UI components (add/remove/modify signals, properties,
methods, or visual elements), update this document in the same commit.

VERSION LOG:
  v1.0 (2025-01-10) - Initial documentation
================================================================================
-->

## Overview

The UI system provides all user interface elements for the game, including the main menu, in-game HUD, display cards, quest tracking, and debug tools. It uses a component-based architecture with centralized styling via `UIStyle`.

---

## Architecture Diagram

```
UI System
├── res://UI/
│   ├── UIStyle.gd                    - Centralized styling constants & functions
│   ├── MainMenu.gd/.tscn             - Character/equipment selection, map settings
│   ├── PlayerConsole.gd/.tscn        - In-game weapon list and card display
│   ├── CharacterSelectCard.gd/.tscn - Individual character selection card
│   ├── EquipmentInventory.gd/.tscn   - Weapon grid in main menu
│   ├── DebugOptionsController.gd/.tscn - Debug toggle checkboxes
│   ├── ControlsPanel.tscn            - Static control reference panel
│   └── DisplayCard/
│       ├── DisplayCardBase.gd        - Base class for all display cards
│       ├── WeaponCard.gd/.tscn       - Weapon display card
│       ├── AbilityCard.gd/.tscn      - Ability display card
│       └── ActorCard.gd/.tscn        - Actor/Goat display card
├── res://Play Space/
│   ├── OptionsMenu.gd/.tscn          - In-game pause menu with volume/goat color
│   └── Arena.tscn (references)
│       └── ArenaUIHandler.gd         - Arena HUD management component
├── res://Components/Arena/
│   └── ArenaUIHandler.gd             - Target label, reticle, actor switching
├── res://Player/
│   └── Reticle.gd                    - Custom crosshair cursor
├── res://QuestSystem/
│   ├── QuestBoardUI.gd               - Modal quest board overlay
│   └── QuestTrackerHUD.gd/.tscn      - Active quest display HUD
└── Autoloads Used by UI:
	├── ItemsAutoload                 - Weapons, selected weapon/ability/actor
	├── GameSettings                  - Player preferences, character loadout
	├── HerdManager                   - Goat selection management
	├── QuestState                    - Quest tracking
	└── QuestEvents                   - Quest signals
```

---

## Central Styling: UIStyle.gd

**File:** `res://UI/UIStyle.gd`

Provides centralized color constants and StyleBoxFlat creation for consistent UI theming.

### Color Constants

| Constant | Color | Usage |
|----------|-------|-------|
| `COLOR_BG_MAIN` | `(0.055, 0.06, 0.075, 0.98)` | Main panel backgrounds |
| `COLOR_BORDER_MAIN` | `(0.90, 0.68, 0.25, 0.94)` | Gold border accent |
| `COLOR_BG_CARD` | `(0.08, 0.085, 0.11, 0.94)` | Card backgrounds |
| `COLOR_BORDER_CARD` | `(0.46, 0.36, 0.18, 0.88)` | Card borders |
| `COLOR_TEXT_GOLD` | `(1.0, 0.86, 0.32)` | Gold text |
| `COLOR_TEXT_BLUE` | `(0.65, 0.86, 1.0)` | Blue informational text |
| `COLOR_TEXT_CREAM` | `(0.82, 0.80, 0.72)` | Default cream text |

### Style Creation Functions

| Function | Returns | Description |
|----------|---------|-------------|
| `make_main_panel_style()` | StyleBoxFlat | Main panel with gold border, 12px corners |
| `make_card_style()` | StyleBoxFlat | Card style with softer border, 8px corners |
| `make_button_normal_style()` | StyleBoxFlat | Normal button state |
| `make_button_hover_style()` | StyleBoxFlat | Hover button state |
| `make_button_pressed_style()` | StyleBoxFlat | Pressed button state |
| `apply_button_theme(btn: Button)` | void | Applies all button styles to a button |

---

## Main Menu: MainMenu.gd

**File:** `res://UI/MainMenu.gd`  
**Type:** `Control`  
**Scene:** `res://UI/MainMenu.tscn`

Handles character selection, equipment configuration, and map generation settings.

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `selected_actor_path: String` | String | Path to selected actor scene |
| `CHARACTER_EQUIPMENT: Dictionary` | Dictionary | Equipment loadouts per character |
| `character_cards: Dictionary` | Dictionary | Map of actor_name -> CharacterSelectCard |
| `selected_character: String` | String | Currently selected character type |

### Actor Scene Mapping

```gdscript
const ACTOR_SCENES: Dictionary = {
	"farmer": "res://scenes/actors/FarmerActor.tscn",
	"fire": "res://scenes/actors/FireActor.tscn",
	"water": "res://scenes/actors/WaterActor.tscn",
	"goat": "res://scenes/actors/GoatActor.tscn",
	"goblin": "res://scenes/actors/GoblinMinion.tscn",
	"scarecrow": "res://scenes/actors/ScarecrowDummy.tscn"
}
```

### Key Methods

| Method | Description |
|--------|-------------|
| `_populate_character_cards()` | Creates character selection cards dynamically |
| `_on_character_selected(actor_name)` | Updates selection state on click |
| `_on_equipment_changed(...)` | Saves equipment selection to GameSettings |
| `_on_play_button_pressed()` | Finalizes settings and transitions to Arena |

---

## Player Console: PlayerConsole.gd

**File:** `res://UI/PlayerConsole.gd`  
**Type:** `CanvasLayer`  
**Scene:** `res://UI/PlayerConsole.tscn`

In-game HUD showing weapon list, display cards, and debug toggles.

### Key Node References

| Node | Type | Description |
|------|------|-------------|
| `weapon_list` | VBoxContainer | Weapon name labels |
| `weapon_card` | WeaponCard | Selected weapon display |
| `ability_card` | AbilityCard | Selected ability display |
| `actor_card` | ActorCard | Controlled actor display |
| `debug_list_toggle` | CheckBox | Toggle debug list visibility |
| `cards_toggle` | CheckBox | Toggle cards visibility |

### Keyboard Controls

| Key | Action |
|-----|--------|
| `Q` | Cycle to previous weapon |
| `E` | Cycle to next weapon |

### Key Methods

| Method | Description |
|--------|-------------|
| `_cycle(direction)` | Cycles through weapons array |
| `_on_weapon_selected(weapon)` | Updates list highlights and card display |
| `_update_weapon_card_from_character()` | Sets initial weapon from GameSettings |

---

## Character Select Card: CharacterSelectCard.gd

**File:** `res://UI/CharacterSelectCard.gd`  
**Type:** `Control`  
**Scene:** `res://UI/CharacterSelectCard.tscn`

Individual character card in the main menu for selection and equipment configuration.

### Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `character_selected` | `actor_name: String` | Emitted when card is clicked |
| `equipment_changed` | `actor_name, weapon_index, ability_index, armor_index` | Equipment changed |

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `actor_name: String` | String | Character type identifier |
| `is_selected_card: bool` | bool | Selection visual state |
| `current_weapon_index: int` | int | Selected weapon index |
| `current_ability_index: int` | int | Selected ability index |
| `current_armor_index: int` | int | Selected armor index |

### Key Methods

| Method | Description |
|--------|-------------|
| `setup(...)` | Initializes card with character data |
| `cycle_weapon()` | Cycles through weapons |
| `cycle_ability()` | Cycles through abilities |
| `cycle_armor()` | Cycles through armor |
| `get_selected_equipment()` | Returns equipment indices dict |

---

## Display Card System

### Base: DisplayCardBase.gd

**File:** `res://UI/DisplayCard/DisplayCardBase.gd`  
**Type:** `PanelContainer`

Base class for all display cards with selection and hover behavior.

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `highlight_color` | Color | `(0.8, 1.0, 0.8)` | Selected state color |
| `base_color` | Color | WHITE | Default color |
| `hover_color` | Color | `(0.9, 0.9, 0.9)` | Hover state color |
| `data_resource` | Resource | null | Data being displayed |

### Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `selected` | `data: Resource` | Card was clicked |

---

### WeaponCard

**File:** `res://UI/DisplayCard/WeaponCard.gd`

Displays weapon information with equip functionality.

### Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `equipped` | `weapon: WeaponData` | Weapon was equipped |

### Key Features
- Displays ammo if `weapon_data.max_ammo > 0`
- Shows notes/description if available
- Visual feedback when weapon is selected

---

### AbilityCard

**File:** `res://UI/DisplayCard/AbilityCard.gd`

Displays ability information (name, icon, description, usage).

---

### ActorCard

**File:** `res://UI/DisplayCard/ActorCard.gd`

Displays actor/character information with stats and selection.

### Key Features
- Supports both `GoatData` resource and runtime `Actor` nodes
- Editable name via LineEdit
- Status indicators: `[P]` pregnant, `[E]` exhausted

### Key Methods

| Method | Description |
|--------|-------------|
| `set_actor(p_actor)` | Sets runtime actor to display |
| `_toggle_arena_selection()` | Toggles arena selection via HerdManager |

---

## Options Menu: OptionsMenu.gd

**File:** `res://Play Space/OptionsMenu.gd`  
**Type:** `Control`

In-game pause menu with volume and goat color controls.

### Key Methods

| Method | Description |
|--------|-------------|
| `toggle()` | Shows/hides menu, toggles game pause |
| `_update_goat_controls()` | Shows goat color sliders when controlling a goat |

### Input Handling
- `ui_cancel` input closes menu and returns focus

---

## ArenaUIHandler.gd

**File:** `res://Components/Arena/ArenaUIHandler.gd`

Component that manages Arena UI elements.

### Key Properties

| Property | Type | Description |
|----------|------|-------------|
| `target_label` | Label | Shows current HP/Mana |
| `reticle` | Control | Custom crosshair cursor |
| `_current_actor` | Actor | Currently tracked actor |

### Key Methods

| Method | Description |
|--------|-------------|
| `setup(p_arena)` | Initializes handler with arena reference |
| `update_for_actor(actor)` | Updates UI to follow new actor |
| `update_ui_text()` | Updates HP/Mana label |
| `handle_game_over()` | Shows game over state |

---

## Quest UI

### QuestBoardUI

**File:** `res://QuestSystem/QuestBoardUI.gd`

Modal quest board overlay.

### Key Methods

| Method | Description |
|--------|-------------|
| `open_board()` | Opens the quest board modal |
| `close_board()` | Closes the quest board modal |
| `is_open()` | Returns whether board is visible |

---

### QuestTrackerHUD

**File:** `res://QuestSystem/QuestTrackerHUD.gd`  
**Scene:** `res://QuestSystem/QuestTrackerHUD.tscn`

Active quest display HUD.

### Key Methods

| Method | Description |
|--------|-------------|
| `_update_all()` | Refreshes quest display |
| `_show_message(text)` | Shows timed message |

---

## Debug Options: DebugOptionsController.gd

**File:** `res://UI/DebugOptionsController.gd`  
**Type:** `PopupPanel`

Static debug toggle states and UI controls.

### Static Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `show_ai_state_labels` | bool | false | Toggle AI state labels |
| `show_arena_metrics` | bool | false | Toggle arena metrics display |
| `show_tile_hover_info` | bool | false | Toggle tile hover debug |
| `show_weapon_list` | bool | false | Toggle weapon list panel |

---

## Reticle: Reticle.gd

**File:** `res://Player/Reticle.gd`

Custom crosshair cursor that follows mouse.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `color` | Color | Crosshair color |
| `mana_value` | float | Mana arc (0.0 to 1.0) |
| `attack_pattern` | int | Crosshair style (0=SINGLE, 1=SPREAD, 2=LOB) |

### Attack Patterns

| Pattern | Value | Description |
|---------|-------|-------------|
| `SINGLE` | 0 | Basic crosshair with center dot |
| `SPREAD` | 1 | 3 radiating dots |
| `LOB` | 2 | Landing zone circle with arrow |

---

## File Structure

```
res://UI/
├── UIStyle.gd
├── MainMenu.gd
├── MainMenu.tscn
├── PlayerConsole.gd
├── PlayerConsole.tscn
├── CharacterSelectCard.gd
├── CharacterSelectCard.tscn
├── EquipmentInventory.gd
├── EquipmentInventory.tscn
├── DebugOptionsController.gd
├── DebugOptionsDialog.tscn
├── ControlsPanel.tscn
└── DisplayCard/
	├── DisplayCardBase.gd
	├── DisplayCardBase.tscn
	├── WeaponCard.gd
	├── WeaponCard.tscn
	├── AbilityCard.gd
	├── AbilityCard.tscn
	├── ActorCard.gd
	└── ActorCard.tscn

res://Play Space/
├── OptionsMenu.gd
└── OptionsMenu.tscn

res://Components/Arena/
└── ArenaUIHandler.gd

res://Player/
└── Reticle.gd

res://QuestSystem/
├── QuestBoardUI.gd
├── QuestTrackerHUD.gd
└── QuestTrackerHUD.tscn
```

---

## Version Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01-10 | Initial documentation |

---

*Sync this document when UI structure changes. Every commit touching UI files should include corresponding documentation updates.*