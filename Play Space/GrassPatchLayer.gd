## GrassPatchLayer
## Scatters organic, randomized grass patches across the top surface of grass tiles.
## Patches are procedurally shaped meshes that sit just above the hex tile tops,
## ignoring hex cell boundaries to create a natural, non-grid-aligned look.
##
## Add as a child of ArenaGrid. Call generate() after the grid is initialized.
class_name GrassPatchLayer
extends Node3D

# --- Tunables ---
@export_group("Coverage")
## Fraction of grass tiles that get a patch anchor (0.0 = none, 1.0 = every tile)
@export_range(0.0, 1.0, 0.05) var coverage_density: float = 0.65
## How many extra "sprinkle" patches are scattered on top of the base coverage
@export var sprinkle_count: int = 40
## Random seed for reproducible layouts (0 = random each run)
@export var seed: int = 0

@export_group("Patch Shape")
## Base radius of a patch in world units
@export var patch_radius_min: float = 0.55
@export var patch_radius_max: float = 1.1
## How many vertices on each blob polygon (more = smoother)
@export_range(6, 20) var blob_points: int = 10
## How much the vertices are perturbed from a perfect circle (0 = circle, 1 = very spiky)
@export_range(0.0, 0.8) var blob_irregularity: float = 0.45
## Positional jitter applied to each patch anchor (fraction of hex radius)
@export_range(0.0, 1.0) var anchor_jitter: float = 0.55

@export_group("Appearance")
## Y offset above the tile surface
@export var y_offset: float = 0.02
## Base grass color (tinted green)
@export var grass_color: Color = Color(0.38, 0.62, 0.25, 0.88)
## Color variation range applied per patch
@export var color_variation: float = 0.12

# Internal
var _rng: RandomNumberGenerator
var _arena: ArenaGrid
var _mesh_instance: MeshInstance3D


func _ready() -> void:
	# Auto-find parent ArenaGrid
	_arena = get_parent() as ArenaGrid
	if not _arena:
		push_warning("GrassPatchLayer: must be a child of ArenaGrid")


## Call this after ArenaGrid has finished generating its grid.
func generate() -> void:
	if not _arena:
		return

	# Clear any previous generation
	if _mesh_instance and is_instance_valid(_mesh_instance):
		_mesh_instance.queue_free()
		_mesh_instance = null

	_rng = RandomNumberGenerator.new()
	_rng.seed = seed if seed != 0 else randi()

	var grass_tiles: Array[HexTileData] = []
	for tile in _arena.tile_data_grid:
		if tile.current_state == TileConstants.State.GRASS:
			grass_tiles.append(tile)

	if grass_tiles.is_empty():
		return

	var patches: Array[PackedVector3Array] = []

	# --- Base coverage: one anchor per selected grass tile ---
	grass_tiles.shuffle() # use built-in shuffle; seed applied via _rng below
	var selected_count := int(grass_tiles.size() * coverage_density)
	for i in selected_count:
		var tile := grass_tiles[i]
		var anchor := _jittered_anchor(tile)
		patches.append(_make_blob(anchor, tile.position.y))

	# --- Sprinkles: random extra patches anywhere on grass ---
	for _i in sprinkle_count:
		var tile := grass_tiles[_rng.randi() % grass_tiles.size()]
		var anchor := _jittered_anchor(tile)
		patches.append(_make_blob(anchor, tile.position.y))

	_build_mesh(patches)


## Rebuild when tile states change (e.g. grass burns to dirt).
func regenerate() -> void:
	generate()


# --- Internals ---

func _jittered_anchor(tile: HexTileData) -> Vector3:
	var hex_r := _arena.hex_size * _arena.tile_scale
	var jitter_r := hex_r * anchor_jitter
	var angle := _rng.randf() * TAU
	var dist := _rng.randf() * jitter_r
	return Vector3(
		tile.position.x + cos(angle) * dist,
		tile.position.y,
		tile.position.z + sin(angle) * dist
	)


func _make_blob(anchor: Vector3, surface_y: float) -> PackedVector3Array:
	var verts := PackedVector3Array()
	var radius := _rng.randf_range(patch_radius_min, patch_radius_max)
	var angle_step := TAU / blob_points
	# Random rotation so patches don't all align the same way
	var rot_offset := _rng.randf() * TAU

	for i in blob_points:
		var base_angle := rot_offset + i * angle_step
		# Perturb radius per vertex for organic shape
		var perturb := 1.0 + _rng.randf_range(-blob_irregularity, blob_irregularity)
		var r := radius * perturb
		verts.append(Vector3(
			anchor.x + cos(base_angle) * r,
			surface_y + y_offset,
			anchor.z + sin(base_angle) * r
		))
	return verts


func _build_mesh(patches: Array[PackedVector3Array]) -> void:
	var surface_tool := SurfaceTool.new()
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)

	for patch in patches:
		# Per-patch color variation
		var variation := _rng.randf_range(-color_variation, color_variation)
		var col := Color(
			clamp(grass_color.r + variation * 0.5, 0.0, 1.0),
			clamp(grass_color.g + variation, 0.0, 1.0),
			clamp(grass_color.b + variation * 0.3, 0.0, 1.0),
			grass_color.a
		)
		surface_tool.set_color(col)

		# Fan triangulate the blob polygon from its centroid
		var centroid := Vector3.ZERO
		for v in patch:
			centroid += v
		centroid /= patch.size()
		centroid.y = patch[0].y  # keep flat

		var n := patch.size()
		for i in n:
			var a := patch[i]
			var b := patch[(i + 1) % n]
			surface_tool.set_color(col)
			surface_tool.add_vertex(centroid)
			surface_tool.add_vertex(a)
			surface_tool.add_vertex(b)

	surface_tool.generate_normals()

	var mesh := surface_tool.commit()

	# Transparent, unlit material so it sits cleanly on the tile top
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.vertex_color_use_as_albedo = true
	mat.no_depth_test = false
	mesh.surface_set_material(0, mat)

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "GrassPatchMesh"
	_mesh_instance.mesh = mesh
	add_child(_mesh_instance)
