# Ability System Reference Guide

<!--
================================================================================
VERSION CONTROL
================================================================================
Document Version: 1.0
Last Synced:     2025-01-10
Godot Version:   4.6+

SYNC RULE: When modifying ability structure (add/remove/modify components,
signals, properties, methods, or actions), update this document in the
same commit. Keep version numbers in sync across files.

VERSION LOG:
  v1.0 (2025-01-10) - Initial documentation
================================================================================
-->

## Overview

The Ability system provides special maneuvers and reactive abilities for actors. It's designed around two key concepts:

1. **AbilityComponent** — The manager that lives on an Actor and coordinates all abilities
2. **AbilityAction** — Individual ability implementations that get plugged into the component

This architecture allows actors to have multiple abilities, each with its own logic, cooldowns, and behaviors.

---

## Architecture Diagram

```
Actor (CharacterBody3D)
└── ability_component: AbilityComponent
    └── actions: Array[AbilityAction]
        ├── NimbleEscape      (Hide / Disengage)
        ├── RedirectAttack    (Attack redirection)
        ├── GoatCharge        (Headbutt charge)
        └── [Custom Abilities...]
```

---

## Core Classes

### 1. AbilityData

**File:** `res://Core/AbilityData.gd`  
**Type:** `Resource`

A data-only container that holds display information for an ability. Used by the UI to show ability cards.

```gdscript
class_name AbilityData
extends Resource

@export var name: String = ""
@export var icon: Texture2D
@export_multiline var description: String = ""
@export var usage: String = ""           # How to use it (e.g. "Press Q")
@export var cooldown: float = 1.0
```

**Usage:** Each `AbilityAction` creates an `AbilityData` instance in `get_ability_data()` to populate the UI.

---

### 2. AbilityComponent

**File:** `res://Components/ActorComponents/AbilityComponents/AbilityComponent.gd`  
**Type:** `Node`

The central manager that lives on an Actor. It holds an array of `AbilityAction` instances and routes execution requests to them.

```gdscript
class_name AbilityComponent
extends Node

var actor: Actor
var actions: Array[AbilityAction] = []

var is_hidden: bool      # Delegates to actions for is_hidden
var is_disengaged: bool  # Delegates to actions for is_disengaged
```

#### Key Methods

```gdscript
func setup(p_actor: Actor) -> void
```
Initializes the component and adds default abilities based on actor type.

```gdscript
func add_action(action: AbilityAction) -> void
```
Adds an ability action to this actor. Called during setup or when granting new abilities.

```gdscript
func execute_ability(type: String, value = null) -> void
```
Routes an execution request to all actions. Each action decides if it handles the type.

```gdscript
func get_attack_target(attacker: Actor) -> Actor
```
Called when this actor is targeted by an attack. Returns the actual target (may be redirected). Used by `MeleeHitbox` and `BaseProjectile`.

```gdscript
func on_damage_taken() -> void
```
Called when the actor takes damage. All actions react accordingly.

```gdscript
func on_attack_performed() -> void
```
Called when the actor performs an attack. All actions react accordingly.

#### Default Setup Logic

```gdscript
func setup(p_actor: Actor) -> void:
    actor = p_actor
    if actor.element_type == "goblin":
        # 50/50 chance between NimbleEscape or RedirectAttack
        if rng.randf() > 0.5:
            add_action(preload("...").new(actor, self))
        else:
            add_action(preload("...").new(actor, self))
    elif actor.element_type == "goat":
        add_action(GoatChargeClass.new(actor, self))
```

---

### 3. AbilityAction

**File:** `res://Components/ActorComponents/AbilityComponents/AbilityAction.gd`  
**Type:** `RefCounted`

The base class for all abilities. Extend this to create new abilities.

```gdscript
class_name AbilityAction
extends RefCounted

var actor: Actor              # The actor using this ability
var component: Node           # The AbilityComponent owning this action

var ability_name: String = ""
var ability_description: String = ""
var ability_usage: String = ""
var ability_icon: Texture2D = null
```

#### Methods to Override

```gdscript
func _init(p_actor: Actor, p_component: Node) -> void
```
Initialize the ability. Set name, description, usage, and icon here.

```gdscript
func get_ability_data() -> AbilityData
```
Returns an `AbilityData` instance populated with the ability's display info.

```gdscript
func can_execute(type: String) -> bool
```
Returns whether this ability can handle the given execution type. Default: `true`

```gdscript
func execute(type: String, value = null) -> void
```
Execute the ability. `type` is the action identifier (e.g., "hide", "disengage", "charge").

```gdscript
func update(delta: float) -> void
```
Called every frame while the ability is active. Use for cooldowns, timers, state checks.

```gdscript
func on_damage_taken() -> void
```
Called when the owning actor takes damage. React appropriately (e.g., cancel hide).

```gdscript
func on_attack_performed() -> void
```
Called when the owning actor performs an attack. React appropriately (e.g., cancel hide).

```gdscript
func on_targeted_by_attack(attacker: Actor) -> Actor
```
Called when the actor is targeted by an attack roll. Return the actual target. Default: returns `actor` (no redirection).

---

## How Abilities Plug Into Actors

### Automatic Integration (Default Behavior)

The `Actor` base class automatically creates and initializes the `AbilityComponent`:

```gdscript
# In Actor.gd _setup_components()
ability_component = _add_comp(AbilityComponent.new())
ability_component.setup(self)
weapon_component.attack_performed.connect(func(_pos): ability_component.on_attack_performed())
```

### Accessing the Ability Component

```gdscript
# From any script with access to the actor
if actor.ability_component:
    actor.ability_component.execute_ability("hide", true)
    actor.ability_component.execute_ability("disengage", direction)
```

### Exposing Properties via Dynamic Lookup

The codebase uses dynamic property lookup to avoid tight coupling:

```gdscript
# NimbleEscape accesses actor properties like this:
var dex_val: float = actor.ability_scores_component.dexterity
var movement = target.get("movement_component")
```

This pattern allows abilities to work with any actor that has the expected component without direct type dependencies.

---

## Existing Abilities

### NimbleEscape

**File:** `res://Components/ActorComponents/AbilityComponents/NimbleEscape.gd`  
**Actor Type:** Goblins (and player-controlled actors)

**Actions:**
- `"hide"` — Toggle stealth. Holding Shift initiates hide attempt with visual feedback.
- `"disengage"` — Dash away from nearest enemy with brief invulnerability.

**Features:**
- Stealth check against nearby enemies' Wisdom
- Visual alpha modulation during hide
- Cooldown management

```gdscript
# Example: Execute hide
ability_component.execute_ability("hide", true)   # Start hiding
ability_component.execute_ability("hide", false)  # Stop hiding

# Example: Execute disengage
ability_component.execute_ability("disengage", direction)  # Dash in direction
```

---

### RedirectAttack

**File:** `res://Components/ActorComponents/AbilityComponents/RedirectAttack.gd`  
**Actor Type:** Goblins

**Action:**
- `on_targeted_by_attack()` — When targeted by an attack, swap places with a nearby ally.

**Features:**
- Finds nearest small/medium ally within range
- Performs position swap with safe Y placement
- Visual indicators on potential swap targets
- Cooldown to prevent spam

```gdscript
# This ability is passive - it reacts automatically
# Called by MeleeHitbox when targeting this actor:
var final_target = target.ability_component.get_attack_target(attacker)
```

---

### GoatCharge

**File:** `res://Components/ActorComponents/AbilityComponents/GoatCharge.gd`  
**Actor Type:** Goats

**Action:**
- `"charge"` — Charge toward a target position, dealing damage and knockback.

**Features:**
- Physics-based charge movement
- Collision detection with actors, tiles, and features
- Damage and stun application
- Terrain speed modifier support

```gdscript
# Example: Execute charge
ability_component.execute_ability("charge", target_position)

# Access charge state
if actor.ability_component:
    for action in actor.ability_component.actions:
        if action is GoatCharge:
            print("Is charging: ", action.is_charging)
```

---

### Dash (Data Only)

**File:** `res://Core/Abilities/Dash.gd`  
**Type:** `AbilityData`

A simple data class for UI display. Not a full `AbilityAction` implementation.

```gdscript
class_name DashAbility
extends AbilityData

func _init() -> void:
    name = "Dash"
    description = "A quick burst of speed to reposition or dodge attacks."
    usage = "Press SHIFT while moving."
    cooldown = 2.0
```

---

## Step-by-Step: Creating a New Ability

### Step 1: Create the AbilityAction Script

Create a new file in `res://Components/ActorComponents/AbilityComponents/`:

```gdscript
class_name MyNewAbility
extends AbilityAction

## Brief description of what this ability does.

# State variables
var _is_active: bool = false
var _cooldown_timer: float = 0.0
const COOLDOWN: float = 5.0

func _init(p_actor: Actor, p_component: Node) -> void:
    super(p_actor, p_component)
    ability_name = "My New Ability"
    ability_description = "Description of what it does."
    ability_usage = "How to activate it."
    # Optional: ability_icon = preload("res://path/to/icon.png")

func can_execute(type: String) -> bool:
    # Return true for action types this ability handles
    return type == "activate" or type == "deactivate"

func execute(type: String, value = null) -> void:
    match type:
        "activate":
            if _cooldown_timer > 0.0:
                return
            _activate()
            _cooldown_timer = COOLDOWN
        "deactivate":
            _deactivate()

func update(delta: float) -> void:
    if _cooldown_timer > 0.0:
        _cooldown_timer -= delta

func on_damage_taken() -> void:
    # React to damage - usually cancel active abilities
    if _is_active:
        _deactivate()

func on_attack_performed() -> void:
    # React to attack - often cancel stealth-like abilities
    if _is_active:
        _deactivate()

func _activate() -> void:
    _is_active = true
    print(actor.name, " activated MyNewAbility")

func _deactivate() -> void:
    _is_active = false
    print(actor.name, " deactivated MyNewAbility")
```

### Step 2: Implement the Ability Logic

Add your specific logic in the private methods. Common patterns:

**Movement-based abilities:**
```gdscript
func _apply_movement_force(force: Vector3) -> void:
    if actor and actor.movement_component:
        actor.movement_component.apply_external_force(force)
```

**Damage-dealing abilities:**
```gdscript
func _deal_damage_to(target: Actor, amount: int) -> void:
    target.take_damage(amount, "normal", knockback_dir)
```

**Visual feedback:**
```gdscript
func _show_effect() -> void:
    if actor and actor.visual_component:
        actor.visual_component.set_alpha(0.5)
```

### Step 3: Register with AbilityComponent

#### Option A: Default Setup (Actor Type Based)

Modify `AbilityComponent.setup()` to add your ability for specific actor types:

```gdscript
# In AbilityComponent.gd setup()
elif actor.element_type == "my_type":
    var MyNewAbilityClass = load("res://Components/ActorComponents/AbilityComponents/MyNewAbility.gd")
    if MyNewAbilityClass:
        add_action(MyNewAbilityClass.new(actor, self))
```

#### Option B: Actor-Specific Setup

Modify the specific actor type's setup:

```gdscript
# In GoatActor.gd (example pattern from GoblinMinion.gd)
if not ability_component:
    ability_component = AbilityComponent.new()
    add_child(ability_component)
    ability_component.setup(self)

ability_component.actions.clear()

var my_action = preload("res://Components/ActorComponents/AbilityComponents/MyNewAbility.gd").new(self, ability_component)
ability_component.add_action(my_action)
```

### Step 4: Connect Input Handling (If Player-Controlled)

Modify `PlayerInputComponent.gd` to route input to the ability:

```gdscript
# In PlayerInputComponent._process_input()
if _ability_pressed:
    if current_controlled_actor and current_controlled_actor.ability_component:
        current_controlled_actor.ability_component.execute_ability("activate", value)
```

### Step 5: Create AbilityData for UI (Optional)

If you want the ability to show in the UI card:

```gdscript
class_name MyNewAbilityData
extends AbilityData

func _init() -> void:
    name = "My New Ability"
    description = "Description of what it does."
    usage = "How to activate it."
    cooldown = 5.0
    icon = preload("res://path/to/icon.png")
```

### Step 6: Add AI Integration (If NPC-Controlled)

Modify the appropriate controller (`GoblinController.gd`, `GoatController.gd`, etc.):

```gdscript
# In the AI logic, check conditions and execute
if should_use_ability():
    actor.ability_component.execute_ability("activate")
```

---

## Usage Examples

### Checking if an Actor Has an Ability

```gdscript
if actor.ability_component and actor.ability_component.actions.size() > 0:
    var first_ability = actor.ability_component.actions[0]
    var data = first_ability.get_ability_data()
    print("Ability: ", data.name)
```

### Iterating All Abilities

```gdscript
if actor.ability_component:
    for action in actor.ability_component.actions:
        print(" - ", action.ability_name)
```

### Checking Hidden State

```gdscript
if actor.ability_component and actor.ability_component.is_hidden:
    # Actor is hidden - skip targeting, etc.
    pass
```

### Getting Attack Target (With Redirection)

```gdscript
# In MeleeHitbox.gd:
if target.get("ability_component"):
    final_target = target.ability_component.get_attack_target(_owner_actor)
```

---

## Best Practices

1. **Use `can_execute()` for Cooldown Checks**
   ```gdscript
   func can_execute(type: String) -> bool:
       return _cooldown_timer <= 0.0 or type == "deactivate"
   ```

2. **Always Call `super._init()` in Derived Classes**
   ```gdscript
   func _init(p_actor: Actor, p_component: Node) -> void:
       super(p_actor, p_component)
       # Your initialization
   ```

3. **Use Dynamic Property Lookup for Components**
   ```gdscript
   # Good - works without direct type coupling
   var movement = actor.get("movement_component")
   var ability_scores = actor.get("ability_scores_component")
   
   # Also valid - when you're sure of the type
   if actor.ability_scores_component:
       strength = actor.ability_scores_component.strength
   ```

4. **Cancel Abilities on Damage/Attack**
   ```gdscript
   func on_damage_taken() -> void:
       if _is_active:
           _deactivate()
   ```

5. **Provide Visual Feedback**
   ```gdscript
   func _activate() -> void:
       if actor and actor.visual_component:
           actor.visual_component.set_alpha(0.5)
   ```

6. **Use Cooldowns to Prevent Spam**
   ```gdscript
   const COOLDOWN = 5.0
   var _cooldown_timer = 0.0
   
   func execute(type: String, value = null) -> void:
       if _cooldown_timer > 0.0:
           return
       # Perform action
       _cooldown_timer = COOLDOWN
   ```

7. **Keep Abilities Self-Contained**
   Each ability should manage its own state, cooldowns, and visual effects.

---

## File Structure

```
res://Core/
├── AbilityData.gd                    # Data-only ability info for UI
└── Abilities/
    └── Dash.gd                       # Example data-only ability

res://Components/ActorComponents/AbilityComponents/
├── AbilityComponent.gd               # Manager that lives on Actor
├── AbilityAction.gd                   # Base class for abilities
├── NimbleEscape.gd                   # Hide / Disengage
├── RedirectAttack.gd                  # Attack redirection
└── GoatCharge.gd                     # Headbutt charge
```

---

## Signal Flow

```
PlayerInputComponent (Input)
        │
        ▼
AbilityComponent.execute_ability()
        │
        ▼
AbilityAction.execute()
        │
        ├── NimbleEscape.execute("hide"/"disengage")
        ├── RedirectAttack.on_targeted_by_attack()
        └── GoatCharge.execute("charge")

Actor takes damage ─ AbilityComponent.on_damage_taken() ─ All actions react
Actor attacks      ─ AbilityComponent.on_attack_performed() ─ All actions react
Actor targeted    ─ AbilityComponent.get_attack_target() ─ All actions check
```

---

## Version Log

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2025-01-10 | Initial documentation |

---

*Sync this document when ability structure changes. Every commit touching ability files should include corresponding documentation updates.*