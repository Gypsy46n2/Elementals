# TileSignalComponent

**Location:** `Components/Arena/TileSignalComponent.gd`

## Overview

`TileSignalComponent` is a Node that centralizes hex‑grid proximity checks for actors and static features. It tracks actor tile changes, manages registered triggers with arbitrary metadata, and emits signals when actors enter or exit a trigger radius so consumers can respond without reimplementing distance math or per‑frame scans.

## Signals

```gdscript
signal trigger_activated(trigger_data: Dictionary, actor: Node3D)
signal trigger_deactivated(trigger_data: Dictionary, actor: Node3D)
```

| Signal                | Description                                                           |
|-----------------------|-----------------------------------------------------------------------|
| `trigger_activated`   | Emitted when an actor enters a registered trigger radius.            |
| `trigger_deactivated` | Emitted when an actor exits a registered trigger radius.             |

## Key Properties

| Name             | Type             | Description                              |
|------------------|------------------|------------------------------------------|
| `arena`          | `Node`           | Reference to the `ArenaGrid` node.       |
| `_triggers`      | `Array[Dictionary]` | Active trigger definitions.              |
| `_actor_tiles`   | `Dictionary`     | Maps each actor to its current tile.     |
| `_tile_to_actors`| `Dictionary`     | Maps each tile to a list of actors on it.|

## Core Methods

### `func setup(p_arena: Node) -> void`
Initializes the component with the arena reference and starts a timer to track new actors.

### `func register_actor(actor: Node3D) -> void`
Begin tracking an actor's tile changes so it can activate/deactivate existing triggers.

### `func register_trigger(center_tile: Object, radius: int, callback: Callable, metadata: Dictionary = {}) -> Dictionary`
Registers a proximity trigger centered on `center_tile` with the given hex `radius`.  
- Immediately checks all tracked actors and activates for those already in range.  
- Returns a `trigger` Dictionary handle for future updates or removal.

### `func update_trigger_center(trigger: Dictionary, new_tile: Object) -> void`
Moves an existing trigger's center to `new_tile`, re-evaluating all tracked actors for enter/exit events.

### `func remove_trigger(trigger: Dictionary) -> void`
Removes the specified trigger by reference identity, stopping any future callbacks or signal emissions.

## Internal Mechanics

- Actors must emit a `tile_changed(new_tile, self)` signal when they move; the component listens and updates its mappings.  
- Distance checks use axial hex coordinates:

```gdscript
func _get_hex_distance(a: Vector2i, b: Vector2i) -> int:
    return (abs(a.x - b.x) + abs(a.x + a.y - b.x - b.y) + abs(a.y - b.y)) / 2
```

- On tile change, each trigger's radius is rechecked. If an actor crosses into range, `_activate_trigger_for_actor` fires the callback and emits `trigger_activated`; if it leaves, `_deactivate_trigger_for_actor` emits `trigger_deactivated`.
- The optional `'continuous'` metadata flag causes callbacks and signals to fire on every movement within radius, not just on enter.

## Usage Examples

### Initializing in `ArenaGrid`
```gdscript
var tile_signals = TileSignalComponent.new()
tile_signals.name = 'TileSignalComponent'
add_child(tile_signals)
tile_signals.setup(self)  # self is the ArenaGrid node
```

### Actor Perception (`DetectionComponent`)
```gdscript
_perception_trigger = arena.tile_signals.register_trigger(
    current_tile,
    hex_radius,
    _on_perception_trigger_activated,
    {'continuous': true}
)
```

### AI Dormant State (`Dormant.gd`)
```gdscript
_trigger = tile_signal_component.register_trigger(
    center_tile,
    dormant_radius_tiles,
    _on_trigger_activated,
    {'previous_state': _previous_state}
)
```

### Static Obstacles in Arena
```gdscript
# Trees, fences, walls block movement with custom weight metadata
tile_signals.register_trigger(
    tile,
    2,
    Callable(),
    {'weight': weight, 'is_static_obstacle': true}
)
```

### Projectile Impact (`LobProjectile.gd`)
```gdscript
var trigger = arena.tile_signals.register_trigger(center, hex_radius, impact_callback)
# Remove after a short delay to catch immediate movement
get_tree().create_timer(0.5).timeout.connect(func():
    arena.tile_signals.remove_trigger(trigger)
)
```

### Quest Camp Discovery (`QuestSpawnManager.gd`)
```gdscript
tile_signal_comp.register_trigger(
    camp_tile,
    8,
    _on_camp_trigger_activated,
    {'quest_id': quest_id, 'camp_index': camp_index, 'camp_id': camp_id}
)
```
