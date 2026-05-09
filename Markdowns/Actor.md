# Actor System Reference Guide

<!--
================================================================================
VERSION CONTROL
================================================================================
Document Version: 1.1
Last Synced:     2025-01-10
Godot Version:   4.2+

SYNC RULE: When modifying actor structure (add/remove/modify components,
signals, properties, methods, or AI states), update this document in the
same commit. Keep version numbers in sync across files.

VERSION LOG:
  v1.0 (2025-01-09) - Initial documentation
  v1.1 (2025-01-10) - Updated file paths to reflect directory restructuring
================================================================================
-->

## Overview

The Actor system is a modular, component-based architecture for game entities. It uses a **Finite State Machine (FSM)** for AI behavior, **Component pattern** for extensibility, and supports both **player-controlled** and **AI-controlled** actors.

---

## Architecture Diagram

```
Actor (CharacterBody2D)
├── Components (in res://Components/ActorComponents/)
│   ├── HealthComponent        - Death, damage events, invincibility frames
│   ├── MovementComponent      - Movement speed, acceleration
│   ├── CommunicationComponent - Radio chatter, voice lines
│   ├── TerrainSpeedModifierComponent - Speed multipliers by terrain
│   ├── SkillCheckComponent    - Lockpicking, hacking, persuasion
│   ├── AbilityComponent      - Special actions, cooldowns
│   └── (more components...)
├── ActorAIController         - Manages AI state machine
├── FactionComponent           - Faction relationships
└── AI States (in res://src/actors/ai/states/)
	├── AIIdleState
	├── AIChaseState
	├── AIAttackState
	└── (more states...)
```

---

## Core: Actor.gd

**Type:** `CharacterBody2D`  
**File:** `res://src/actors/base/Actor.gd`

The base class for all game actors (players, enemies, NPCs).

### Properties

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `current_health: float` | float | `max_health` | Current health pool |
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

---

## Components

Components are located in `res://Components/ActorComponents/`. See individual component files for detailed documentation.

### HealthComponent

**File:** `res://Components/ActorComponents/HealthComponent.gd`

Manages actor health with invincibility frames.

### MovementComponent

**File:** `res://Components/ActorComponents/MovementComponent.gd`

Handles movement speed, acceleration, and terrain modifications.

### CommunicationComponent

**File:** `res://Components/ActorComponents/CommunicationComponent.gd`

Handles radio chatter and voice line playback.

### TerrainSpeedModifierComponent

**File:** `res://Components/ActorComponents/TerrainSpeedModifierComponent.gd`

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

### SkillCheckComponent

**File:** `res://Components/ActorComponents/SkillCheckComponent.gd`

Handles contextual skill events (lockpicking, hacking, persuasion).

```gdscript
enum SkillType { LOCKPICKING, HACKING, PERSUASION }
```

### AbilityComponent

**File:** `res://Components/ActorComponents/AbilityComponent.gd`

Manages special abilities with cooldown management.

### Ability Components

Located in `res://Components/ActorComponents/AbilityComponents/`:

| File | Description |
|------|-------------|
| `AbilityComponent.gd` | Base ability management |
| `AbilityAction.gd` | Action triggers |
| `GoatCharge.gd` | Goat-specific charge ability |
| `NimbleEscape.gd` | Quick escape ability |
| `RedirectAttack.gd` | Attack redirection |

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

Located in `res://src/actors/ai/states/`:

| File | Description |
|------|-------------|
| `AIState.gd` | Base class |
| `AIIdleState.gd` | Default patrol/idle behavior |
| `AIChaseState.gd` | Pursues target |
| `AIAttackState.gd` | Attacks target |
| `AIFleeState.gd` | Flees from threat |
| `AIDeathState.gd` | Death handling |
| `AIFlockinState.gd` | Flocking behavior |
| `AIInvestigateState.gd` | Investigates detected activity |
| `AIRoamState.gd` | Roaming/wandering |
| `AIStunnedState.gd` | Stunned state |
| `Dormant.gd` | Dormant/inactive state |

### AI Behavior Overview

```
AIIdleState
	↓ (target detected)
AIChaseState
	↓ (in attack range)
AIAttackState
	↓ (target escapes / low health)
AIChaseState / AIFleeState
	↓ (death)
AIDeathState
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

## Actor Controllers

Actor-specific AI controllers located in `res://src/actors/types/`:

| File | Description |
|------|-------------|
| `GoatController.gd` | AI logic for GoatActor |
| `FarmerController.gd` | AI logic for FarmerActor |
| `GoblinController.gd` | AI logic for GoblinMinion |

---

## Derived Actors

All actor types are located in `res://src/actors/types/`.

### GoatActor

**File:** `res://src/actors/types/GoatActor.gd`

```gdscript
class_name GoatActor
extends Actor
```

### FireActor

**File:** `res://src/actors/types/FireActor.gd`

```gdscript
class_name FireActor
extends Actor
```

### FarmerActor

**File:** `res://src/actors/types/FarmerActor.gd`

```gdscript
class_name FarmerActor
extends Actor
```

### WaterActor

**File:** `res://src/actors/types/WaterActor.gd`

```gdscript
class_name WaterActor
extends Actor
```

### GoblinMinion

**File:** `res://src/actors/types/GoblinMinion.gd`

```gdscript
class_name GoblinMinion
extends Actor
```

### ScarecrowDummy

**File:** `res://src/actors/types/ScarecrowDummy.gd`

```gdscript
class_name ScarecrowDummy
extends Actor
```

---

## Visual Components

Located in `res://src/actors/types/`:

| File | Description |
|------|-------------|
| `GoatVisuals.gd` | Goat visual management |
| `DormantVisual3D.gd` | 3D dormant visual effect |
| `StunVisual3D.gd` | 3D stun visual effect |
| `GoblinModels/GoblinModel.gd` | Goblin model management |

---

## Usage Patterns

### Creating a New Actor

```gdscript
var new_actor = Actor.new()
add_child(new_actor)
```

### Creating an Actor from Scene

```gdscript
const ACTOR_SCENE = preload("res://scenes/actors/FireActor.tscn")
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

### Source Code

```
res://src/actors/
├── base/
│   └── Actor.gd
├── types/
│   ├── GoatActor.gd
│   ├── GoatController.gd
│   ├── GoatVisuals.gd
│   ├── FireActor.gd
│   ├── FarmerActor.gd
│   ├── FarmerController.gd
│   ├── WaterActor.gd
│   ├── GoblinMinion.gd
│   ├── GoblinController.gd
│   ├── GoblinModels/
│   │   └── GoblinModel.gd
│   ├── ScarecrowDummy.gd
│   ├── DormantVisual3D.gd
│   └── StunVisual3D.gd
├── ai/
│   ├── ActorAIController.gd
│   ├── ActorController.gd
│   ├── ActorStateMachine.gd
│   ├── ActorTileNavigationComponent.gd
│   ├── FactionComponent.gd
│   └── states/
│       ├── AIState.gd
│       ├── AIIdleState.gd
│       ├── AIChaseState.gd
│       ├── AIAttackState.gd
│       ├── AIFleeState.gd
│       ├── AIDeathState.gd
│       ├── AIFlockinState.gd
│       ├── AIInvestigateState.gd
│       ├── AIRoamState.gd
│       ├── AIStunnedState.gd
│       └── Dormant.gd
└── projectiles/
	├── BaseProjectile.gd
	├── WaveProjectile.gd
	├── LobProjectile.gd
	├── FireProjectile.gd
	├── FireLobProjectile.gd
	├── WaterProjectile.gd
	├── WaterLobProjectile.gd
	└── HandaxeProjectile.gd

res://Components/ActorComponents/
├── HealthComponent.gd
├── MovementComponent.gd
├── CommunicationComponent.gd
├── TerrainSpeedModifierComponent.gd
├── SkillCheckComponent.gd
├── AbilityScoresComponent.gd
├── ActorData.gd
├── ActorParticleComponent.gd
├── ActorTileInteractionComponent.gd
├── ActorVisualComponent.gd
├── ArmorClassComponent.gd
├── BobComponent.gd
├── ChargeVisualComponent.gd
├── DamageComponent.gd
├── DetectionComponent.gd
├── GoatScreamComponent.gd
├── HealthBarPool.gd
├── ManaComponent.gd
├── StatusEffectComponent.gd
├── StunComponent.gd
└── AbilityComponents/
	├── AbilityComponent.gd
	├── AbilityAction.gd
	├── GoatCharge.gd
	├── NimbleEscape.gd
	└── RedirectAttack.gd
```

### Scenes

```
res://scenes/
├── actors/
│   ├── GoatActor.tscn
│   ├── FireActor.tscn
│   ├── FarmerActor.tscn
│   ├── WaterActor.tscn
│   ├── GoblinMinion.tscn
│   ├── ScarecrowDummy.tscn
│   └── models/
│       ├── GoatModel.tscn
│       └── GoblinModel.tscn
├── projectiles/
│   ├── FireProjectile.tscn
│   ├── FireLobProjectile.tscn
│   ├── WaterProjectile.tscn
│   ├── WaterLobProjectile.tscn
│   ├── ArrowProjectile.tscn
│   ├── ClubProjectile.tscn
│   ├── DaggerProjectile.tscn
│   ├── HandaxeProjectile.tscn
│   ├── JavelinProjectile.tscn
│   ├── ScimitarProjectile.tscn
│   └── ShortbowProjectile.tscn
└── weapons/
	├── ClubModel.tscn
	├── HandaxeModel.tscn
	├── JavelinModel.tscn
	├── ScimitarModel.tscn
	└── ShortbowModel.tscn
```

---

*Generated from codebase on 2025-01-10*

---

## Version Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01-09 | Initial documentation |
| 1.1 | 2025-01-10 | Updated file paths to reflect directory restructuring |

---

*Sync this document when actor structure changes. Every commit touching actor files should include corresponding documentation updates.*
