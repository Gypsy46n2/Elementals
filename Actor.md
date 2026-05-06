# Actor System Reference Guide

<!--
================================================================================
VERSION CONTROL
================================================================================
Document Version: 1.0
Last Synced:     2025-01-09
Godot Version:   4.2+

SYNC RULE: When modifying actor structure (add/remove/modify components,
signals, properties, methods, or AI states), update this document in the
same commit. Keep version numbers in sync across files.

VERSION LOG:
  v1.0 (2025-01-09) - Initial documentation
================================================================================
-->

## Overview

The Actor system is a modular, component-based architecture for game entities. It uses a **Finite State Machine (FSM)** for AI behavior, **Component pattern** for extensibility, and supports both **player-controlled** and **AI-controlled** actors.

---

## Architecture Diagram

```
Actor (CharacterBody2D)
├── StatsComponent
│   └── Handles: health, stamina, movement speed, damage
├── HealthComponent
│   └── Handles: death, damage events, invincibility frames
├── CommunicationComponent
│   └── Handles: radio chatter, voice lines, proximity dialogue
├── TerrainSpeedModifierComponent
│   └── Handles: speed multipliers based on terrain type
├── SkillCheckComponent
│   └── Handles: lockpicking, hacking, persuasion events
├── AbilityComponent
│   └── Handles: special actions, cooldowns, activation
├── ActorAIController
│   └── Manages AI state machine
└── AI States (children of AIState)
    ├── AIIdleState
    ├── AIChaseState
    └── AIAttackState
```

---

## Core: Actor.gd

**Type:** `CharacterBody2D`  
**File:** `res://src/actors/Actor.gd`

The base class for all game actors (players, enemies, NPCs).

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `stats: StatsComponent` | StatsComponent | — | Reference to stats component |
| `current_health: float` | float | `stats.max_health` | Current health pool |
| `can_take_damage: bool` | bool | `true` | Damage gate |
| `is_invincible: bool` | bool | `false` | Invincibility frames active |
| `invincibility_duration: float` | float | `0.2` | Invincibility duration after hit |
| `damage_cooldown: float` | float | `0.5` | Cooldown between damage instances |

### Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `died` | — | Emitted when health reaches 0 or below |
| `health_changed` | `old_value: float, new_value: float` | Emitted when health is modified |

### Key Methods

```gdscript
func take_damage(amount: float, knockback_force: Vector2 = Vector2.ZERO) -> void
```
Applies damage with optional knockback. Respects invincibility frames.

```gdscript
func heal(amount: float) -> void
```
Restores health up to max_health. Emits `health_changed`.

```gdscript
func die() -> void
```
Triggers death sequence and emits `died` signal.

```gdscript
func get_stat(stat_name: String) -> Variant
```
Retrieves a stat value by name from StatsComponent.

---

## Stat Component

**File:** `res://src/actors/components/StatsComponent.gd`

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `max_health: float` | float | Maximum health pool |
| `base_damage: float` | float | Base damage dealt |
| `base_armor: float` | float | Damage reduction |
| `base_speed: float` | float | Movement speed |
| `base_stamina: float` | float | Stamina pool |
| `speed_multiplier: float` | float | Speed scaling factor |

---

## Health Component

**File:** `res://src/actors/components/HealthComponent.gd`

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `owner_actor: Actor` | Actor | Reference to parent actor |
| `max_health: float` | float | Maximum health |
| `current_health: float` | float | Current health |
| `invincibility_duration: float` | float | Post-damage invincibility window |

### Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `health_depleted` | — | Emitted when health hits 0 |
| `health_changed` | `old_value: float, new_value: float` | Emitted on health change |

---

## Communication Component

**File:** `res://src/actors/components/CommunicationComponent.gd`

Handles radio chatter and voice line playback.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `audio_stream_player: AudioStreamPlayer` | AudioStreamPlayer | Audio playback node |
| `voice_lines: Dictionary` | Dictionary | Audio stream keyed by event type |
| `voice_cooldown: float` | float | Minimum time between lines |
| `current_voice_cooldown: float` | float | Cooldown timer |

### Voice Line Events

```gdscript
# Dictionary structure
{
    "idle": AudioStreamMP3,
    "chase": AudioStreamMP3,
    "attack": AudioStreamMP3,
    "death": AudioStreamMP3,
    "alert": AudioStreamMP3,
    "found_item": AudioStreamMP3,
    "injured": AudioStreamMP3
}
```

### Methods

```gdscript
func play_voice_line(event_type: String) -> void
```
Plays the voice line for the given event if cooldown allows.

```gdscript
func set_voice_line(event_type: String, audio_stream: AudioStream) -> void
```
Assigns an audio stream to an event type.

---

## Terrain Speed Modifier Component

**File:** `res://src/actors/components/TerrainSpeedModifierComponent.gd`

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `current_terrain: TerrainType` | enum | Active terrain type |
| `base_speed: float` | float | Actor's base speed |

### Terrain Types

```gdscript
enum TerrainType { GRASS, SAND, WATER, ROCK }
```

### Speed Modifiers Table

| Terrain | Multiplier |
|---------|------------|
| GRASS | 1.0 |
| SAND | 0.7 |
| WATER | 0.5 |
| ROCK | 0.8 |

### Methods

```gdscript
func update_terrain(terrain: TerrainType) -> void
```
Sets terrain and recalculates speed.

```gdscript
func get_modified_speed() -> float
```
Returns speed after terrain modifier.

---

## Skill Check Component

**File:** `res://src/actors/components/SkillCheckComponent.gd`

Handles contextual skill events (lockpicking, hacking, persuasion).

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `skill_type: SkillType` | enum | Current skill being used |

### Skill Types

```gdscript
enum SkillType { LOCKPICKING, HACKING, PERSUASION }
```

### Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `skill_check_started` | `skill_type: SkillType` | Emitted when skill check begins |
| `skill_check_completed` | `skill_type: SkillType, success: bool` | Emitted on completion |

### Methods

```gdscript
func start_skill_check(skill: SkillType) -> void
```
Initiates a skill check and emits `skill_check_started`.

```gdscript
func complete_skill_check(success: bool) -> void
```
Completes the skill check with result.

---

## Ability Component

**File:** `res://src/actors/components/AbilityComponent.gd`

Manages special abilities with cooldown management.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `ability_scene: PackedScene` | PackedScene | Scene to spawn on activation |
| `ability_cooldown: float` | float | Cooldown duration |
| `current_cooldown: float` | float | Remaining cooldown |
| `ability_owner: Node2D` | Node2D | Owner for spawned scene |
| `ability_instance: Node2D` | Node2D | Active instance |

### Signals

| Signal | Parameters | Description |
|--------|------------|-------------|
| `ability_ready` | — | Emitted when cooldown completes |
| `ability_activated` | — | Emitted on successful activation |

### Methods

```gdscript
func try_activate_ability() -> bool
```
Attempts activation. Returns `true` if cooldown is ready and owner is valid.

```gdscript
func reset_cooldown() -> void
```
Resets cooldown to 0.

---

## AI System

### AI Controller: ActorAIController.gd

**File:** `res://src/actors/ai/ActorAIController.gd`

Manages the AI state machine for an Actor.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `actor: Actor` | Actor | Owner actor reference |
| `state_machine: StateMachine` | StateMachine | FSM for state management |
| `target: Node2D` | Node2D | Current target actor |
| `awareness_radius: float` | float | Detection radius |
| `attack_range: float` | float | Melee attack range |
| `chase_speed: float` | float | Speed while chasing |

### Methods

```gdscript
func set_state(state_class: Variant) -> void
```
Transitions to a new AI state by class or script.

```gdscript
func set_target(new_target: Node2D) -> void
```
Updates the target reference.

### AI States

```
AIState (base class)
├── AIIdleState
├── AIChaseState
└── AIAttackState
```

---

### Base: AIState.gd

**File:** `res://src/actors/ai/states/AIState.gd`

Base class for all AI states. Must be extended.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `ai_controller: ActorAIController` | ActorAIController | Owner AI controller |

### Required Override Methods

```gdscript
func enter() -> void      # Called when state starts
func exit() -> void       # Called when state ends
func process_state(delta: float) -> void   # _process callback
func physics_process_state(delta: float) -> void  # _physics_process callback
```

---

### AIIdleState.gd

**File:** `res://src/actors/ai/states/AIIdleState.gd`

Default patrol/idle behavior. Scans for targets.

### Behavior

1. Sets actor movement to `Vector2.ZERO`
2. Checks `ai_controller.target`
3. If target found within `awareness_radius`, transitions to `AIChaseState`

---

### AIChaseState.gd

**File:** `res://src/actors/ai/states/AIChaseState.gd`

Pursues the target actor.

### Behavior

1. Moves actor toward target position using `chase_speed`
2. Recalculates direction each frame
3. If target within `attack_range`, transitions to `AIAttackState`
4. If target exits `awareness_radius`, returns to `AIIdleState`

---

### AIAttackState.gd

**File:** `res://src/actors/ai/states/AIAttackState.gd`

Attacks the target actor.

### Properties

| Property | Type | Description |
|----------|------|-------------|
| `attack_cooldown: float` | float | Time between attacks |
| `attack_damage: float` | float | Damage per hit |
| `attack_knockback: Vector2` | Vector2 | Knockback force |
| `current_cooldown: float` | float | Cooldown timer |

### Behavior

1. Stops actor movement
2. Applies damage to target with knockback
3. Starts `attack_cooldown` timer
4. After cooldown, checks if target still in range
5. Returns to `AIChaseState` if out of range

---

## Derived Actors

### GoatActor

**File:** `res://src/actors/GoatActor.gd`

Example derived actor class.

```gdscript
class_name GoatActor
extends Actor
```

Initializes with custom values:
- `base_speed`: 100.0
- `awareness_radius`: 250.0

### FireActor

**File:** `res://src/actors/FireActor.gd`

Example fire/hazard actor.

```gdscript
class_name FireActor
extends Actor
```

---

## Usage Patterns

### Creating a New Actor

```gdscript
var new_actor = Actor.new()
add_child(new_actor)
```

### Creating an Actor from Scene

```gdscript
const ACTOR_SCENE = preload("res://src/actors/FireActor.tscn")
var actor = ACTOR_SCENE.instantiate()
add_child(actor)
actor.global_position = Vector2(100, 200)
```

### Adding Components

```gdscript
# Via Scene
var component_scene = preload("res://path/to/Component.tscn")
var component = component_scene.instantiate()
actor.add_child(component)

# Programmatically (if component is a script)
var component = ComponentClass.new()
actor.add_child(component)
```

### Setting Up AI

```gdscript
# Configure AI Controller
ai_controller.awareness_radius = 300.0
ai_controller.attack_range = 50.0
ai_controller.chase_speed = 150.0

# Set initial state
ai_controller.set_state(AIIdleState)

# Set target
ai_controller.set_target(player_actor)
```

### Handling Damage

```gdscript
# Subscribe to damage
actor.health_changed.connect(_on_health_changed)

func _on_health_changed(old_val: float, new_val: float):
    var damage = old_val - new_val
    print("Took %s damage, health: %s" % [damage, new_val])

# Subscribe to death
actor.died.connect(_on_death)

func _on_death():
    queue_free()
    # Spawn death effects, drop loot, etc.
```

### Using Voice Lines

```gdscript
comm_component.set_voice_line("chase", audio_stream)
comm_component.play_voice_line("chase")
```

### Terrain Speed Modifier

```gdscript
terrain_mod_component.update_terrain(TerrainSpeedModifierComponent.TerrainType.SAND)
var speed = terrain_mod_component.get_modified_speed()
```

### Ability Activation

```gdscript
ability_component.ability_scene = preload("res://scenes/Fireball.tscn")
if ability_component.try_activate_ability():
    print("Ability activated!")
```

### Skill Check

```gdscript
skill_check_component.skill_check_completed.connect(_on_skill_done)

func _on_skill_done(skill_type, success):
    if success:
        print("Skill check passed!")
    else:
        print("Skill check failed!")

skill_check_component.start_skill_check(SkillCheckComponent.SkillType.LOCKPICKING)
```

---

## Best Practices

1. **Component Communication** — Components should communicate via signals, not direct references
2. **AI States** — Keep state logic minimal; delegate complex behavior to dedicated systems
3. **Damage** — Always route damage through `take_damage()` to respect invincibility
4. **Health** — Use `heal()` instead of directly modifying `current_health`
5. **Speed** — Use `get_modified_speed()` instead of reading `base_speed` directly
6. **Abilities** — Check `ability_ready` signal before UI updates

---

## File Structure

```
res://src/actors/
├── Actor.gd
├── GoatActor.gd
├── FireActor.gd
├── components/
│   ├── StatsComponent.gd
│   ├── HealthComponent.gd
│   ├── CommunicationComponent.gd
│   ├── TerrainSpeedModifierComponent.gd
│   ├── SkillCheckComponent.gd
│   └── AbilityComponent.gd
└── ai/
    ├── ActorAIController.gd
    └── states/
        ├── AIState.gd
        ├── AIIdleState.gd
        ├── AIChaseState.gd
        └── AIAttackState.gd
```

---

*Generated from codebase on 2025-01-09*

---

## Version Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01-09 | Initial documentation |

---

*Sync this document when actor structure changes. Every commit touching actor files should include corresponding documentation updates.*