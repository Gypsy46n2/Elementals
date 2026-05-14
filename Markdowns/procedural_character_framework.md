# Procedural Character Framework — Godot 4
**Low-Poly, Code-Generated, Procedurally Animated**

> Version: 0.4 — Implementation Order + AI Prompting Guide Added
> Status: Design Phase

### Changelog
| Version | Change |
|---------|--------|
| 0.1 | Initial architecture sketch |
| 0.2 | Added three-tier Detail Level system cascading through all layers |
| 0.3 | Added Editor Plugin layer — viewport gizmos, parameter panel, live preview, save/load pipeline |
| 0.4 | Added Implementation Order and AI Prompting Guide sections |

---

## Vision

A fully code-driven character generation and animation system for Godot 4. No external mesh files. Characters are defined by data (`Resource` files), assembled at runtime from procedural geometry, automatically rigged, and animated through IK and physics-layered motion. Changing a handful of parameters produces an entirely distinct creature.

---

## Design Principles

- **Zero art assets** — all geometry generated via `SurfaceTool` / `ArrayMesh`
- **Flat shading first** — low-poly aesthetic; normals calculated per-face
- **Segmented bodies** — parts remain separate `MeshInstance3D` nodes (no mesh merging); joints handled visually through overlap and shared color
- **Data-driven** — every character is a `CreatureDefinition` Resource; the generator is just a reader
- **Single generator, infinite output** — one `BipedGenerator` produces humans, goblins, aliens, giants by varying parameters
- **Three-tier detail** — every layer of the system responds to a `DetailLevel` enum (`SIMPLE`, `MODERATE`, `COMPLEX`); one setting cascades mesh density, animation system activation, and behaviour richness simultaneously
- **Editor-first authoring** — a Godot plugin provides a live viewport preview with drag handles and a parameter panel; the output is always a plain `CreatureDefinition` `.tres` file — the runtime generator stays unaware of the editor tooling

---

## Detail Level System

The `DetailLevel` enum is the master switch that controls complexity across every layer. It is set once — either in the `CreatureDefinition` or overridden at runtime by the game (e.g. based on distance from camera, number of creatures on screen, or platform capability). Every builder and animation system reads it and scales accordingly.

```gdscript
enum DetailLevel {
    SIMPLE,    # Background NPCs, crowds, distant enemies
    MODERATE,  # Standard enemies, secondary characters
    COMPLEX    # Player character, bosses, hero NPCs, cinematics
}
```

### What Each Level Controls

| System | SIMPLE | MODERATE | COMPLEX |
|--------|--------|----------|---------|
| **Limb sides** (polygon count) | 4 | 6 | 8 |
| **Torso sides** | 5 | 8 | 10 |
| **Head geometry** | Box only | Shape-matched | Shape-matched + detail geo |
| **Eye meshes** | Flat quad | Sphere | Sphere + pupil geo |
| **Extras** (tail, horns, wings) | Disabled | Enabled, low segments | Enabled, full segments |
| **Skeleton bones** | Hips + 4 limb chains | Full biped | Full biped + extras |
| **Foot IK** | Disabled — static feet | Basic (step arcs) | Full (terrain conforming) |
| **Body lean** | Disabled | Enabled | Enabled |
| **Spine wave** | Disabled | Enabled | Enabled |
| **Jiggle solver** | Disabled | Disabled | Enabled |
| **Idle variation** | Disabled | Minimal (breathing only) | Full (noise + look-around) |
| **LookAt** | Disabled | Disabled | Enabled |
| **`_process` cost (est.)** | Negligible | Low | Moderate |

### Runtime Switching

Detail level can be changed at runtime — the generator rebuilds the affected systems cleanly. Useful for:
- Transitioning a background NPC to a COMPLEX state when the player approaches
- Downgrading all creatures except the player during heavy combat scenes
- Platform scaling (mobile defaults to SIMPLE for crowds)

```gdscript
# In CreatureGenerator
func set_detail_level(level: DetailLevel) -> void:
    definition.detail_level = level
    _rebuild_mesh()        # ShapeAssembler reruns with new segment counts
    _rebuild_skeleton()    # SkeletonInferer updates bone count
    _configure_animation() # AnimationController enables/disables subsystems
```

---

## High-Level Architecture

```
┌─────────────────────────────────────────────┐
│             EDITOR PLUGIN LAYER             │
│                                             │
│  CreatureEditorPlugin                       │
│  ├── CharacterDesignerDock  (panel UI)      │
│  ├── CreatureGizmoPlugin    (viewport)      │
│  └── DefinitionSerializer  (save/load)      │
│                    │                        │
│         writes / reads                      │
└──────────────────────────────────┬──────────┘
                                   │
                    CreatureDefinition.tres
                                   │
┌──────────────────────────────────▼──────────┐
│            RUNTIME GENERATION LAYER         │
│                                             │
│  CreatureGenerator (Node)                   │
│  ├── ShapeAssembler                         │
│  │   ├── TorsoBuilder                       │
│  │   ├── LimbBuilder                        │
│  │   ├── HeadBuilder                        │
│  │   └── ExtrasBuilder                      │
│  ├── SkeletonInferer                        │
│  │   └── BoneMapper                         │
│  └── AnimationController                    │
│      ├── LocomotionSystem                   │
│      │   ├── FootPlacement (IK)             │
│      │   └── BodyLean                       │
│      ├── SecondaryMotion                    │
│      │   ├── SpineWave                      │
│      │   └── JiggleSolver                   │
│      └── BehaviourLayer                     │
│          ├── IdleVariation                  │
│          └── LookAt                         │
└─────────────────────────────────────────────┘
```

The editor plugin and the runtime generator are **fully decoupled** — they share only the `CreatureDefinition` resource format. The plugin can be disabled in a shipped game with zero impact on the runtime.

---

## Editor Plugin Layer — CreatureEditorPlugin

The editor plugin is a Godot `EditorPlugin` that activates when a `CreatureGenerator` node is selected in the scene tree. It adds three things: a docked parameter panel, viewport gizmo handles, and a save/load pipeline. The plugin writes and reads `CreatureDefinition` resources — it never touches the runtime generator directly.

**Key constraint:** every drag gesture and slider change maps to a *named semantic parameter* in `CreatureDefinition`, never to a raw transform. This ensures the saved `.tres` file is always a clean, human-readable data record rather than a dump of mesh positions.

---

### Plugin Component 1 — CharacterDesignerDock

A `Control`-based panel docked in the Godot editor (bottom or side panel). Appears automatically when a `CreatureGenerator` node is selected.

#### Panel Sections

```
┌─────────────────────────────────┐
│  🦴 Creature Designer           │
│  [New] [Load .tres] [Save .tres]│
├─────────────────────────────────┤
│  Body Plan:  [BIPED ▼]          │
│  Detail:     [MODERATE ▼]       │
├── Proportions ──────────────────┤
│  Torso Height   ●───────  1.00  │
│  Torso Width    ●───────  1.00  │
│  Arm Length     ●───────  1.00  │
│  Leg Length     ●───────  1.00  │
│  Head Scale     ●───────  1.00  │
│  Limb Thickness ●───────  0.18  │
├── Posture ──────────────────────┤
│  Spine Bend     ●───────   0°   │
│  Neck Angle     ●───────   0°   │
│  Shoulder Droop ●───────   0°   │
├── Head & Face ──────────────────┤
│  Shape:      [ROUND ▼]          │
│  Snout       ●───────  0.00     │
│  Eye Size    ●───────  1.00     │
│  Eye Spacing ●───────  1.00     │
├── Extras ───────────────────────┤
│  [x] Tail   Segments [6] Len [1]│
│  [ ] Wings                      │
│  Horns [0]                      │
├── Appearance ───────────────────┤
│  Body    [████]  Accent [████]  │
│  Eyes    [████]  Rough  [0.85]  │
├── Animation Feel ───────────────┤
│  Walk Speed   ●───────  1.00    │
│  Bounce       ●───────  0.06    │
│  2nd Motion   ●───────  1.00    │
└─────────────────────────────────┘
```

#### Behaviour

- Every control is **bidirectionally bound** to `CreatureDefinition` — changing a slider updates the definition, which triggers the live preview to regenerate
- Changing a value marks the definition as **dirty** (unsaved changes indicator in the title)
- The preview regenerates within one editor frame using the same `CreatureGenerator` the runtime uses — no separate preview system needed
- Undo/redo is integrated via `EditorUndoRedoManager` — every slider release or dropdown change is registered as an undoable action

---

### Plugin Component 2 — CreatureGizmoPlugin

Extends `EditorNode3DGizmoPlugin` to draw interactive handles directly in the 3D viewport over the live preview creature.

#### Handle Types

Each handle type maps drag distance to a specific parameter:

| Handle | Visual | Drag Axis | Parameter Written |
|--------|--------|-----------|-------------------|
| Torso height | ↕ arrow at top of chest | Y | `torso_height` |
| Torso width | ↔ arrows at chest sides | X | `torso_width` |
| Arm length | ○ sphere at wrist | Y along arm | `arm_length` |
| Leg length | ○ sphere at ankle | Y along leg | `leg_length` |
| Head scale | ○ sphere at head top | uniform | `head_scale` |
| Limb thickness | ○ sphere at upper arm | X | `limb_thickness` |
| Spine bend | ↻ arc at spine mid | rotation | `spine_bend` |
| Snout length | ○ sphere at nose | Z | `snout_length` |

#### Gizmo Interaction Rules

- Handles are **colour-coded by region**: torso handles orange, limb handles blue, head handles green, posture handles purple
- Hovering a handle highlights it and shows a tooltip with the parameter name and current value
- Dragging snaps to a resolution matching the parameter's meaningful range (e.g. `torso_height` snaps to 0.05 increments)
- Handle positions are **recomputed after every regeneration** so they always sit on the surface of the current preview mesh
- Only the handles relevant to the current `body_plan` and enabled extras are shown — no phantom handles for disabled features

#### Gizmo Data Flow

```
User drags handle
      │
      ▼
GizmoPlugin.set_handle()
      │   maps drag delta → parameter delta
      ▼
CreatureDefinition (property updated)
      │
      ▼
CreatureGenerator._rebuild()   ← same function the runtime uses
      │
      ▼
Live preview updates in viewport
      │
      ▼
GizmoPlugin._redraw()          ← handle positions updated to new mesh
```

---

### Plugin Component 3 — DefinitionSerializer

Handles reading and writing `CreatureDefinition` resources. Thin wrapper around Godot's `ResourceSaver` / `ResourceLoader` with editor-specific conveniences.

#### Save Flow

```gdscript
# DefinitionSerializer.gd
func save(definition: CreatureDefinition, path: String) -> void:
    # Validate: ensure no default-only fields are ambiguous
    _validate(definition)
    ResourceSaver.save(definition, path)
    # Register in the editor's recent files
    EditorInterface.get_resource_filesystem().scan()
```

Saves as a human-readable `.tres` (text resource). Example output:

```ini
[gd_resource type="CreatureDefinition" format=3]

[resource]
detail_level = 1
body_plan = 0
torso_height = 1.2
torso_width = 0.95
torso_depth = 0.6
limb_thickness = 0.14
arm_length = 1.0
leg_length = 0.75
head_scale = 1.4
spine_bend = -20.0
head_shape = 0
snout_length = 0.0
eye_size = 1.2
has_tail = false
body_color = Color(0.3, 0.55, 0.25, 1)
accent_color = Color(0.15, 0.3, 0.12, 1)
```

#### Load Flow

- File picker filters to `*.tres` and `*.res`
- Loaded definition is validated (version check for future compatibility)
- Panel and gizmos update immediately to reflect loaded values
- Preview regenerates automatically

#### Template Library

A built-in set of starter `.tres` files ships with the plugin under `addons/procedural_creature/templates/`:

```
templates/
├── biped_neutral.tres      ← balanced starting point
├── biped_stocky.tres
├── biped_lanky.tres
├── biped_hunched.tres
└── biped_beast.tres
```

Users load a template, tweak it in the designer, and save as their own definition — non-destructive, templates are never overwritten.

---

### Plugin File Structure (additions to addon)

```
addons/procedural_creature/
├── plugin.cfg
├── plugin.gd                      ← EditorPlugin entry point
├── editor/
│   ├── creature_editor_plugin.gd  ← registers dock + gizmo
│   ├── character_designer_dock.gd ← Control panel UI
│   ├── character_designer_dock.tscn
│   ├── creature_gizmo_plugin.gd   ← EditorNode3DGizmoPlugin
│   └── definition_serializer.gd   ← save/load wrapper
└── templates/
    ├── biped_neutral.tres
    ├── biped_stocky.tres
    ├── biped_lanky.tres
    ├── biped_hunched.tres
    └── biped_beast.tres
```

---

### Editor ↔ Runtime Contract

The only shared surface between editor and runtime is the `CreatureDefinition` resource class. This means:

- The plugin can be removed from a shipped game by deleting `addons/procedural_creature/editor/` — runtime is unaffected
- A `.tres` file authored in the editor is identical to one written by hand or generated programmatically at runtime
- Future editor features (copy/paste between definitions, randomise button, diff view) never require touching runtime code

---



The single source of truth for a creature. Saved as a `.tres` file. No code — just data.

```gdscript
# creature_definition.gd
class_name CreatureDefinition
extends Resource

## --- Detail Level ---
@export var detail_level: DetailLevel = DetailLevel.MODERATE
# Can be overridden at runtime without changing the .tres file

## --- Archetype ---
@export var body_plan: BodyPlan = BodyPlan.BIPED
enum BodyPlan { BIPED, QUADRUPED, SERPENTINE, CUSTOM }

## --- Proportions ---
@export_group("Proportions")
@export var torso_height: float = 1.0      # multiplier vs baseline
@export var torso_width: float = 1.0
@export var torso_depth: float = 0.6
@export var limb_thickness: float = 0.18
@export var arm_length: float = 1.0
@export var leg_length: float = 1.0
@export var head_scale: float = 1.0

## --- Posture ---
@export_group("Posture")
@export var spine_bend: float = 0.0        # degrees; negative = hunch forward
@export var neck_angle: float = 0.0        # degrees; tilt
@export var shoulder_droop: float = 0.0    # degrees

## --- Head & Face ---
@export_group("Head")
@export var head_shape: HeadShape = HeadShape.ROUND
enum HeadShape { ROUND, ANGULAR, ELONGATED, FLAT, HORNED }
@export var snout_length: float = 0.0      # 0 = flat face, 1 = full snout
@export var eye_size: float = 1.0
@export var eye_spacing: float = 1.0
@export var jaw_width: float = 1.0

## --- Extras ---
@export_group("Extras")
@export var has_tail: bool = false
@export var tail_segments: int = 6
@export var tail_length: float = 1.0
@export var has_wings: bool = false
@export var horn_count: int = 0

## --- Materials ---
@export_group("Appearance")
@export var body_color: Color = Color(0.6, 0.55, 0.5)
@export var accent_color: Color = Color(0.3, 0.25, 0.2)
@export var eye_color: Color = Color(0.1, 0.6, 0.9)
@export var roughness: float = 0.85

## --- Animation Feel ---
@export_group("Animation")
@export var walk_speed: float = 1.0
@export var bounce_amount: float = 0.06
@export var secondary_motion_strength: float = 1.0
@export var step_height: float = 0.18
```

---

## Layer 2 — ShapeAssembler

Reads a `CreatureDefinition` and instantiates the physical scene tree of `MeshInstance3D` nodes. Each part is a named node so the `SkeletonInferer` can locate attachment points.

### Scene Tree Output (Biped example)

```
CreatureRoot (Node3D)
├── Hips          (BoneAnchor)
│   ├── Spine     (BoneAnchor)
│   │   ├── Chest (MeshInstance3D)  ← TorsoBuilder
│   │   ├── Neck  (MeshInstance3D)  ← LimbBuilder (short)
│   │   ├── Head  (MeshInstance3D)  ← HeadBuilder
│   │   │   ├── EyeL (MeshInstance3D)
│   │   │   └── EyeR (MeshInstance3D)
│   │   ├── ShoulderL (BoneAnchor)
│   │   │   └── UpperArmL → ForearmL → HandL
│   │   └── ShoulderR (BoneAnchor)
│   │       └── UpperArmR → ForearmR → HandR
│   ├── HipL (BoneAnchor)
│   │   └── ThighL → ShinL → FootL
│   └── HipR (BoneAnchor)
│       └── ThighR → ShinR → FootR
└── [Extras: Tail, Wings, Horns]
```

### TorsoBuilder

Generates torso mesh using `SurfaceTool`. A low-poly torso is a tapered prism, wider at shoulders, narrower at waist. Side count is driven by `DetailLevel`.

**Sides by detail level:** SIMPLE → 5, MODERATE → 8, COMPLEX → 10

**Key parameters consumed:** `torso_height`, `torso_width`, `torso_depth`, `spine_bend`, `detail_level`

### LimbBuilder

Reusable for arms and legs. Generates a tapered cylinder. Side count scales with `DetailLevel`.

**Sides by detail level:** SIMPLE → 4, MODERATE → 6, COMPLEX → 8

- `length`, `radius_top`, `radius_bottom`, `sides` (resolved from detail level)

One class handles all limbs. Limb identity (arm vs leg) is just the parameters passed in.

### HeadBuilder

Switches mesh generation strategy based on `head_shape` enum. At SIMPLE, always generates a box regardless of `head_shape` — shape differentiation only kicks in at MODERATE and above.

- **SIMPLE** → box (cheapest, still readable at distance)
- **MODERATE** → shape-matched (ROUND, ANGULAR, ELONGATED, FLAT)
- **COMPLEX** → shape-matched + secondary detail geo (brow ridge, jaw edge loops)

Eye meshes follow the same pattern: SIMPLE → flat quad, MODERATE/COMPLEX → sphere geometry.

### ExtrasBuilder

Extras (tail, wings, horns) are fully **disabled at SIMPLE**. At MODERATE and COMPLEX they are enabled, with segment count scaling:

| Extra | MODERATE | COMPLEX |
|-------|----------|---------|
| Tail segments | 4 | `tail_segments` (from definition) |
| Wing edge loops | 3 | 6 |
| Horn sides | 4 | 6 |

---

## Layer 3 — SkeletonInferer

Walks the assembled scene tree and **automatically creates a `Skeleton3D`**. It derives bone positions from the `BoneAnchor` nodes — no manual rigging.

```
BoneAnchor nodes define:
  - bone_name: String
  - axis: Vector3   (the direction this bone "points")
  - length: float   (to child anchor, auto-calculated)
```

The inferer:
1. Traverses the tree depth-first
2. For each `BoneAnchor`, calls `skeleton.add_bone(name)`
3. Sets `set_bone_rest()` from the node's global transform relative to the skeleton root
4. Connects parent/child via `set_bone_parent()`

The result is a `Skeleton3D` that exactly mirrors the shape assembly — no manual bone placement ever needed.

---

## Layer 4 — AnimationController

No `AnimationPlayer`. No keyframes. All motion is computed per frame in `_process()` or `_physics_process()`. Each subsystem checks `detail_level` on init and either activates, runs a reduced version, or skips entirely.

### LocomotionSystem

**FootPlacement (IK)**
- SIMPLE: disabled — feet are static relative to hips; body bobs via a simple sine on the hip bone
- MODERATE: basic step arcs — foot target moves when drift exceeds `step_threshold`; smooth arc via `lerp` + sine height curve
- COMPLEX: terrain-conforming — raycasts below each foot adjust target height to match ground normal; foot rotates to match surface

**BodyLean**
- SIMPLE: disabled
- MODERATE + COMPLEX: forward velocity → forward torso tilt; lateral velocity → roll; applied as rotation on `Spine` bone

### SecondaryMotion

**SpineWave**
- SIMPLE: disabled
- MODERATE + COMPLEX: sine wave passes up spine bones each step cycle; amplitude and frequency driven by `walk_speed` and `bounce_amount`

**JiggleSolver**
- SIMPLE + MODERATE: disabled
- COMPLEX only: spring-damper on designated jiggle bones (belly, cheeks, tail tip); each bone stores velocity; each frame applies spring force toward rest pose

### BehaviourLayer

**IdleVariation**
- SIMPLE: disabled — creature is perfectly still when not moving
- MODERATE: breathing only — subtle chest scale pulse on a slow timer
- COMPLEX: full — low-frequency Perlin noise on chest and head rotation, occasional "look around" impulse, breathing

**LookAt**
- SIMPLE + MODERATE: disabled
- COMPLEX only: head and eye tracking toward `look_target`; clamped to anatomically valid rotation ranges per creature type

---

## Layer 5 — Variation Examples

How parameter changes produce distinct creatures from the same system:

| Creature     | Key Changes vs. Baseline Biped |
|--------------|-------------------------------|
| Goblin       | `head_scale: 1.4`, `leg_length: 0.7`, `spine_bend: -20`, `limb_thickness: 0.14` |
| Giant        | `torso_height: 1.8`, `torso_width: 1.5`, `leg_length: 1.6`, `shoulder_droop: 10` |
| Lizard-man   | `head_shape: ELONGATED`, `snout_length: 0.7`, `has_tail: true`, `spine_bend: -10` |
| Alien        | `head_scale: 1.6`, `eye_size: 2.0`, `eye_spacing: 1.4`, `limb_thickness: 0.1`, `arm_length: 1.3` |
| Beast-man    | `head_shape: HORNED`, `horn_count: 2`, `torso_width: 1.4`, `spine_bend: -5` |

---

## File Structure (Godot Project)

```
res://
├── addons/
│   └── procedural_creature/
│       ├── plugin.cfg
│       ├── core/
│       │   ├── creature_definition.gd
│       │   ├── creature_generator.gd
│       │   ├── shape_assembler.gd
│       │   ├── skeleton_inferer.gd
│       │   └── animation_controller.gd
│       ├── builders/
│       │   ├── torso_builder.gd
│       │   ├── limb_builder.gd
│       │   ├── head_builder.gd
│       │   └── extras_builder.gd
│       └── animation/
│           ├── locomotion_system.gd
│           ├── foot_placement.gd
│           ├── secondary_motion.gd
│           └── behaviour_layer.gd
├── creatures/
│   ├── definitions/
│   │   ├── humanoid_base.tres
│   │   ├── goblin.tres
│   │   └── lizard_man.tres
│   └── scenes/
│       └── creature_root.tscn   ← one scene, many definitions
└── demo/
    └── demo_scene.tscn
```

---

## Open Questions / Future Layers

- [ ] **Quadruped support** — different `BodyPlan` needs a different foot IK setup (4 feet, different spine axis)
- [ ] **Mesh merging** — option to bake all segments into one `ArrayMesh` for draw-call optimization at spawn
- [ ] **Vertex color painting** — per-region color zones (belly lighter than back, etc.) without textures
- [ ] **Combat/state poses** — additive pose offsets layered on top of procedural locomotion
- [ ] **Cloth/cape simulation** — extend `JiggleSolver` to a chain of bones
- [ ] **Distance-based auto-switching** — `CreatureManager` singleton watches camera distance and calls `set_detail_level()` automatically; thresholds configurable per-project
- [ ] **SIMPLE crowd instancing** — at SIMPLE level, consider converting to `MultiMeshInstance3D` for true GPU instancing of large crowds
- [ ] **Detail level presets per platform** — project setting to remap levels (e.g. mobile: COMPLEX → MODERATE, MODERATE → SIMPLE)
- [ ] **Editor: Randomise button** — randomises all parameters within designer-set ranges; useful for rapid exploration
- [ ] **Editor: Definition diff view** — side-by-side comparison of two `.tres` files with delta highlighting
- [ ] **Editor: Copy region** — copy just the Head or Limb parameter group from one definition to another
- [ ] **Editor: Animation preview toggle** — play the procedural locomotion in-editor to preview walk cycle feel without entering play mode
- [ ] **Editor: Export to thumbnail** — render a small icon of the current creature for use in game UI inventory or character select screens

---

---

## Implementation Order

The order matters significantly here. Each phase produces something immediately testable, and each one is a strict dependency for the next. Do not skip ahead — the AI will produce better code and fewer conflicts if the foundation is solid before the layers above it are built.

---

### Phase 1 — Foundation (No Rendering Yet)

**Goal:** Get the data model right before anything is visible. This is the contract everything else signs.

**Files to produce:**
```
addons/procedural_creature/core/creature_definition.gd
```

**What it must contain:**
- All enums: `DetailLevel`, `BodyPlan`, `HeadShape`
- All `@export` property groups exactly as specified in the Layer 1 section
- No logic — pure data only
- A `duplicate_definition()` helper that deep-copies the resource (needed later for undo/redo)

**Test:** Create a `.tres` file manually in the Godot editor, assign values, reload the project. Confirm all values persist correctly. Nothing should render yet.

---

### Phase 2 — LimbBuilder (First Geometry)

**Goal:** Prove the geometry generation approach works with the simplest possible shape.

**Files to produce:**
```
addons/procedural_creature/builders/limb_builder.gd
```

**What it must contain:**
- Static function: `build(length, radius_top, radius_bottom, sides) -> ArrayMesh`
- Generates a tapered cylinder using `SurfaceTool`
- Computes flat-shaded normals per face (not per vertex)
- A `resolve_sides(detail_level: DetailLevel) -> int` helper that returns 4 / 6 / 8

**Test:** In a bare test scene, call `LimbBuilder.build(1.0, 0.1, 0.08, 6)`, assign to a `MeshInstance3D`, and confirm a visible tapered cylinder with flat shading appears. Vary `sides` and confirm the low-poly look at 4 sides.

**Do not proceed** until flat shading is confirmed working. Normal computation is the most common failure point here.

---

### Phase 3 — TorsoBuilder and HeadBuilder

**Goal:** Complete the full set of body part generators.

**Files to produce:**
```
addons/procedural_creature/builders/torso_builder.gd
addons/procedural_creature/builders/head_builder.gd
addons/procedural_creature/builders/extras_builder.gd
```

**TorsoBuilder:** Tapered prism (not cylinder — the torso has a distinct cross-section). Wider at shoulder ring, narrower at waist ring. Accepts `height`, `width`, `depth`, `sides`.

**HeadBuilder:** Switches on `HeadShape` enum. Start with ROUND (low-poly sphere via icosphere subdivision level 1) and ANGULAR (box). ELONGATED and FLAT can follow. At `DetailLevel.SIMPLE`, always return a box regardless of enum value.

**ExtrasBuilder:** Implement tail only first (chain of tapered cylinders along a curve). Wings and horns can be stubbed with `pass` and added later.

**Test:** Manually call each builder in a test scene and visually confirm each shape. Check that `DetailLevel.SIMPLE` always produces the lowest polygon version.

---

### Phase 4 — ShapeAssembler + BoneAnchor

**Goal:** Assemble the parts into a correctly parented scene tree automatically from a `CreatureDefinition`.

**Files to produce:**
```
addons/procedural_creature/core/bone_anchor.gd
addons/procedural_creature/core/shape_assembler.gd
```

**BoneAnchor:** Minimal `Node3D` subclass. Properties: `bone_name: String`, `axis: Vector3`, stores a reference to its child `MeshInstance3D`.

**ShapeAssembler:** Reads a `CreatureDefinition`, instantiates `BoneAnchor` and `MeshInstance3D` nodes, parents them in the correct hierarchy (as shown in the Layer 2 scene tree diagram), positions each part relative to its parent using the definition's proportion parameters.

**Critical rule:** ShapeAssembler must be **fully deterministic** — calling it twice with the same definition must produce identical node trees. This is required for the editor preview to be stable.

**Test:** Pass in the `biped_neutral` definition values hardcoded. Confirm the scene tree matches the Layer 2 diagram exactly. Confirm a recognisable biped silhouette appears in the viewport.

---

### Phase 5 — CreatureGenerator

**Goal:** One node that orchestrates everything so far into a single clean entry point.

**Files to produce:**
```
addons/procedural_creature/core/creature_generator.gd
```

**What it must do:**
- Holds a `@export var definition: CreatureDefinition`
- On `_ready()` or when `definition` changes, calls `ShapeAssembler` to build the tree
- Exposes `rebuild()` as a public method (editor and runtime both call this)
- Clears the previous tree before rebuilding (no duplicate nodes accumulating)
- Exposes `set_detail_level(level)` which updates the definition and calls `rebuild()`

**Test:** Drop a `CreatureGenerator` into a scene, assign a definition in the inspector, run the scene. Character should appear. Change `detail_level` in the inspector at runtime and confirm the mesh updates.

---

### Phase 6 — SkeletonInferer

**Goal:** Auto-generate a `Skeleton3D` from the assembled node tree.

**Files to produce:**
```
addons/procedural_creature/core/skeleton_inferer.gd
```

**What it must do:**
- Walk the `BoneAnchor` tree depth-first
- For each anchor, call `skeleton.add_bone()` and `set_bone_rest()` using the node's transform relative to the skeleton root
- Wire parent-child relationships via `set_bone_parent()`
- Attach the resulting `Skeleton3D` as a child of `CreatureGenerator`

**Test:** After generation, select the `Skeleton3D` in the editor. Confirm bone count matches expected (biped = ~16 bones at MODERATE). Confirm bones visually align with the mesh in the skeleton debug view.

---

### Phase 7 — Editor Plugin Shell + CharacterDesignerDock

**Goal:** The plugin activates, the dock appears, sliders exist, and changing a slider rebuilds the preview. No gizmos yet.

**Files to produce:**
```
addons/procedural_creature/plugin.cfg
addons/procedural_creature/plugin.gd
addons/procedural_creature/editor/creature_editor_plugin.gd
addons/procedural_creature/editor/character_designer_dock.gd
addons/procedural_creature/editor/character_designer_dock.tscn
```

**Build the dock in this order:**
1. Header row: New / Load / Save buttons
2. Body Plan and Detail Level dropdowns
3. Proportions sliders (torso height, width, arm/leg length, head scale)
4. Each slider change calls `CreatureGenerator.rebuild()` on the selected node

**Critical:** Use `EditorUndoRedoManager` from the start. Every slider `drag_ended` signal (not `value_changed`) registers an undo action. Getting this right early prevents painful retrofitting later.

**Test:** Select a `CreatureGenerator` in the editor. Confirm the dock appears. Drag a slider. Confirm the preview character updates. Press Ctrl+Z. Confirm the slider and preview revert.

---

### Phase 8 — DefinitionSerializer (Save / Load)

**Goal:** Save and load `.tres` files from the dock. Ship the template library.

**Files to produce:**
```
addons/procedural_creature/editor/definition_serializer.gd
addons/procedural_creature/templates/biped_neutral.tres
addons/procedural_creature/templates/biped_stocky.tres
addons/procedural_creature/templates/biped_lanky.tres
addons/procedural_creature/templates/biped_hunched.tres
addons/procedural_creature/templates/biped_beast.tres
```

**Save:** `ResourceSaver.save(definition, path)`. Mark dock as clean after save.

**Load:** Open file dialog filtered to `.tres`. Load via `ResourceLoader.load()`. Validate it is a `CreatureDefinition` before applying. Update all dock controls to reflect loaded values.

**Templates:** Create each `.tres` by hand using Godot's inspector after Phase 5 is working. Save them into the templates folder. Wire a "Load Template" dropdown in the dock header.

**Test:** Save a creature, close and reopen Godot, load the file. Confirm every parameter is identical to what was saved.

---

### Phase 9 — CreatureGizmoPlugin (Viewport Handles)

**Goal:** Draggable handles appear on the preview creature in the 3D viewport.

**Files to produce:**
```
addons/procedural_creature/editor/creature_gizmo_plugin.gd
```

**Implement handles in this order** (simplest to most complex):
1. Head scale — uniform drag, single sphere handle at top of head
2. Torso height — Y-axis drag, arrow handle at chest top
3. Torso width — X-axis drag, handles at left and right chest edge
4. Arm length — Y drag along arm axis, sphere at wrist
5. Leg length — Y drag along leg axis, sphere at ankle
6. Spine bend — rotational drag, arc handle at spine midpoint

Each handle must update the dock slider in sync (bidirectional).

**Test:** Drag the head scale handle. Confirm head resizes, dock slider updates, and Ctrl+Z reverts both the visual and the slider.

---

### Phase 10 — AnimationController: Locomotion (MODERATE)

**Goal:** The character walks convincingly. This is the first animation system.

**Files to produce:**
```
addons/procedural_creature/animation/locomotion_system.gd
addons/procedural_creature/animation/foot_placement.gd
```

**Build in this order:**
1. Hip bob — simple sine wave on hip Y position, driven by velocity. No IK yet.
2. Body lean — forward tilt and lateral roll on the Spine bone from velocity vector.
3. Foot IK targets — four `Marker3D` nodes (FootL, FootR target pairs), static on ground plane.
4. Step detection — when foot drifts beyond `step_threshold`, trigger a step arc.
5. Step arc — `lerp` position + `sin()` height curve over `step_duration` frames.

**Test:** Give the `CreatureGenerator` a `CharacterBody3D` parent and a basic movement script. Walk around. Confirm feet step alternately, body bobs and leans. Feet should never slide.

---

### Phase 11 — AnimationController: Secondary Motion (COMPLEX)

**Goal:** The character feels alive when still and in motion.

**Files to produce:**
```
addons/procedural_creature/animation/secondary_motion.gd
addons/procedural_creature/animation/behaviour_layer.gd
```

**Build in this order:**
1. Breathing — chest bone scale pulse on a slow `sin()` timer. MODERATE+.
2. SpineWave — sine propagation up spine bones tied to step cycle. MODERATE+.
3. IdleVariation — low-frequency `FastNoiseLite` noise on head and chest rotation. COMPLEX only.
4. LookAt — head tracks a `look_target` Node3D with rotation clamping. COMPLEX only.
5. JiggleSolver — spring-damper on nominated bones. COMPLEX only. Implement last as it requires careful tuning.

**Test for each:** Isolate and test each subsystem independently before combining. Jiggle in particular needs to be tested with extreme velocity changes to confirm the spring doesn't diverge.

---

### Phase 12 — Integration Pass + Demo Scene

**Goal:** Everything works together, edge cases handled, demo scene ships with the plugin.

**Tasks:**
- Test all `DetailLevel` transitions at runtime (call `set_detail_level()` while character is moving)
- Test all `BodyPlan` values produce valid trees (even if only BIPED is fully implemented)
- Confirm `rebuild()` produces no orphan nodes across repeated calls
- Confirm editor gizmos, dock sliders, and undo/redo all stay in sync under rapid input
- Build `demo/demo_scene.tscn` — one creature of each template type, togglable detail level, free-move camera

---

## AI Prompting Guide

When using Godot's integrated AI to implement each phase, structure your prompts using this document as context. The following rules will produce better results and fewer revision cycles.

### General Rules

**Always paste the relevant section of this document** as context before describing the task. The AI has no memory between sessions — it needs the design as a prefix every time.

**One phase per session.** Do not ask the AI to implement multiple phases in one prompt. The output quality degrades significantly with scope.

**Name the files explicitly.** Always tell the AI exactly which file it is writing and what its `class_name` should be. Ambiguity here causes the AI to invent its own structure.

**State what must NOT be done.** Negative constraints are as important as positive ones. The AI will reach for `AnimationPlayer`, keyframes, and external mesh imports if you don't explicitly forbid them.

---

### Phase Prompt Templates

Use these as starting points. Paste them into Godot's AI, prepending the relevant section of this document.

---

**Phase 1 — CreatureDefinition**
```
Context: [paste the Layer 1 — CreatureDefinition section]

Write creature_definition.gd as a Godot 4 GDScript Resource subclass.
class_name: CreatureDefinition
- Include all enums (DetailLevel, BodyPlan, HeadShape) defined at the top of the file
- Include all @export properties exactly as listed, grouped with @export_group
- Add one helper method: duplicate_definition() -> CreatureDefinition that returns a deep copy
- No logic, no _ready(), no _process()
- Do not import or reference any other custom class
```

---

**Phase 2 — LimbBuilder**
```
Context: [paste the LimbBuilder section from Layer 2]

Write limb_builder.gd as a Godot 4 GDScript class.
class_name: LimbBuilder
- One static function: build(length: float, radius_top: float, radius_bottom: float, sides: int) -> ArrayMesh
- Use SurfaceTool to generate the mesh
- Normals must be flat-shaded: compute one normal per face, assign it to all three vertices of that face
- One static helper: resolve_sides(detail_level: int) -> int returning 4, 6, or 8
- Do not use any Godot primitive mesh classes (CylinderMesh etc.) — build all geometry manually
- Do not reference CreatureDefinition or any other custom class
```

---

**Phase 4 — ShapeAssembler**
```
Context: [paste the Layer 2 — ShapeAssembler section and the BoneAnchor spec]

Write shape_assembler.gd as a Godot 4 GDScript class.
class_name: ShapeAssembler
- One static function: assemble(definition: CreatureDefinition, parent: Node3D) -> void
- Creates BoneAnchor and MeshInstance3D nodes and adds them as children of parent
- Node hierarchy must match the scene tree diagram in the Layer 2 section exactly
- All part positions are derived from definition proportion values — no hardcoded offsets
- The function must be fully deterministic: identical input always produces identical output
- Call LimbBuilder, TorsoBuilder, HeadBuilder to generate meshes — do not generate geometry inline
- Do not use add_child with deferred — all nodes must be added synchronously
```

---

**Phase 7 — CharacterDesignerDock (Sliders only, no gizmos)**
```
Context: [paste the CharacterDesignerDock section and the panel layout diagram]

Write character_designer_dock.gd as a Godot 4 GDScript class extending Control.
class_name: CharacterDesignerDock
- On _ready(), build all UI controls in code — do not rely on the .tscn for control layout
- Each HSlider connects to a property on the active CreatureDefinition via a _on_slider_changed(value, property_name) handler
- Use drag_ended signal (not value_changed) to register undo actions with EditorUndoRedoManager
- Expose set_target(generator: CreatureGenerator) to bind the dock to a selected node
- When any value changes, call generator.rebuild()
- Do not use AnimationPlayer, Tween, or any timer for UI updates
```

---

**Phase 9 — CreatureGizmoPlugin (Head scale handle only, first)**
```
Context: [paste the CreatureGizmoPlugin section, focusing on the handle types table]

Write creature_gizmo_plugin.gd as a Godot 4 GDScript class extending EditorNode3DGizmoPlugin.
class_name: CreatureGizmoPlugin
- Implement ONE handle only: head scale (uniform drag, sphere handle at top of head)
- _redraw(): draw one sphere handle positioned at the top of the head MeshInstance3D
- set_handle(): map drag delta to definition.head_scale, clamp to range 0.3..3.0
- commit_handle(): register the change with EditorUndoRedoManager, call generator.rebuild()
- After rebuild(), call update_overlays() so the handle repositions to the new mesh
- Do not implement any other handles yet — they will be added in subsequent prompts
```

---

### Prompt Dos and Don'ts

| Do | Don't |
|----|-------|
| Paste the relevant doc section as context | Ask the AI to "remember" from a previous session |
| Name the file, class_name, and exact method signatures | Leave method names open-ended |
| State forbidden approaches explicitly | Assume the AI won't use AnimationPlayer or keyframes |
| Ask for one file per prompt | Ask for an entire phase in one prompt |
| Ask the AI to explain its normal calculation before writing it | Accept flat shading code without verification |
| Test each phase before prompting the next | Stack multiple untested phases |
| Tell the AI which other classes exist but not to rewrite them | Give the AI the whole codebase as context |

---

*Implementation ready. Begin with Phase 1 — CreatureDefinition.*

