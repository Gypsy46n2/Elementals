# Breeding System Design Document

<!--
================================================================================
VERSION CONTROL
================================================================================
Document Version: 1.1
Created:         2025-01-XX
Last Updated:    2025-01-28
Status:          IN PROGRESS - Phase 1 Refactor

CHANGELOG:
- 1.1: Added Phase 1-5 refactor plan for actor-agnostic architecture.
	   Marked completed items. Updated file structure.

This document defines the core breeding mechanics for Elementals.
The system is designed to be actor-type-agnostic — any breedable actor
should be able to participate in the breeding system.
================================================================================
-->

## Implementation Status

### ✅ Completed

| Component | File | Status | Notes |
|-----------|------|--------|-------|
| `ActorData` (base) | `res://Components/ActorComponents/ActorData.gd` | ✅ Done | Contains Gender enum, breeding fields (is_pregnant, pregnancy_timer, pregnancy_father, is_exhausted), visual fields (base_color, pattern_color), get_actor_type() method |
| `GoatData` | `res://Components/BreedingComponents/GoatData.gd` | ✅ Done | Extends ActorData, contains goat-specific traits only |
| `BreedingComponent` | `res://Core/Managers/BreedingComponent.gd` | ✅ Done | Generic `breed(parent_a, parent_b)` using ActorData |
| `GeneticComponent` | `res://Components/BreedingComponents/GeneticComponent.gd` | ✅ Done | Works with ActorData instead of GoatData |
| `GoatManager` → `HerdManager` | `res://Components/BreedingComponents/HerdManager.gd` | ✅ Done | Renamed and updated to actor-agnostic types |
| `HerdComponent` | `res://Core/Managers/HerdComponent.gd` | ✅ Done | Updated to `Array[ActorData]` |
| Generic GameEvents | `res://Core/GameEvents.gd` | ✅ Done | Added `actor_selection_toggled` signal, deprecated `goat_selection_toggled` |

### ❌ Not Yet Implemented

| Component | File | Status | Notes |
|-----------|------|--------|-------|
| `BreedableComponent` | `res://Components/BreedingComponents/BreedableComponent.gd` | ❌ Not created | Planned but not needed for Phase 1 |
| `TraitInheritanceEngine` | `res://Core/Managers/TraitInheritanceEngine.gd` | ❌ Not created | Genetics calculator |
| `GoblinData` | `res://Components/BreedingComponents/GoblinData.gd` | ❌ Not created | Goblin-specific traits |
| `ElementalData` | `res://Components/BreedingComponents/ElementalData.gd` | ❌ Not created | Elemental-specific traits |
| `CaptureComponent` | `res://Components/BreedingComponents/CaptureComponent.gd` | ❌ Not created | Wild capture system |
| `SpawnVarianceConfig` | `res://Components/BreedingComponents/SpawnVarianceConfig.gd` | ❌ Not created | Stat variance for spawned creatures |

## Overview

The breeding system enables players to create new actors through reproduction,
capturing wild specimens, and propagating desirable traits. Rather than being
goat-specific, the system operates on the `ActorData` infrastructure, allowing
flexible extension to any actor type (goblins, elementals, wildlife, etc.).

---

## Actor-Agnostic Refactor Plan

### Current Architecture Issues

The system has tight coupling that prevents easy extensibility:

| Issue | Location | Problem |
|-------|----------|---------|
| `GoatManager` autoload | Global | Adding Goblins requires a `GoblinManager` autoload |
| `HerdComponent.herd` | `Array[GoatData]` | Hardcoded to goats only |
| `ActorCard.gd` | `goat_data: GoatData` | UI assumes GoatData type |
| `GoatRenderer.gd` | Visual system | Only renders goat visuals |
| `ActorVisualComponent` | `_setup_goat_visuals(GoatData)` | Visual logic tied to type |
| `GameEvents` signals | `goat_selection_toggled(GoatData, bool)` | Goat-specific events |
| `ItemsAutoload` | `selected_goat: GoatData` | Selection tied to type |

### Refactor Phases

#### Phase 1: Core Infrastructure (LOW RISK)

1. **Rename `GoatManager` → `HerdManager`**
   - Rename file and class_name
   - Update all references from `GoatManager` → `HerdManager`

2. **Make HerdComponent Generic**
   - `Array[GoatData]` → `Array[ActorData]`
   - Methods become type-agnostic

3. **Add `actor_type` Property**
   ```gdscript
   func get_actor_type() -> String:
	   return get_script().get_global_name()  # "GoatData", "GoblinData", etc.
   ```

**Why first**: Low risk refactor - mainly renaming and type generalization.

#### Phase 2: Generic UI Layer (MEDIUM RISK)

4. **ActorCard Refactor**
   - Remove `goat_data` alias
   - Use `actor_data: ActorData` generic
   - Add type-detection for display logic:
   ```gdscript
   func _get_display_name() -> String:
	   match actor_data.get_actor_type():
		   "GoatData": return (actor_data as GoatData).goat_name
		   "GoblinData": return (actor_data as GoblinData).clan_name
		   _: return actor_data.get_actor_type()
   ```

5. **Rename `GoatRenderer` → `ActorCardRenderer`**
   - Type-detection for visual setup
   - Works with any ActorData subclass

6. **Update Ranch.gd**
   - Work with `Array[ActorData]` selection
   - Generic display and breeding UI

**Why second**: UI changes - may need visual testing.

#### Phase 3: Visual Polymorphism (MEDIUM RISK)

7. **ActorVisualComponent Refactor**
   - Replace `_setup_goat_visuals()` with `setup_visuals(ActorData)`
   - Use `match` on script type:
   ```gdscript
   func setup_visuals(data: ActorData) -> void:
	   match data.get_actor_type():
		   "GoatData":
			   _setup_goat_visuals(data as GoatData)
		   "GoblinData":
			   _setup_goblin_visuals(data as GoblinData)
   ```

8. **Add `VisualConfig` Resource** (Optional)
   - Each actor type defines visual requirements
   - Decouples visual logic from ActorData

**Why third**: Visual changes may need testing.

#### Phase 4: Signals & Events (MEDIUM RISK)

9. **Generic GameEvents**
   ```gdscript
   # Rename signals to actor-agnostic
   signal actor_selection_toggled(actor_data: ActorData, is_selected: bool)
   signal actor_bred(parent_a: ActorData, parent_b: ActorData, offspring: ActorData)
   
   # Deprecate old goat-specific signals
   # signal goat_selection_toggled(GoatData, bool)  # DEPRECATED
   ```

10. **Generic ItemsAutoload**
	```gdscript
	var selected_actor_data: ActorData  # Was: selected_goat: GoatData
	```

11. **Search and Update All References**
	```bash
	# Find all goat-specific signal usages
	grep -r "goat_selection_toggled\|selected_goat" --include="*.gd"
	```

**Why fourth**: Must update all signal consumers.

#### Phase 5: Spawning & Factory (LOW RISK)

12. **ActorFactory Pattern**
	```gdscript
	class_name ActorFactory
	
	static func create_actor(actor_data: ActorData) -> Actor:
		var scene: PackedScene = _scenes_by_type.get(actor_data.get_actor_type())
		var actor: Actor = scene.instantiate()
		actor.actor_data = actor_data
		return actor
	```

13. **Refactor ArenaSpawner**
	- Remove hardcoded string → scene mapping
	- Use `ActorFactory` instead of `match type:`

**Why last**: Final architectural cleanup.

### Target Architecture

After refactoring, the system will work like this:

```
ActorData (base)
├── actor_type: String (script name)
├── create_offspring(partner) → virtual
├── get_visual_config() → virtual
│
├── GoatData
│   ├── goat_name, horn_type, body_type, pattern_type
│   └── create_offspring() → goat-specific genetics
│
└── GoblinData (future)
	├── clan_name, tattoo_pattern, skin_color
	└── create_offspring() → goblin-specific genetics
		↓
	ActorVisualComponent.setup_visuals(ActorData)
		↓
	match actor_data.actor_type:
		"GoatData" → setup goat visuals
		"GoblinData" → setup goblin visuals

HerdManager (autoload)
├── HerdComponent.herd: Array[ActorData]
└── Works with ANY ActorData subclass
```

### Risk Assessment

| Phase | Risk | Mitigation |
|-------|------|------------|
| Phase 1 | Breaking existing save/load | Add migration or version bump |
| Phase 2 | UI showing wrong data | Strong type checking |
| Phase 3 | Visual mismatches | Per-type visual config resource |
| Phase 4 | Missing signal handlers | Search for `goat_selection_toggled` usages |

---

## Core Philosophy

### Actor-Agnostic Design

The system does not assume binary gender, sexual reproduction, or any specific
visual appearance. Instead, it defines a **BreedingProtocol** interface that each
actor type can implement according to its own biology:

| Actor Type | Reproduction Style | Notes |
|------------|-------------------|-------|
| Goats | Sexual (DOE × BUCK) | Pregnancy, gestation period |
| Goblins | Sexual (MALE × FEMALE) | Standard reproduction, hybrid vigor possible |
| Mimics | Asexual | Budding/mitosis, self-reproducing |
| Elementals | Spawning | Fire + Fire = Fire (elemental stability) |
| Fire + Water | Combination | Creates hybrid elemental offspring |
| Wildlife | Sexual / Asexual | Varies by species |

### Trait Inheritance Model

Traits are categorized by their inheritance mode:

1. **Mendelian** — Dominant/recessive alleles (horn type, color patterns)
2. **Quantitative** — Polygenic blend (stats, size)
3. **Environmental** — Learned or situational (abilities, faction)
4. **Mutational** — Random chance of novel traits

---

## Data Architecture

### ActorData (Base Resource)

`res://Components/ActorComponents/ActorData.gd`

```gdscript
class_name ActorData
extends Resource

signal stats_changed
signal breeding_state_changed

@export_group("Ability Scores")
@export var strength: float = 1.0
@export var dexterity: float = 1.0
@export var constitution: float = 1.0
@export var intelligence: float = 1.0
@export var wisdom: float = 1.0
@export var charisma: float = 1.0
```

### BreedableComponent (New)

A new component that extends ActorData with breeding-related state:

`res://Components/BreedingComponents/BreedableComponent.gd`

```gdscript
class_name BreedableComponent
extends Node

## Interface for breedable actors.
## Each actor type implements its own reproduction logic.

enum ReproductionMode {
	SEXUAL,           # Requires two parents (male + female)
	ASEXUAL,          # Self-reproducing (budding, spores, mitosis)
	ELEMENTAL,        # Combination-based (Fire + Water = Steam)
	GESTATION         # Pregnancy with timer (subset of SEXUAL)
}

@export var reproduction_mode: ReproductionMode = ReproductionMode.SEXUAL
@export var gestation_period_days: int = 3
@export var fertility_modifier: float = 1.0
@export var inbreeding_tolerance: float = 0.3

var _data: ActorData
var _is_gestating: bool = false
var _gestation_timer: int = 0
var _partner_data: ActorData = null
var _offspring_traits: Array[Dictionary] = []

func can_breed_with(other: ActorData) -> bool:
	## Override per actor type to enforce breeding rules
	pass

func initiate_breeding(partner: ActorData) -> bool:
	## Start breeding process with partner
	pass

func process_gestation() -> Array[ActorData]:
	## Called each day. Returns offspring if gestation complete.
	pass

func inherit_trait(source: ActorData, trait_id: String) -> Variant:
	## Calculate trait value from parent(s)
	pass
```

### ActorDataExtensions (Trait Definitions)

Each actor type extends ActorData with type-specific traits:

#### GoatData (Existing)

```gdscript
@export_group("Visual Traits")
@export var horn_type: HornType = HornType.NONE
@export var body_type: BodyType = BodyType.MEDIUM
@export var pattern_type: PatternType = PatternType.SOLID
@export var base_color: Color = Color.WHITE
@export var pattern_color: Color = Color.GRAY

@export_group("Lifecycle")
@export var age_days: int = 0
@export var is_pregnant: bool = false
@export var pregnancy_timer: int = 0
@export var pregnancy_father: GoatData = null
@export var is_exhausted: bool = false
```

#### GoblinData (New)

```gdscript
class_name GoblinData
extends ActorData

enum GoblinVariant { STANDARD, HOBGOBLIN, BUGBEAR }
enum SkinColor { GREEN, BLUE, BROWN, GRAY }
enum Gender { MALE, FEMALE }  # Standard sexual reproduction

@export_group("Goblin Traits")
@export var goblin_variant: GoblinVariant = GoblinVariant.STANDARD
@export var gender: Gender = Gender.MALE
@export var skin_color: SkinColor = SkinColor.GREEN
@export var has_scars: bool = false
@export var has_tattoos: bool = false
@export var tusk_length: float = 1.0
```

#### ElementalData (New)

```gdscript
class_name ElementalData
extends ActorData

enum ElementType { FIRE, WATER, EARTH, AIR, LIGHTNING, ICE, NATURE }
enum ElementStrength { WEAK, STANDARD, STRONG }

@export_group("Elemental Traits")
@export var primary_element: ElementType = ElementType.FIRE
@export var secondary_element: ElementType = ElementType.NONE
@export var element_strength: ElementStrength = ElementStrength.STANDARD
@export var temperature: float = 20.0  # Celsius, affects interactions
@export var stability: float = 1.0      # Likelihood of elemental combination
```

---

## Breeding Component Architecture

### BreedingManager

`res://Core/Managers/BreedingManager.gd`

Central orchestrator for all breeding operations:

```gdscript
class_name BreedingManager
extends Node

## Manages breeding operations across all herd/actors.
## Delegates type-specific logic to actor-type handlers.

@export var max_herd_size: int = 20
@export var inbreeding_penalty: float = 0.2

func breed(parent_a: ActorData, parent_b: ActorData) -> bool:
	## Initiate breeding between two actors
	## Returns true if breeding was successful
	
func process_daily_gestation(herd: Array[ActorData]) -> Array[ActorData]:
	## Called during day advance. Returns any offspring born.
	
func calculate_offspring_stats(parent_a: ActorData, parent_b: ActorData) -> Dictionary:
	## Blend parent stats with mutation variance
	
func inherit_trait(trait_id: String, parent_a: ActorData, parent_b: ActorData) -> Variant:
	## Resolve trait inheritance based on mode
```

### TraitInheritanceEngine

`res://Core/Managers/TraitInheritanceEngine.gd`

Handles the genetics calculations:

```gdscript
class_name TraitInheritanceEngine

static func blend_stat(parent_a: float, parent_b: float, mutation_range: float = 0.1) -> float:
	var base: float = (parent_a + parent_b) * 0.5
	var mutation: float = randf_range(-mutation_range, mutation_range)
	return base * (1.0 + mutation)

static func select_trait(trait_a: Variant, trait_b: Variant, dominance: Dictionary = {}) -> Variant:
	## Mendelian-style trait selection
	## dominance map: {"trait_value": 0.8} where value > 0.5 is dominant
	pass

static func elemental_combination(element_a: ElementType, element_b: ElementType) -> ElementType:
	## Fire + Water = Steam (new element)
	## Fire + Fire = Fire (stable)
	## Steam + Fire = Superheated Steam, etc.
	pass

static func apply_inbreeding_penalty(stats: Dictionary, inbreeding_coefficient: float) -> Dictionary:
	## Reduce stats based on genetic similarity
	pass
```

---

## Capture System

Wild actors can be captured and added to the player's herd.

### CaptureComponent

`res://Components/BreedingComponents/CaptureComponent.gd`

```gdscript
class_name CaptureComponent
extends Node

## Allows actors to be captured/captured from wild state.

enum CaptureMethod {
    TRAP,           # Use item to capture
    BEFRIEND,       # Win over with items/buffs
    DOMINATE,       # Defeat and claim
    RITUAL          # Magic-based capture
}

@export var capture_difficulty: float = 1.0  # Higher = harder
@export var capture_method: CaptureMethod = CaptureMethod.TRAP
@export var loyalty_required: float = 0.7
@export var base_capture_chance: float = 0.3

var _current_loyalty: float = 0.0

func attempt_capture(capture_item: ItemData = null) -> bool:
    ## Attempt to capture this actor
    ## Returns true if successful
    pass

func increase_loyalty(amount: float) -> void:
    _current_loyalty = clamp(_current_loyalty + amount, 0.0, 1.0)

func decrease_loyalty(amount: float) -> void:
    _current_loyalty = clamp(_current_loyalty - amount, 0.0, 1.0)
```

### Capture Interaction

When interacting with a wild actor:

1. Player uses capture tool or interaction
2. CaptureComponent evaluates:
   - Actor's `capture_difficulty`
   - Capture method bonus
   - Player's capture skill
   - Actor's current loyalty
3. On success: Actor's faction changes to PLAYER, actor_data added to herd
4. On failure: Loyalty penalty, actor may flee

---

## Spawn Variance System

Spawned creatures (elementals, summoned beings, magically created entities) have inherent
stat variance to prevent identical copies. This variance is applied at spawn time.

### Variance Parameters

```gdscript
class_name SpawnVarianceConfig
extends Resource

@export var stat_variance_range: Vector2 = Vector2(-2.0, 2.0)
    ## Min/max deviation applied to each stat.
    ## Example: strength 10 ± 2 → random value in [8, 12]

@export var variance_distribution: VarianceDistribution = VarianceDistribution.UNIFORM
    ## How the random values are distributed

@export var apply_to_all_stats: bool = true
    ## If true, apply variance to all stats equally.
    ## If false, use per-stat variance config.

@export var per_stat_variance: Dictionary = {
    "strength": Vector2(-2, 2),
    "dexterity": Vector2(-1.5, 1.5),
    "constitution": Vector2(-2, 2),
    "intelligence": Vector2(-3, 3),
    "wisdom": Vector2(-3, 3),
    "charisma": Vector2(-1, 1)
}
    ## Per-stat overrides when apply_to_all_stats is false
```

### Variance Distributions

| Distribution | Behavior | Use Case |
|-------------|----------|----------|
| `UNIFORM` | Equal probability across range | Simple, predictable variance |
| `GAUSSIAN` | Bell curve, smaller deviations more likely | Natural stat clustering |
| `BOUNDED` | Gaussian clipped to range | Most natural feeling |

```gdscript
enum VarianceDistribution {
    UNIFORM,   # randf_range(min, max)
    GAUSSIAN,  # Gaussian centered on base stat
    BOUNDED    # Gaussian clipped to [min, max]
}

static func apply_variance(base_stats: Dictionary, config: SpawnVarianceConfig) -> Dictionary:
    match config.variance_distribution:
        VarianceDistribution.UNIFORM:
            return _apply_uniform_variance(base_stats, config)
        VarianceDistribution.GAUSSIAN:
            return _apply_gaussian_variance(base_stats, config)
        VarianceDistribution.BOUNDED:
            return _apply_bounded_variance(base_stats, config)

static func _apply_gaussian_variance(base_stats: Dictionary, config: SpawnVarianceConfig) -> Dictionary:
    var result := base_stats.duplicate(true)
    for stat in result:
        if stat in ["name", "uuid"]:
            continue
        var base: float = result[stat]
        var range_min: float = config.stat_variance_range.x
        var range_max: float = config.stat_variance_range.y
        var variance: float = randfn(0.0, (range_max - range_min) * 0.25)  # ~1 std dev
        variance = clamp(variance, range_min, range_max)
        result[stat] = max(1.0, base + variance)  # Minimum of 1
    return result
```

### Spawn Variance in Actor Types

#### Elementals

```gdscript
class_name ElementalData
extends ActorData

@export var spawn_variance: SpawnVarianceConfig = SpawnVarianceConfig.new()

func _init() -> void:
    super._init()
    spawn_variance.stat_variance_range = Vector2(-1.5, 1.5)
    spawn_variance.variance_distribution = VarianceDistribution.BOUNDED
	# Elementals have tighter variance — they're more consistent
```

#### Goblins (Sexual Reproduction — No Spawn Variance)

```gdscript
# Goblins breed normally, so offspring don't use spawn variance.
# They inherit blended stats from parents instead.
# Spawn variance only applies to wild/despawned goblins respawning.
```

#### Goats (Standard Breeding — No Spawn Variance)

```gdscript
# Domestic goats use parent stat blending.
# Spawn variance might apply to wild goats migrating in.
```

---

## Faction Integration

Breeding and capture both affect faction relationships:

```gdscript
## Breeding effects on faction
BREEDING_NEUTRAL:
    # Newly hatched/spawned actors inherit parent faction
    # OR start as WILDLIFE until captured
    
BREEDING_HOSTILE:
    # Offspring start hostile to player
    # Must be captured to join herd
    
BREEDING_FRIENDLY:
    # Offspring automatically join PLAYER faction
    # Useful for tamed/companion actors
```

---

## State Machine: Actor Lifecycle

```
[Wild]
    │
    ├─── Capture Attempt ──────────► [Captured] ──► [Herd Member]
    │                                      │
    ├─── Defeated (capture on death) ──────┘
    │
    └─── Breeding Available
            │
            ├─── Find Partner
            │
            ├─── [SEXUAL] Partner + Self → [Pregnant]
            │                                  │
            ├─── [ASEXUAL] Self → [Ready to Spawn]    │
            │                                    │
            └─── [ELEMENTAL] Elements Combined    │
                                               │
                                    [Offspring Produced]
                                               │
                            ┌───────────────────┼───────────────────┐
                            ▼                   ▼                   ▼
                       [Wild? (if spawn      [Herd]              [Released]
                        in wild area)]
```

---

## Migration Plan: Actor-Agnostic Refactor

> ⚠️ **Note**: The previous migration plan assumed creating new components from scratch.
> The current approach is to refactor existing components in place, starting with low-risk
> renaming and type generalization before moving to higher-risk UI and signal changes.

### Old Plan (Abandoned)

The original plan called for creating `BreedableComponent.gd`, `BreedingManager.gd`, etc.
as new files. This has been superseded by the **Actor-Agnostic Refactor Plan** above.

### Current Status

**Completed** (2025-01-28):
- ✅ ActorData base class with breeding fields (Gender, is_pregnant, pregnancy_timer, etc.)
- ✅ GoatData extends ActorData with goat-specific traits only
- ✅ BreedingComponent.breed() generic method using ActorData
- ✅ GeneticComponent works with ActorData
- ✅ All Gender references updated from DOE/BUCK to MALE/FEMALE

**In Progress**:
- 🔄 Phase 1: Core Infrastructure (GoatManager → HerdManager)

### Future Migration Steps

#### GoblinData (Post Phase 5)

1. Create `res://Components/BreedingComponents/GoblinData.gd`
2. Implement goblin-specific traits (variant, scars, gender, etc.)
3. Set reproduction_mode = SEXUAL (MALE × FEMALE)
4. Add goblin-specific gestation mechanics (gestation_period_days ≈ 1-2 days)
5. Add capture mechanics (loyalty system)

#### ElementalData (Post Phase 5)

1. Create `res://Components/BreedingComponents/ElementalData.gd`
2. Implement elemental combination table
3. Add stability trait for mutation rates

---

## File Structure

```
res://Components/
├── ActorComponents/
│   └── ActorData.gd                    # ✅ EXISTING: Base class with breeding fields, get_actor_type()
│
├── BreedingComponents/
│   ├── GoatData.gd                     # ✅ EXISTING: Extends ActorData
│   ├── HerdManager.gd                  # ✅ RENAMED: Was GoatManager, now actor-agnostic
│   ├── GeneticComponent.gd             # ✅ EXISTING: Works with ActorData
│   ├── BreedableComponent.gd           # ❌ NOT NEEDED: ActorData provides base functionality
│   ├── TraitInheritanceEngine.gd       # ❌ TODO: Genetics calculator
│   ├── GoblinData.gd                   # ❌ TODO: Goblin-specific traits
│   ├── ElementalData.gd                # ❌ TODO: Elemental-specific traits
│   ├── CaptureComponent.gd             # ❌ TODO: Wild capture system
│   └── SpawnVarianceConfig.gd          # ❌ TODO: Stat variance for spawned creatures
│
├── Ranch/
│   └── Ranch.gd                        # ✅ EXISTING: Updated to use HerdManager
│
└── UI/
    ├── ActorCard.gd                    # ✅ UPDATED: Uses HerdManager
    └── GoatRenderer.gd                 # 🔄 TO RENAME: ActorCardRenderer (Phase 2)

res://Core/
├── Managers/
│   ├── BreedingComponent.gd            # ✅ EXISTING: Generic breed() method
│   ├── HerdComponent.gd                # ✅ UPDATED: Array[ActorData] instead of Array[GoatData]
│   ├── ProgressionComponent.gd        # 🔄 TO UPDATE: Phase 2
│   ├── SaveComponent.gd                # 🔄 TO UPDATE: Phase 2
│   └── EconomyComponent.gd             # ✅ EXISTING: No herd type dependencies
│
├── GoatSaveData.gd                     # 🔄 TO RENAME: HerdSaveData (Phase 2)
└── GameEvents.gd                       # ✅ UPDATED: actor_selection_toggled signal
```

---

## Example: Creating a Hybrid Elemental

```gdscript
# FireActor + WaterActor breeding
func elemental_breed(element_a: ElementData, element_b: ElementData) -> ElementData:
    match [element_a.primary_element, element_b.primary_element]:
        [ElementType.FIRE, ElementType.WATER]:
            return _create_steam_elemental(element_a, element_b)
        [ElementType.FIRE, ElementType.FIRE]:
            return _stabilize_fire_elemental(element_a)
        [ElementType.STEAM, ElementType.FIRE]:
            return _create_superheated_steam(element_a, element_b)
```

---

## Next Steps

### Immediate (Phase 1 - Core Infrastructure)

- [x] ✅ ActorData base class with breeding fields (completed 2025-01-28)
- [x] ✅ GoatData extends ActorData (completed 2025-01-28)
- [x] ✅ BreedingComponent.breed() generic method (completed 2025-01-28)
- [x] ✅ Rename `GoatManager` → `HerdManager` (completed 2025-01-28)
- [x] ✅ Make `HerdComponent.herd` generic (`Array[ActorData]`) (completed 2025-01-28)
- [x] ✅ Add `get_actor_type()` method to ActorData (completed 2025-01-28)
- [x] ✅ Add generic `actor_selection_toggled` GameEvents signal (completed 2025-01-28)

### Phase 2 (Generic UI Layer)

- [ ] ⬜ Refactor ActorCard to use `ActorData` generic
- [ ] ⬜ Rename `GoatRenderer` → `ActorCardRenderer`
- [ ] ⬜ Update Ranch.gd for generic actor selection

### Phase 3 (Visual Polymorphism)

- [ ] ⬜ Refactor ActorVisualComponent.setup_visuals() for type detection
- [ ] ⬜ (Optional) Add VisualConfig resource

### Phase 4 (Signals & Events)

- [ ] ⬜ Update GameEvents signals to be actor-agnostic
- [ ] ⬜ Update ItemsAutoload.selected_goat → selected_actor_data

### Phase 5 (Spawning & Factory)

- [ ] ⬜ Create ActorFactory pattern
- [ ] ⬜ Refactor ArenaSpawner to use ActorFactory

### Future (Post-Refactor)

- [ ] ⬜ Implement TraitInheritanceEngine
- [ ] ⬜ Create GoblinData with traits
- [ ] ⬜ Create ElementalData with combination table
- [ ] ⬜ Implement CaptureComponent
- [ ] ⬜ Add capture tool items

---

*This document is the source of truth for breeding mechanics.*
*Update version log when making significant changes.*
