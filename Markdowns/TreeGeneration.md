# Tree Generation Blueprint

This document captures the procedural tree generation system for the Arena project. It establishes the goals, randomized blueprint rules, harvest workflow, resource implications, and integration points that will eventually replace the current sprite-based tree spawning tied directly to tile generation.

---

## 1. Design Rationale

- **Separation of concerns:** Trees should be generated independently from tile placement. Currently `GridGenerator.spawn_initial_trees()` instantiates a shared tree feature scene during grid generation, which couples visual feature placement tightly with terrain math. Moving tree logic into its own subsystem keeps the grid generator focused on tiles and allows tree rules to evolve without duplicating terrain code.
- **Blueprint-driven construction:** Feature scenes should be interpreted through blueprint data, which describes how many primitives to assemble, how they bend or branch, and how foliage is layered. This makes it easy to author multiple tree species and vary their look and behavior without hand-crafting each variant in the editor.
- **Harvest complexity:** Trees should not all yield the same amount of wood. A larger, more complex tree (taller trunk, more branches/foliage) should award proportionally more resources when the player harvests it. The blueprint should therefore expose the parameters needed for resource calculation.
- **Two-phase harvest model:** Felling and processing are distinct phases. An actor must fell a tree (producing a log) before they can process it. This creates meaningful interaction time and makes the world feel more alive.
- **Actor-agnostic interactions:** Both the player and NPCs must be able to harvest trees. The system uses a target selection model rather than player-exclusive interactions.

---

## 2. Goals and Constraints

1. **Loose coupling from terrain generation.** A dedicated tree spawner subsystem should run after tile generation, querying the grid for valid placement tiles but not reusing tile generation code.
2. **Construct trees from simple primitives.** Trunks should consist of stacked cylinders/cones, with optional bend segments tuned by a "jank factor". Branches are similar primitives attached along the trunk. Foliage layers are built from spheres/cones adjusted to form layered canopies. All primitives use CSG nodes for easy configuration and runtime adjustment.
3. **Controlled randomness.** All major tree attributes (trunk height, branch count, branch placement, foliage count, etc.) should be randomized within configurable ranges to ensure variation while staying within plausible bounds.
4. **Harvest yield data.** Blueprints must provide enough information to derive a wood yield (raw resource). The yield table should scale with trunk height, branch count, and foliage volume.
5. **Varying density.** The spawner must support anything from sparse plains to dense forests, driven by biome data.
6. **Simple collision.** A single cylinder collider at the trunk base handles harvest detection. No per-branch collision needed.

---

## 3. Blueprint Structure

### 3.1 Trunk Configuration
A `TreeBlueprint` resource will describe the trunk as a stack of segments.

| Property | Description | Example Range |
|----------|-------------|---------------|
| `base_height` | Total height of the trunk | 4.0 – 12.0 units |
| `base_radius` | Radius at the bottom of the trunk | 0.5 – 2.0 units |
| `segment_count` | Number of cylindrical/conical sections | 2 – 4 |
| `jank_factor` | Maximum bend angle per segment (degrees) | 0° – 15° |
| `segment_randomness` | Variation modifier applied to each segment's height/rotation | ±10% |

Each segment will be positioned relative to the previous one. The `jank_factor` controls how much rotation offset is introduced between successive segments, introducing a subtle lean or twist that distinguishes one tree from another.

### 3.1.1 Trunk Origin Requirement

The trunk of a tree must **always** have its origin (one end of the cylinder) fixed to the ground. This is a hard constraint that must be maintained at all times during tree construction:

- **Origin (ground point):** The first end of the trunk cylinder must be 100% anchored to the ground (Y = 0 or tile surface level). This point never moves.
- **Terminal point:** The opposite end of the cylinder is the terminal point. This is the point that may have slight bend/jank applied through segment rotations.

The jank factor and segment rotations affect the terminal point and subsequent segments — never the origin. This ensures trees look grounded and natural rather than floating or partially buried.

### 3.1.2 Trunk Segment Chaining Algorithm

For proper tip-to-tip connection between trunk segments, follow this formal algorithm:

```
For each trunk segment index i from 0 to segment_count - 1:

1. CALCULATE SEGMENT HEIGHT
   - segment_height = total_trunk_height / segment_count
   - Apply random variation: segment_height *= randf_range(1 - segment_randomness, 1 + segment_randomness)

2. DETERMINE ORIGIN AND TERMINAL POINTS

   IF i == 0 (first segment):
	 origin_point = Vector3(0, 0, 0)  # Fixed to ground
	 Calculate jank rotation (azimuth, inclination) based on jank_factor
	 Apply rotation to "up" direction to get segment_axis
	 terminal_point = origin_point + (segment_axis * segment_height)
   
   ELSE (subsequent segments):
	 origin_point = previous_segment.terminal_point  # Chain from previous
	 Calculate incremental jank rotation
	 Apply rotation incrementally to running direction
	 terminal_point = origin_point + (segment_axis * segment_height)

3. CALCULATE CYLINDER PLACEMENT
   center_point = (origin_point + terminal_point) / 2
   cylinder_length = origin_point.distance_to(terminal_point)

4. CALCULATE CYLINDER ROTATION
   The cylinder's local Y-axis must align with the segment axis:
   - rotation_quaternion = Quaternion that rotates Vector3.UP to segment_axis
   - Convert to euler degrees for CSG node

5. PLACE CYLINDER
   cylinder.position = center_point
   cylinder.rotation = rotation_quaternion_as_euler
   cylinder.height = cylinder_length  # Cylinder height is the distance between points
```

**Key Rules:**
- First segment origin is always at ground level (Y = 0)
- Each subsequent segment's origin equals the previous segment's terminal point
- Cylinder `height` property equals the calculated segment length (not a fixed value)
- Rotation aligns the cylinder's long axis with the segment direction vector
- Jank rotations accumulate incrementally (not random per-segment)

### 3.2 Branch Rules
Branches sprout from the trunk at randomized heights and angles.

| Property | Description | Range |
|----------|-------------|-------|
| `branch_count_min/max` | How many branches to spawn | 2 – 8 |
| `branch_length_range` | Branch length (units) | 1.0 – 4.0 |
| `branch_angle_variance` | Vertical tilt variance for each branch in degrees | 10° – 35° |
| `branch_radius_ratio` | Relative radius compared to trunk segment | 0.4 – 0.7 |
| `attachment_height_padding` | Avoid top/bottom extremes by reserving a height buffer | 10% – 20% of trunk height |

Branches are represented by tapered cylinders or cones and optionally emit their own foliage clusters if enabled. Each branch can also have a subtle random bend to emphasize the "jank" effect of older trees.

### 3.3 Foliage Layers
Foliage is constructed from spheres/cones layered around the upper trunk and branches.

| Property | Description | Range |
|----------|-------------|-------|
| `foliage_layers_min/max` | Number of distinct canopy layers | 1 – 4 |
| `foliage_shape` | Primitive type (sphere, cone, capsule) | [configurable] |
| `foliage_size` | Radius of each foliage sphere | 0.5 – 4.0 units |
| `foliage_scale` | Uniform scale multiplier applied to all foliage | 0.5 – 3.0 |
| `leaf_size` | Size of individual leaf/foliage clusters in shader. Higher = larger, fewer pieces | 0.5 – 4.0 |
| `layer_offset_variance` | Up/down offset jitter per layer | ±0.5 units |
| `layer_scale_variance` | Scale jitter per layer | ±15% |
| `layer_rotation_variance` | Random rotation when placing each layer | 0° – 30° |
| `foliage_density` | How many primitives per layer (for spread) | 2 – 5 |

Foliage layers are stacked vertically. Each layer can be composed of multiple primitives spread around the trunk circumference to produce bushy canopies.

The `leaf_size` parameter controls the visual appearance of foliage in the shader. Higher values create chunkier, more solid-looking leaves, while lower values produce denser, more intricate foliage with more individual pieces visible.

---

## 4. Randomization Parameters Summary

| Parameter | Purpose | Suggested Domain |
|-----------|---------|------------------|
| `TreeBlueprint.trunk_height` | Controls visual scale and wood yield. | 4.0 – 12.0 |
| `TreeBlueprint.jank_factor` | Determines trunk bend extremity. | 0 – 15° |
| `TreeBlueprint.branch_count` | Influences canopy complexity and resource yield. | 2 – 8 |
| `TreeBlueprint.branch_length` | Varies silhouette length. | 1.0 – 4.0 |
| `TreeBlueprint.foliage_layers` | Sets canopy height. | 1 – 4 |
| `TreeBlueprint.foliage_jitter` | Adds asymmetry to layers. | ±10% |
| `TreeBlueprint.foliage_density` | Controls how lush each layer appears. | 2 – 5 primitives |

Random seeds should be exposed when needed (e.g., for deterministic level generation) while still allowing `randf()` or `randi()` based randomness for in-game tree spawning.

---

## 5. Resource Yield Table

Each physical piece of a tree yields a unit of resource when harvested. Wood comes from trunk segments and branches; leaf litter comes from foliage layers (a trash/placeholder item until it has a use).

### 5.1 Wood Yield Formula

```
wood_yield = segment_count + branch_count
```

| Piece Type | Count Range | Wood Per Piece | Total Wood Range |
|------------|-------------|----------------|------------------|
| Trunk segments | 2 – 4 | 1 | 2 – 4 |
| Branches | 2 – 8 | 1 | 2 – 8 |
| **Total** | — | — | **4 – 12** |

### 5.2 Leaf Litter Yield Formula

```
leaf_litter_yield = foliage_layer_count
```

| Foliage Volume | Layers Range | Leaf Litter Range |
|----------------|--------------|-------------------|
| Low | 1 – 2 | 1 – 2 |
| Medium | 2 – 3 | 2 – 3 |
| High | 3 – 4 | 3 – 4 |

### 5.3 Combined Yield Table

| Tree Size | Trunk Height | Segments | Branches | Layers | **Wood** | **Leaf Litter** |
|-----------|--------------|----------|----------|--------|----------|-----------------|
| Small | 4.0 – 6.0 | 2 | 2 – 4 | 1 – 2 | 4 – 6 | 1 – 2 |
| Medium | 6.0 – 9.0 | 3 | 3 – 6 | 2 – 3 | 6 – 9 | 2 – 3 |
| Large | 9.0 – 12.0 | 4 | 5 – 8 | 3 – 4 | 9 – 12 | 3 – 4 |

Leaf litter is a placeholder resource. It spawns on harvest but has no consumer use yet.

---

## 6. Biome System

Each biome is defined by a `BiomeData` resource that controls what trees spawn and how densely.

```gdscript
class_name BiomeData
extends Resource

@export var name: String
@export var tree_blueprint: TreeBlueprint
@export var spawn_density: float  # 0.0 – 1.0, controls tree frequency
@export var valid_terrain: Array[int]  # TileConstants.State values
@export var valid_tile_types: Array[int]  # TileConstants.Type values
```

| Property | Description |
|----------|-------------|
| `name` | Human-readable biome name (e.g., "Oak Forest", "Boreal Woodland") |
| `tree_blueprint` | Reference to the blueprint this biome uses |
| `spawn_density` | 0.0 = no trees, 1.0 = maximum density |
| `valid_terrain` | Which tile states this biome allows (e.g., GRASS, DIRT) |
| `valid_tile_types` | Which tile types this biome allows |

The `TreeSpawner` queries tile terrain and type, looks up the appropriate `BiomeData`, and uses `spawn_density` to determine whether to place a tree. This replaces the current flat 5% probability roll.

### Density Thresholds

| Density Value | Behavior |
|---------------|----------|
| 0.0 – 0.1 | Sparse: occasional trees, clear plains |
| 0.1 – 0.4 | Light: scattered trees, parkland feel |
| 0.4 – 0.7 | Moderate: regular spacing, typical woodland |
| 0.7 – 1.0 | Dense: closely packed, dense forest |

---

## 7. Mesh Construction (CSG)

Trees are built from CSG (Constructive Solid Geometry) nodes for simplicity:

| Primitive | Node Type | Usage |
|-----------|-----------|-------|
| Trunk segments | `CSGCylinder3D` | Stacked with slight rotations for jank |
| Branches | `CSGCylinder3D` | Tapered cylinders angled off trunk |
| Foliage clusters | `CSGSphere3D` | Groups layered around upper trunk/branches |

CSG nodes are chosen over `MeshInstance3D` for:
- Easy runtime reconfiguration (hide/show, swap color)
- Simpler collision (single collider covers the whole tree)
- Lower iteration cost during development

When visual quality becomes a priority, these can be replaced with `MeshInstance3D` nodes without changing the blueprint structure.

### Materials

Trees use a single shared `ShaderMaterial` or `StandardMaterial3D` resource. Variant tinting is applied at runtime via `albedo_color`. This allows:

1. One base material asset in the project
2. Per-tree color variation without duplicating material resources
3. Easy future expansion (vertex colors, noise-based color variation per blueprint)

```gdscript
# Example: Apply variant tint to a tree
var mat = tree_trunk.get_surface_material(0).duplicate()
mat.albedo_color = Color(randf_range(0.8, 1.0), randf_range(0.6, 0.9), randf_range(0.7, 0.8))
tree_trunk.set_surface_material(0, mat)
```

---

## 8. Harvest System

### 8.1 Interaction Model

Trees use a **target selection system** rather than direct player interaction:

1. Actor equips a valid tool (axe)
2. Actor selects a tree within interaction range
3. Actor performs harvest actions on the selected tree

This model supports both the player (via input) and NPCs (via AI), since both can share the same targeting and action logic.

### 8.2 Hitpoint System (Concurrent Harvesting)

To safely handle multiple actors harvesting the same tree simultaneously, trees use an HP pool rather than discrete state transitions managed by any single actor.

**HP Calculation:**
```
max_hp = base_hp + (trunk_height * height_factor) + (branch_count * branch_factor)
```

| Tree Size | Trunk Height | Branches | Max HP |
|-----------|--------------|------------------|--------|
| Small | 4.0 – 6.0 | 2 – 4 | 10 – 20 |
| Medium | 6.0 – 9.0 | 3 – 6 | 20 – 35 |
| Large | 9.0 – 12.0 | 5 – 8 | 35 – 55 |

**Damage per hit:**
- Tool damage is subtracted from tree HP
- Each successful hit spawns a log pile fragment (partial yield)
- Tree transitions to FELLEDB when HP reaches 0 (no active actor owns this state)

**Benefits:**
- No actor ownership — any actor can hit any tree simultaneously
- Yields scale naturally with tree size (more HP = more potential hits = more total yield)
- Graceful partial harvest — if interrupted, actor keeps what they've gathered

### 8.3 Harvest State Machine

Trees follow a two-phase harvest workflow:

```
STANDING → FELLING → FELLEDB → PROCESSING → LOGS_READY
```

| State | Description | Transition |
|-------|-------------|------------|
| `STANDING` | Tree is upright, idle. Interactable with axe. | Any actor hits tree until HP = 0 |
| `FELLING` | Play fall animation. Tree becomes grounded. | Animation complete |
| `FELLEDB` | Tree is on the ground. Actor must approach with tool to begin processing. | Actor begins processing |
| `PROCESSING` | Repeated hits remove branch meshes and spawn log piles nearby. | All branches processed |
| `LOGS_READY` | One or more `LogPile` nodes exist at the tile. Haulable via normal pickup. | Actor takes log pile |

### 8.4 Fall Animation

The fall animation uses **AnimationPlayer** for smooth, non-instantaneous transition. This approach is chosen over tweening or `_process` rotation because:

- **Blendable** — can crossfade with idle animations if needed
- **looped=false** — animation plays once and stops cleanly
- **Callbacks via `_animation_finished`** — transitions to FELLEDB state after animation completes
- **Easy to tune** — adjust keyframes in the editor for different tree sizes

**Animation setup:**
- Tracks rotation on the tree root node
- Tree rotates from upright (0°) to grounded (~90° from vertical)
- Duration: 0.8 – 1.2 seconds for convincing weight
- Easing: `ease_out` — fast initial fall, slow impact

```
Felling animation track:
  frame 0:   rotation_degrees = 0
  frame 24:  rotation_degrees = 85  (at 1.0 second, 24fps)
```

The animation is authored once and reused across all tree sizes. If trees of significantly different scale need different animation timings, the `TreeFeature` can adjust the AnimationPlayer's `speed_scale` based on blueprint parameters.

### 8.5 HarvestableComponent

Trees attach a `HarvestableComponent` that manages state, HP, and interactions:

```gdscript
class_name HarvestableComponent
extends Node

enum State { STANDING, FELLING, FELLEDB, PROCESSING, LOGS_READY }

signal state_changed(new_state: State)
signal fully_harvested()
signal damage_received(amount: int, actor: Node3D)

@export var current_state: State = State.STANDING
@export var interaction_range: float = 3.0
@export var log_pile_scene: PackedScene

var max_hp: int
var current_hp: int
```

**HP Integration:**
- `max_hp` is computed from `TreeBlueprint` parameters on `_ready()`
- `current_hp` starts at `max_hp` and decrements per hit
- `damage_received` signal allows visual feedback (shake, particles)
- Any actor can damage the tree — no ownership required

**Key methods:**
- `can_interact(actor: Node3D, tool_type: String) -> bool` — validates actor proximity and tool
- `apply_damage(amount: int, actor: Node3D) -> void` — reduces HP, spawns partial yield, transitions on HP = 0
- `process_branch(actor: Node3D) -> void` — removes one branch, spawns a log pile
- `get_yield() -> Dictionary` — returns `{wood: int, leaf_litter: int}` based on piece count

### 8.6 Collision Setup

A single `CollisionShape3D` (cylinder) at the trunk base handles harvest detection. No per-branch collision needed.

```gdscript
# Approximate collision for harvest detection
var collider = CollisionShape3D.new()
var shape = CylinderShape3D.new()
shape.radius = blueprint.base_radius * 1.5
shape.height = blueprint.base_height
collider.shape = shape
add_child(collider)
```

This collider also blocks actor movement through the tree.

### 8.7 Log Piles

Processing a tree produces `LogPile` nodes that spawn adjacent to the fallen tree. Log piles are themselves `HarvestableComponent` entities:

| Property | Description |
|----------|-------------|
| `log_count` | Number of logs in the pile |
| `weight` | Affects actor movement speed when hauling |
| `haulable` | Boolean — true when pile can be picked up |

Actors pick up a log pile, carry it to a destination, and drop it. Empty piles are automatically deleted — no manual cleanup needed. When `log_count` reaches 0, the node queues itself for free via `queue_free()`.

### 8.8 Persistence (Save/Load & Day Reset)

Harvest progress does not persist across save/load or day transitions.

**Save/Load:**
- Trees are regenerated from `TreeBlueprint` on load — no per-tree state is saved
- `LogPile` nodes left on the ground are tracked independently and persist via the tile/world save system

**Day Transition:**
- Any tree with `current_hp < max_hp` resets to `current_hp = max_hp` on new day
- Trees in `FELLING`, `FELLEDB`, `PROCESSING`, or `LOGS_READY` states reset to `STANDING`
- Log piles remain — they represent already-harvested resources and persist normally

```
On day change:
	if current_state != State.STANDING or current_hp < max_hp:
		reset_to_standing()
```

This is a deliberate design choice: the arena regenerates each day, keeping the loop consistent with other harvestable resources.

---

## 9. Placement System

### 9.1 Current State (GridGenerator.gd)

`GridGenerator.spawn_initial_trees()` uses a flat 5% probability roll on grass tiles outside the farmstead area:

```gdscript
func spawn_initial_trees() -> void:
	for tile in arena.tile_data_grid:
		if tile.current_state == TileConstants.State.GRASS:
			if tile in farmstead_interior_tiles or tile in farmstead_perimeter_tiles:
				continue
			if randf() < 0.05:
				spawn_tree(tile)
```

This is a starting point, not final placement logic.

### 9.2 TreeSpawner

A dedicated `TreeSpawner` service replaces `GridGenerator.spawn_initial_trees()`:

```gdscript
class_name TreeSpawner
extends Node

func spawn_for_biome(biome: BiomeData, tiles: Array[HexTileData]) -> void
func spawn_for_tile(tile: HexTileData, blueprint: TreeBlueprint) -> void
func calculate_density(tile: HexTileData) -> float
```

**Responsibilities:**
1. Filter tiles by biome terrain/type constraints
2. Apply `spawn_density` probability to eligible tiles
3. Enforce spacing rules (minimum distance between trees)
4. Instantiate trees using the biome's blueprint

### 9.3 Spacing Rules

Trees occupy exactly one hex tile. The spawner enforces a **1:1 tile-to-tree ratio** — no tile can hold more than one tree:

```gdscript
# Check if tile already has a tree before placing
if tile.occupied_by_tree:
	continue
tile.occupied_by_tree = true  # mark after placing
```

This replaces the flexible `min_tree_spacing` radius approach. Direct 1:1 occupancy is simpler, easier to validate, and matches the grid structure naturally.

---

## 10. Removal Plan (Old Tree System)

The current tree system uses a sprite-based `TreeFeature` with a lifecycle state machine (`PINECONE → SAPLING → TREE → STUMP/BURNT_STUMP`). The new blueprint-driven harvest system replaces it entirely. The following steps document the migration path.

### 10.1 Components to Remove

| File/Location | Current Role | Action |
|--------------|--------------|--------|
| `res://Play Space/tree_feature.tscn` | Scene for all tree states | Replace with new `TreeFeature` scene using CSG |
| `res://Play Space/TreeFeature.gd` | State machine + lifecycle logic | Refactor: strip state machine, add CSG construction + `HarvestableComponent` |
| `res://Play Space/TreeStates/TreeState.gd` | Base state class | Remove after migration |
| `res://Play Space/TreeStates/TreeMaturedState.gd` | Mature tree behavior | Remove |
| `res://Play Space/TreeStates/TreeSaplingState.gd` | Sapling behavior | Remove |
| `res://Play Space/TreeStates/TreePineconeState.gd` | Pinecone state (pushable) | Remove — pushable behavior can be revived later as a separate feature if needed |
| `res://Play Space/TreeStates/TreeStumpState.gd` | Stump state | Remove |
| `res://Play Space/TreeStates/TreeBurntStumpState.gd` | Burnt stump state | Remove |
| `res://Play Space/TreeStates/TreeStateData.gd` | State data container | Remove |
| `res://Play Space/TreeStates/TreeSpecies.gd` | Species with per-state data | Remove — biome data replaces species |
| `res://Play Space/TreeStates/GenericPine.tres` | Species resource | Remove — `TreeBlueprint` and `BiomeData` resources replace this |
| `res://assets/generated/archive/tree_simple*.png` | Sprite textures | Move to archive folder if not already there |
| `res://assets/SoundFiles/Tree fall.mp3` | Tree fall sound | Retain — used by new harvest animation |
| `GridGenerator.gd` lines 195–211 | `spawn_initial_trees()` + `spawn_tree()` | Remove after `TreeSpawner` is implemented |

### 10.2 Components to Refactor

| File | Change |
|------|--------|
| `res://Play Space/Arena.gd` | Remove `tree_feature_scene` export (line 7). `TreeSpawner` manages instantiation. |
| `res://Play Space/TreeFeature.gd` | Strip the state machine (`State` enum, `_update_state_node`, `current_state_node`). Replace sprite rendering with CSG primitive construction driven by `TreeBlueprint`. Add `HarvestableComponent` as a child. |

### 10.3 Migration Order

1. **Create** new resources (`TreeBlueprint`, `BiomeData`, `HarvestableComponent`, `LogPile`) and `TreeSpawner` service.
2. **Build** new `TreeFeature` scene with CSG construction + `HarvestableComponent`. Validate in isolation.
3. **Integrate** `TreeSpawner` into `GridGenerator` or `ArenaGrid`, replacing `spawn_initial_trees()`.
4. **Update** `ArenaGrid` to remove `tree_feature_scene` export once spawner owns tree creation.
5. **Delete** old state files (`TreeStates/` directory, old `TreeFeature.gd`).
6. **Clean up** sprite textures not already in the archive folder.

### 10.4 Features to Revisit Later

The new system does not initially support:
- **Pinecone push mechanic** — pinecones are removed in this migration. If needed, implement as a separate lightweight entity later.
- **Sapling growth** — trees are harvested directly without a growth lifecycle. If a farming/growth simulation is desired, add a `GrowingTreeFeature` variant.
- **Fire spread from trees** — the current fire-damage accumulator in `TreeFeature._process()` will be removed. Fire interaction on `HarvestableComponent` can be re-added if needed.

---

## 11. Integration Points

1. **TreeBlueprint resource:** Create `res://Resources/Trees/TreeBlueprint.tres` defining parameter ranges and defaults.
2. **BiomeData resource:** Create `res://Resources/Trees/BiomeData.tres` for oak forest, boreal woodland, etc.
3. **TreeFeature scene:** Refactor `TreeFeature.gd` to accept a `TreeBlueprint` and build trunk, branches, and foliage from CSG primitives.
4. **HarvestableComponent:** New component attached to tree features that manages harvest state machine and interaction callbacks.
5. **LogPile scene:** A scene for processed log piles with their own `HarvestableComponent` for pickup and hauling.
6. **TreeSpawner service:** A service that runs after grid generation, queries biome data, and spawns trees at valid tiles.
7. **Actor targeting:** `ActorController` or a dedicated `TargetComponent` handles selecting harvestable entities within range.
8. **Harvest yields:** Blueprint metrics compute wood yield per tree (placeholder table in section 5).

---

## 12. Next Steps

1. **Define resources.** Create `TreeBlueprint.tres` and `BiomeData.tres` with typed properties and default ranges.
2. **Build CSG trees.** Refactor `TreeFeature.gd` to construct a tree from CSG nodes driven by blueprint parameters. Single material with runtime tinting.
3. **Implement HarvestableComponent.** Attach to `TreeFeature` to manage state transitions and interaction callbacks.
4. **Build LogPile scene.** Create a simple log pile prefab with its own `HarvestableComponent` for pickup.
5. **Implement TreeSpawner.** Read biome data, filter valid tiles, apply spacing rules, and instantiate trees.
6. **Connect actor targeting.** Allow actors to select and interact with `HarvestableComponent` entities using equipped tools.
7. **Tune parameters.** Adjust spawn density, spacing rules, and harvest yields through playtesting.
8. **Add editor tooling** (future): Inspector preview for `TreeBlueprint` showing the generated tree silhouette.

---

## 13. Performance Considerations

The project targets smooth performance on older hardware. All tree-related systems are designed with this constraint in mind.

### 13.1 CSG vs MeshInstance

CSG nodes are used during development for iteration speed. However, they recalculate geometry every frame if modified at runtime. The long-term plan is mesh baking:

- **Development:** CSG for rapid prototyping and parameter tuning
- **Production:** Replace CSG with pre-baked `MeshInstance3D` after finalizing blueprints
- **No runtime CSG modification** — once baked, trees are static meshes

### 13.2 Level of Detail (LOD)

Dense forests with many trees require distance-based LOD to maintain frame rate:

**LOD Levels:**
| Level | Distance | Representation |
|-------|----------|-----------------|
| LOD0 | 0 – 30 units | Full tree (trunk + branches + foliage) |
| LOD1 | 30 – 60 units | Simplified trunk + canopy blob |
| LOD2 | 60 – 100 units | Single billboard quad or low-poly silhouette |
| LOD3 | 100+ units | Hidden (culled) |

**Implementation:**
- Each `TreeBlueprint` defines simplified mesh references for LOD1–LOD2
- `TreeFeature` switches mesh representation based on distance to camera
- LOD transitions use `LOD3D` node (Godot 4.3+) or manual distance checks
- Trees auto-switch to LOD0 when any actor approaches for harvesting

**LOD Switching:**
```gdscript
func _process_lod() -> void:
	var cam := get_viewport().get_camera_3d()
	var dist := global_position.distance_to(cam.global_position)
	
	if dist < 30:
		_set_lod(0)
	elif dist < 60:
		_set_lod(1)
	elif dist < 100:
		_set_lod(2)
	else:
		_set_lod(3)  # hide
```

### 13.3 Spawn Budgeting

To prevent frame spikes during world generation, tree spawning is spread across multiple frames:

```gdscript
const SPAWN_BATCH_SIZE := 10  # trees per frame

func _deferred_spawn_trees(trees: Array) -> void:
	var batch: Array = trees.slice(0, SPAWN_BATCH_SIZE)
	var remaining: Array = trees.slice(SPAWN_BATCH_SIZE)
	
	for tile in batch:
		_spawn_single_tree(tile)
	
	if not remaining.is_empty():
		await get_tree().process_frame
		_deferred_spawn_trees(remaining)
```

### 13.4 Batching Guidelines

| Optimization | Target |
|-------------|--------|
| Shared materials | All trees share one `ShaderMaterial` with per-instance color tinting |
| Static colliders | Collision shapes set to `disabled = true` when tree is too far for interaction |
| Shadow casting | LOD1+ meshes disable shadow casting |
| Max active trees | Hard cap of ~200 trees visible at once; culling activates beyond that |

---

## 14. Animation Ownership

The fall animation is triggered by `HarvestableComponent`, not the tree itself. This keeps harvest logic centralized:

```
HarvestableComponent.apply_damage()
  → if HP reaches 0:
	  → current_state = State.FELLING
	  → AnimationPlayer.play("fall")
	  → _animation_finished callback → State.FELLEDB
```

`TreeFeature` exposes a reference to its `AnimationPlayer` so `HarvestableComponent` can trigger playback. No tree-specific animation code exists outside `HarvestableComponent`.

---

## 16. Foliage Visibility System

Trees naturally obstruct the player's view of their character and spotted enemies. The foliage visibility system dynamically increases the transparency of tree foliage and trunks when they occlude important targets, improving player awareness without removing trees from the scene.

### 16.1 Design Goals

1. **Character visibility:** The player must always be able to see their character, even when it is directly behind a tree trunk or within the canopy.
2. **Spotted enemy visibility:** Enemies that the player's Actor has identified as a target should remain partially visible through foliage.
3. **Non-disruptive transparency:** Trees should fade smoothly rather than pop to full transparency, preserving the forest atmosphere.
4. **Performance-friendly:** The system should not require per-pixel raycasting or expensive shaders.

### 16.2 Occlusion Targets

The system tracks "visible actors" — entities whose visibility through foliage is prioritized:

| Target | Source of Truth | Notes |
|--------|-----------------|-------|
| Player character | `Actor` or `PlayerController` node | Always visible |
| Spotted enemy | `ActorController.target` when in `State.ALERT` or `State.COMBAT` | Visible only while actively targeted |

**Spotted enemy logic:**
- An enemy must be in an engaged state (ALERT or COMBAT) to trigger visibility
- If the player deselects or loses the enemy, standard occlusion rules apply
- The system does not reveal enemies the player has not detected

### 16.3 Occlusion Detection

Rather than per-pixel visibility testing, the system uses **axis-aligned occlusion checks** against foliage bounding volumes:

```
For each visible actor:
  1. Calculate screen-space position of the actor
  2. Find all foliage meshes whose screen-space bounds overlap the actor
  3. Mark overlapping foliage as "occluding" for this frame
```

**Foliage bounding volumes:**
- Trunk: cylinder bounds from ground to crown top
- Canopy: sphere bounds per foliage cluster or combined canopy volume
- These volumes are precomputed on tree generation and stored as `AABB` data

**Optimization:** Only trees within a screen-space radius of the target are checked. Trees far from the actor's screen position are skipped entirely.

### 16.4 Transparency Levels

Foliage opacity is controlled by a shader uniform and follows a tiered model:

| Level | Opacity | Condition |
|-------|---------|-----------|
| Full | 1.0 | No occlusion |
| Partial | 0.4 – 0.6 | Actor occluded but not critical |
| Fading | 0.1 – 0.3 | Actor directly behind trunk or high-density canopy |
| Hidden | 0.0 | Reserved for extreme cases (e.g., character inside trunk bounds) |

The exact opacity within each tier can be adjusted by a global `FoliageTransparency` setting.

### 16.5 Shader Implementation

A single `ShaderMaterial` applied to all foliage meshes exposes a `current_opacity` uniform:

```gdscript
# Foliage shader (gdshader)
shader_type spatial;
render_mode blend_transparent, depth_draw_always, cull_back;

uniform float current_opacity : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	ALBEDO = albedo_color;
	ALPHA = current_opacity;
}
```

**Key render mode flags:**
- `blend_transparent` — enables alpha blending
- `depth_draw_always` — prevents z-fighting with occluded actors (critical for visibility)
- `cull_back` — foliage renders on both sides to avoid clipping issues at low opacity

**Opacity update loop:**
```gdscript
func _process_transparency() -> void:
	var visible_actors := _get_visible_actors()
	var occluded_foliage := _find_occluding_foliage(visible_actors)
	
	for foliage in all_foliage_meshes:
		if foliage in occluded_foliage:
			foliage.material.set_shader_parameter("current_opacity", 0.4)
		else:
			foliage.material.set_shader_parameter("current_opacity", 1.0)
```

### 16.6 Trunk vs. Canopy Transparency

Trunks and foliage behave differently:

| Component | Behavior | Reason |
|-----------|----------|--------|
| Trunk | Fades to ~30% opacity when occluding actor | Trunks are visually heavy; too much transparency ruins the silhouette |
| Canopy | Fades to ~50% opacity when occluding actor | Dense foliage should still block view but reveal movement beneath |
| Both | Snap to full opacity within 0.5s of no occlusion | Prevents slow fade-in creating a "ghost" effect |

This differentiation prevents canopies from disappearing entirely while still revealing actors moving through the understory.

### 16.7 Performance Considerations

- **No per-frame raycasting:** Occlusion checks use AABB overlap in screen space, not pixel-level ray tests
- **Instanced materials:** All trees share a material template; only the `current_opacity` uniform is updated per-mesh
- **Frustum culling:** Trees outside the camera frustum are skipped entirely
- **Fade damping:** Opacity changes are lerped over 2–3 frames to avoid per-frame uniform updates for transient occlusions (actor briefly passing behind a branch)

```gdscript
# Lerped opacity update
var target_opacity := is_occluding ? 0.4 : 1.0
current_opacity = lerp(current_opacity, target_opacity, 0.3)  # ~3 frames to settle
foliage.material.set_shader_parameter("current_opacity", current_opacity)
```

### 16.8 Integration Points

| Component | Change |
|-----------|--------|
| `TreeBlueprint` | Add optional `foliage_shader_material` reference (defaults to shared transparent material) |
| `HarvestableTree` | On `_ready()`, apply transparent material to foliage CSG nodes; store references for fast uniform updates |
| `VisibilityManager` (new) | Singleton that tracks visible actors, runs occlusion checks, and updates foliage opacity each frame |
| `ActorController` | Emit signal `target_spotted(enemy)` and `target_lost(enemy)` for the visibility manager |
| `PlayerController` | Always reports player character as visible |

### 16.9 Future Enhancements

- **Depth-based fading:** Fade canopy more near its center and less at edges (natural gradient)
- **Selective transparency:** Only occluding foliage layers fade; inner layers remain opaque for depth
- **Enemy peripheral vision:** Reveal enemies that are about to spot the player (reactivity warning)
- **Per-species transparency:** Some trees (e.g., sparse conifers) naturally allow more visibility; blueprint could include a `visibility_occlusion_factor` (0.0 – 1.0)

---

## 17. Implementation Learnings

This section captures hard-won lessons from building the system. Update it as new patterns emerge.

### 17.1 CSG Centering Behavior

`CSGCylinder3D.position` is its **center point**, not one end. This is critical when chaining segments or positioning branches:

```gdscript
# WRONG — cylinder is offset, one end floats
cylinder.position = segment.origin
cylinder.height = segment_length

# CORRECT — cylinder is centered between origin and terminal
cylinder.position = (origin + terminal) / 2.0
cylinder.height = origin.distance_to(terminal)
```

The trunk segment chaining algorithm (section 3.1.2) relies on this behavior. Each segment's midpoint must be calculated as the average of its origin and terminal points.

### 17.2 Foliage Guarantee

Every branch and the topmost trunk **always** gets at least one foliage sphere. There is no random roll for existence — only for position, scale, and rotation:

| Component | Foliage guarantee |
|-----------|-------------------|
| Topmost trunk terminal | ✅ Always — at least 1 layer |
| Each branch tip | ✅ Always — at least 1 sphere |

The `branch_foliage_ratio` parameter from earlier designs has been removed.

### 17.3 Foliage Anchor Positioning

Foliage is positioned so the trunk/branch origin falls **30–60% of the way from the sphere's outer edge toward its center**:

```
position = anchor_point + outward_direction * (outward_ratio * radius)
```

Where `outward_ratio` is `randf_range(0.30, 0.60)`. This ensures the trunk/branch visibly "enters" the foliage from below rather than attaching at the sphere's center.

### 17.4 Foliage Count and Randomization

The base number of foliage clusters is determined by tree structure:

| Source | Foliage Count |
|--------|---------------|
| Top trunk segment | +1 (always) |
| Each branch | +1 per branch |

**Oak-style trees** may spawn with additional extra foliage:
- `extra_foliage_max` controls the maximum (0-2 extra)
- Actual count is randomly chosen each generation
- Extra foliage placement uses **distance optimization**: the algorithm samples 16 candidate positions and picks the one that maximizes the minimum distance to existing foliage clusters
- All foliage (base and extra) must stay within the top terminal branch's radius

This produces natural-looking canopies where extra foliage "fills gaps" between existing clusters rather than clustering together.

### 15.4 Blueprint Owns Its Construction

The `TreeBlueprint` class implements `generate_tree()` which returns all segment, branch, and foliage data. `HarvestableTree` only converts this data to CSG nodes. This separation:

- Enables testing the generation algorithm without instantiating nodes
- Allows the blueprint to drive editor previews
- Prevents `HarvestableTree` from accumulating its own generation logic

---

_End of document._
