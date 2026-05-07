# Agent Instructions for Elementals Project

## Project Overview

**Elementals** is a tactical hex-grid game where players control elemental beings (goats, farmers, fire, water, goblins) in combat. The game features:

- **Hexagonal grid-based arena** with tiles that can change state (grass, fire, water, mud, stone, etc.)
- **Component-based actor system** where every entity (Actor) is built from modular components
- **AI-driven NPCs** with state machines (idle, roam, chase, attack, flee, investigate, stunned, death)
- **Tile signal system** for efficient proximity/trigger detection without per-frame distance calculations
- **Quest system** integrated with the arena
- **Breeding system** for goats with genetic traits

---

## Project Structure

```
res://
├── src/actors/               # All playable/NPC entities
│   ├── base/
│   │   ├── Actor.gd          # Base class - all living entities inherit from here
│   │   ├── ActorController.gd  # Base controller (human input)
│   │   └── ActorData.gd     # RPG stat container
│   ├── ai/                   # AI behavior system
│   │   ├── ActorAIController.gd  # Base AI controller
│   │   ├── ActorStateMachine.gd  # State machine for AI
│   │   ├── AIState.gd            # Base state class
│   │   └── states/           # Individual AI states
│   │       ├── AIFlockState.gd
│   │       └── ...           # Other AI states (idle, roam, chase, attack, flee, etc.)
│   ├── types/                # Specific actor implementations
│   │   ├── GoatActor.gd      # Player-controlled goat
│   │   ├── GoatController.gd # Goat AI controller
│   │   ├── FarmerActor.gd    # NPC farmer
│   │   ├── FireActor.gd      # Fire elemental
│   │   ├── WaterActor.gd     # Water elemental
│   │   ├── GoblinMinion.gd   # Goblin NPC
│   │   ├── GoblinController.gd  # Goblin AI controller
│   │   └── ScarecrowDummy.gd   # Training dummy
│   └── projectiles/          # All projectile types
│       ├── BaseProjectile.gd
│       └── ...               # (FireProjectile, WaterLobProjectile, etc.)
│
├── Components/               # Modular components attached to actors
│   ├── ActorComponents/      # Components usable by any Actor
│   │   ├── AbilityComponents/    # Special abilities (GoatCharge, NimbleEscape, etc.)
│   │   ├── ActorTileInteractionComponent.gd
│   │   ├── DetectionComponent.gd   # Perception/enemy detection
│   │   ├── HealthComponent.gd      # Health management
│   │   ├── MovementComponent.gd     # Hex-grid movement
│   │   ├── ProjectileComponent.gd   # Ranged attacks
│   │   ├── TerrainSpeedModifierComponent.gd
│   │   └── WeaponComponent.gd
│   ├── BreedingComponents/   # Goat genetics/breeding
│   └── DebugComponent.gd
│
├── Play Space/             # World objects
│   ├── Arena.gd           # ArenaGrid - THE central game world node
│   ├── hex_tile.gd        # Single tile mesh
│   ├── hex_tile_data.gd   # Tile data (axial coords, state, etc.)
│   ├── tile_constants.gd  # Tile state enumerations
│   └── TreeStates/        # Tree growth state machine
│
├── Core/                   # Autoloaded singletons
│   ├── GameEvents.gd      # Global event bus
│   ├── GameSettings.gd    # Player preferences
│   ├── ItemsAutoload.gd   # Item database
│   └── AbilityData.gd
│
├── QuestSystem/            # Quest tracking/markers
├── UI/                     # User interface elements
├── Player/                 # Player camera/reticle
└── test_*.gd               # Test scripts
```

---

## Critical: Component Routing

### The TileSignalComponent Is The Authority On Distance

**`res://Components/Arena/TileSignalComponent.gd`** is the central hub for all hex-distance calculations and proximity-based triggers. **ALL distance-related decisions must route through this component.**

## Critical: Centralized Timing

**`res://Components/Arena/GameClockComponent.gd`** is the single source of truth for all game timing. **ALL timer logic must route through this component.**

### Why This Matters

- **Before**: 50 actors × 4 timers = 200+ timer nodes (massive overhead)
- **After**: 1 centralized clock, zero timer nodes per actor

### How It Works

```gdscript
# GameClockComponent runs _physics_process with a base tick (10Hz / 0.1s)
# Components register callbacks for specific intervals
# Actor.gd routes register_tick() calls to ArenaGrid.game_clock

func register_tick(callback: Callable, interval: float = 0.1) -> int
func unregister_tick(id: int) -> void
signal tick_elapsed(delta: float)  # Fires every 0.1s with accumulated delta
```

### When You Need Timing Logic

1. **Status effects** → Use `Actor.register_tick()` for burn, poison, slow ticks
2. **Periodic abilities** → Register with GameClock instead of Timer nodes
3. **Cooldown tracking** → Can use the tick system for cooldown checks
4. **AI state timers** → Route through GameClock callbacks

### Example: Registering a Component Tick

```gdscript
# WRONG: Adding Timer nodes to actor
var my_timer: Timer
func _ready():
	my_timer = Timer.new()
	add_child(my_timer)
	my_timer.timeout.connect(_on_my_tick)

# RIGHT: Register with GameClockComponent
var _my_tick_id: int = -1

func setup(actor: Actor):
	_my_tick_id = actor.register_tick(_on_my_tick, 1.0)  # Every 1 second

func _on_my_tick() -> void:
	# Handle tick logic
	pass

func _exit_tree():
	if _my_tick_id >= 0:
		actor.unregister_tick(_my_tick_id)
```

### Anti-Patterns

- **Do NOT add Timer nodes to actors for game logic**
- **Do NOT create accumulators in component _physics_process**
- **Do NOT create standalone timer components** — use the centralized system
- **Do NOT use _physics_process for game logic timing** — all timing goes through GameClockComponent
- **Visual effects that need per-frame updates** — use Tweens instead of _physics_process

### Components Currently Using GameClock

- `StatusEffectComponent` — burn duration, damage ticks, splash sound timing

#### What TileSignalComponent Provides

```gdscript
# Centralized hex distance and proximity detection
# Avoids duplicate distance math across the codebase
# Manages enter/exit signals for actor-trigger proximity

func register_trigger(center_tile, radius, callback, metadata) -> Dictionary
func update_trigger_center(trigger, new_tile)
func register_actor(actor)
signal trigger_activated(trigger_data, actor)
signal trigger_deactivated(trigger_data, actor)
```

#### When You Need Distance Logic

1. **Detection ranges** → Use `DetectionComponent` which registers with `TileSignalComponent`
2. **Attack ranges** → Route through `TileSignalComponent` triggers, not raw position distance
3. **Trigger zones** → Use `tile_signals.register_trigger(tile, radius, callback)`
4. **Nearest enemy queries** → Use `DetectionComponent.detect_nearest_enemy()` which uses the signal system
5. **Area effects** → Use `ArenaGrid.get_tiles_in_radius()` for hex-based area queries

#### Example: Registering a Custom Trigger

```gdscript
# WRONG: Direct distance calculation
var dist = actor.global_position.distance_to(target.global_position)
if dist < attack_range:
	perform_attack()

# RIGHT: Route through TileSignalComponent
func _setup_combat_trigger() -> void:
	var arena = actor.get_tree().get_first_node_in_group("arena")
	if arena and arena.tile_signals:
		var my_tile = actor.tile_interaction_component.get_ground_tile()
		var hex_radius = int(ceil(attack_range / (SQRT3 * arena.hex_size))) + 1
		_combat_trigger = arena.tile_signals.register_trigger(
			my_tile,
			hex_radius,
			_on_enemy_in_range,
			{"continuous": true}
		)
```

---

## Script Documentation Requirements

Every script **MUST** include documentation explaining:

### 1. Class Docstring (Top of file)

```gdscript
## Brief one-line purpose.
## Expanded description of what this script does and why it exists.
## Mention if it's part of a system or requires other components.
class_name MyComponent
extends Node
```

### 2. Signal Documentation

```gdscript
## Emitted when [condition].
## [Param description for each parameter].
signal my_signal(param1: Type)
```

### 3. Variable Documentation

```gdscript
## Description of what this holds or controls.
## Include units if applicable (e.g., "Movement speed in units/second").
var my_variable: Type

## Reference to the owning actor.
## Set during setup(), do not access before ready.
var actor: Node3D
```

### 4. Function Documentation

```gdscript
## Brief description of what the function does.
## Expand if the logic is non-obvious or has edge cases.
## [Param description for each parameter].
## [Return type and description].
func my_function(param1: Type, param2: Type) -> ReturnType:
    pass
```

### 5. Inline Comments for Non-Obvious Logic

```gdscript
# Comment WHY this is done this way, not WHAT it does
# Using BFS instead of brute force to avoid O(N) grid scan
var candidates = get_tiles_in_radius(center, radius)
```

---

## Coding Conventions

### File Organization

- `class_name` at the top of every script
- Variables grouped by purpose with `@export_group`
- Components declared as typed `var` with null checks where needed
- Use `_` prefix for private/internal variables: `var _private_var`

### Component Pattern

All components follow this pattern:

```gdscript
class_name MyComponent
extends Node

var actor: Node3D  # Owner reference

func setup(p_actor: Node3D) -> void:
    actor = p_actor
    # Initialize state, connect signals

func _some_internal_method() -> void:
    pass
```

### Hex Grid Conventions

- **Axial coordinates** (Vector2i) for tile addressing
- **`axial_coords`** property on `HexTileData` for tile position
- **Hex distance** via `TileSignalComponent._get_hex_distance()` or `ArenaGrid.get_tiles_in_radius()`
- **World position** (Vector3) for rendering and physics

### State Machine Pattern (AI)

```gdscript
# States inherit from AIState.gd
class_name MyState
extends AIState

func enter() -> void:
    # Called when entering this state
    pass

func exit() -> void:
    # Called when leaving this state
    pass

func physics_update(delta: float) -> void:
    # Called every physics frame while in this state
    pass
```

### Signal Connection Pattern

```gdscript
# Prefer binding over closures for signal callbacks
signal.tile_changed.connect(_on_tile_changed.bind(source))

# Or use callable with explicit binding
some_signal.connect(Callable(self, "_on_something").bind(data))
```

### Error Handling

```gdscript
# Always check for valid instances
if not is_instance_valid(actor):
    return

# Check for null before accessing properties
if not some_component:
    return

# Use get_node_or_null for optional scene nodes
var node = get_node_or_null("OptionalNode")
```

---

## Common Patterns

### Getting the Arena Reference

```gdscript
# From an Actor
var arena = actor._arena_grid

# From anywhere
var arena = get_tree().get_first_node_in_group("arena")

# From a component
var arena = get_node("/root/Arena")  # If path is known
```

### Adding a New Component to Actors

1. Add `var new_component: NewComponent` to `Actor.gd`
2. Initialize in `_setup_components()`:
   ```gdscript
   new_component = _add_comp(NewComponent.new())
   new_component.setup(self)
   ```
3. Wire up signals and exports as needed

### Adding a New AI State

1. Create new class in `States/` inheriting from `AIState.gd`
2. Implement `enter()`, `exit()`, `physics_update()`, and `update()` methods
3. Register in `ActorAIController._init_state_machine()`:
   ```gdscript
   state_machine.register_state("my_state", MyNewState.new())
   ```

### Adding a New Tile State

1. Add to `tile_constants.gd` enum
2. Update `HexTileData._sync_type()` for mesh/material assignment
3. Add logic in `TileSystem.gd` for state behavior
4. Update `ArenaGrid.set_tile_state()` if special handling needed

---

## Testing Guidelines

- Test scripts follow `test_*.gd` naming convention
- Component tests should verify:
  - `setup()` completes without error
  - Required signals are emitted
  - Edge cases (null inputs, invalid states)
- Scene tests should verify:
  - Nodes are in expected positions
  - Scripts are correctly attached
  - Exports are wired up

---

## Performance Considerations

1. **Avoid per-frame distance calculations** — use `TileSignalComponent` triggers
2. **Cache frequently accessed values** — especially on `HexTileData`
3. **Use BFS for area queries** — `get_tiles_in_radius()` not brute force scans
4. **Lazy initialization** — defer non-essential setup to `call_deferred()`
5. **Pool objects where applicable** — projectiles, particles

---

## Key Files Reference

| System | Key File | Purpose |
|--------|----------|---------|
| Core Game Loop | `Play Space/Arena.gd` | Main arena, orchestrator |
| Centralized Timing | `Components/Arena/GameClockComponent.gd` | Single clock for all game timing |
| Hex Grid | `Play Space/hex_tile_data.gd` | Tile data structure |
| Distance/Triggers | `Components/Arena/TileSignalComponent.gd` | Central proximity system |
| Actor System | `src/actors/base/Actor.gd` | Base entity class |
| AI Behavior | `src/actors/ai/ActorAIController.gd` | NPC controller |
| Movement | `Components/ActorComponents/MovementComponent.gd` | Hex-grid movement |
| Perception | `Components/ActorComponents/DetectionComponent.gd` | Enemy detection |
| Events | `Core/GameEvents.gd` | Global event bus |

---

## Questions This Agent Should Ask

Before proceeding, I may ask clarifying questions if:

1. A requested feature spans multiple systems unclear how to integrate
2. There's conflict between existing patterns and new requirements
3. A script modification could break existing functionality
4. The user's intent maps to multiple possible implementations

---

*Last updated: Auto-generated from project analysis*
