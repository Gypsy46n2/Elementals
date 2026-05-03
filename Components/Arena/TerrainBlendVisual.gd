# TerrainBlendVisual
# ------------------
# Visual-only terrain mesh that drapes over the existing hex grid.
# - Reads tile data from ArenaGrid (positions, height_level, current_state).
# - Builds ONE ArrayMesh with shared corner vertices so hex seams blend
#   and height changes appear as slopes instead of chopped cylinders.
# - Textures itself with Terrain3D demo ground/rock PNGs blended via
#   vertex colors (R=grass, G=dirt/mud, B=rock, A=wet/special).
# - Adds boundary skirts so the playable area looks like a piece of land,
#   not a flat plane that extends to infinity.
# - Adds a WorldEnvironment with a sky/clear-color so the background is
#   not the default grey.
# - Hides the existing hex cylinder MultiMesh visuals AFTER it is built,
#   while keeping fire particles, collision, gameplay, and tile state intact.
#
# IMPORTANT: NO `class_name`. This script is loaded by path so it can never
# collide with another global script class in scanned folders.
extends Node3D

# --- Tunables ----------------------------------------------------------------
const SHADER_PATH: String = "res://Components/Arena/TerrainBlendVisual.gdshader"
const GROUND_ALB_PATH: String = "res://assets/terrain3d_demo/textures/ground037_alb_ht.png"
const ROCK_ALB_PATH: String = "res://assets/terrain3d_demo/textures/rock023_alb_ht.png"

# How long to wait after a tile state change before rebuilding the mesh.
# Prevents thrash when many tiles change in the same frame (fire spread, etc).
const REBUILD_DEBOUNCE_SEC: float = 0.18

# Bottom Y of the boundary skirt. Tiles in the playable area sit on top of
# this skirt; nothing is rendered outside the skirt, so we never see a giant
# grey rectangular plane.
const SKIRT_BOTTOM_Y: float = -8.0

# How much to round corner positions when keying shared vertices. Smaller =
# stricter sharing, larger = more tolerant. 0.01 is plenty for hex math.
const CORNER_KEY_QUANT: float = 100.0

# --- State -------------------------------------------------------------------
var _arena: Node = null               # ArenaGrid (typed loosely to avoid hard dep cycles)
var _mesh_instance: MeshInstance3D = null
var _shader_material: ShaderMaterial = null
var _standard_material: StandardMaterial3D = null
var _rebuild_timer: Timer = null
var _hidden_cylinder_states: Array = []  # Tracks which renderer states we hid
var _last_mesh_triangle_count: int = 0


# Public entry point. Call after the grid is generated.
func setup(arena: Node) -> void:
	_arena = arena
	_ensure_environment()
	_build_mesh_instance()
	_connect_signals()
	rebuild_now()
	# Only hide the cylinder visuals if our new mesh ACTUALLY produced
	# something visible. Otherwise we leave the cylinders in place so the
	# arena still has a floor.
	if _last_mesh_triangle_count > 0:
		_hide_cylinder_visuals()
	else:
		push_warning("[TerrainBlendVisual] mesh produced 0 triangles — keeping cylinder visuals.")


# Public: forces an immediate rebuild (used on setup and when callers need it).
func rebuild_now() -> void:
	if _arena == null or _mesh_instance == null:
		return
	var mesh: ArrayMesh = _generate_terrain_mesh()
	if mesh != null and mesh.get_surface_count() > 0:
		_mesh_instance.mesh = mesh
		_last_mesh_triangle_count = 0
		for s in range(mesh.get_surface_count()):
			var arr: Array = mesh.surface_get_arrays(s)
			var idx_arr: Variant = arr[Mesh.ARRAY_INDEX]
			if idx_arr is PackedInt32Array:
				_last_mesh_triangle_count += int((idx_arr as PackedInt32Array).size() / 3)
		# Diagnostic: dump the live tile-state distribution so we can confirm
		# the mesh is being rebuilt from the LATEST tile data.
		var tdg_v: Variant = _arena.get("tile_data_grid")
		if tdg_v is Array:
			var counts: Dictionary = {}
			for t in (tdg_v as Array):
				var s2: int = int(t.current_state)
				counts[s2] = int(counts.get(s2, 0)) + 1
			print("[TerrainBlendVisual] live state counts: ", counts)
	else:
		_last_mesh_triangle_count = 0
		push_warning("[TerrainBlendVisual] _generate_terrain_mesh returned null or empty")


# --- Signal plumbing ---------------------------------------------------------
func _connect_signals() -> void:
	if _arena == null:
		return
	# tile_counts_changed fires whenever set_tile_state runs; use it as a
	# cheap signal that the visual is potentially stale.
	if _arena.has_signal("tile_counts_changed"):
		var cb: Callable = Callable(self, "_on_tile_counts_changed")
		if not _arena.is_connected("tile_counts_changed", cb):
			_arena.connect("tile_counts_changed", cb)

	# Safety-net periodic rebuild timer — re-builds every 2s even if no
	# signals fire, so any missed state change still becomes visible.
	_rebuild_timer = Timer.new()
	_rebuild_timer.one_shot = true
	_rebuild_timer.wait_time = 2.0
	_rebuild_timer.timeout.connect(_on_rebuild_timer_timeout)
	add_child(_rebuild_timer)
	_rebuild_timer.start(2.0)


func _on_tile_counts_changed(counts: Dictionary) -> void:
	# Rebuild IMMEDIATELY on every state change. Earlier debounce was hiding
	# a real bug where rebuilds weren't actually firing for some transitions.
	# Mesh build is fast enough (a few ms for a 40x40 grid) that an immediate
	# rebuild per state change is fine.
	print("[TerrainBlendVisual] tile_counts_changed: ", counts, " — rebuilding now")
	rebuild_now()


func _on_rebuild_timer_timeout() -> void:
	# Safety-net periodic rebuild. Catches any state changes that somehow
	# didn't trigger tile_counts_changed (e.g. direct mutation of
	# current_state outside set_tile_state).
	rebuild_now()
	if _rebuild_timer:
		_rebuild_timer.start(2.0)


# --- Environment / sky -------------------------------------------------------
func _ensure_environment() -> void:
	# If the scene tree already has a WorldEnvironment somewhere above us,
	# do not add another one.
	var existing: Node = _find_node_of_type(get_tree().get_current_scene(), "WorldEnvironment")
	if existing != null:
		return
	var env: Environment = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky: Sky = Sky.new()
	var psky: ProceduralSkyMaterial = ProceduralSkyMaterial.new()
	psky.sky_top_color = Color(0.40, 0.62, 0.86)
	psky.sky_horizon_color = Color(0.78, 0.84, 0.90)
	psky.ground_bottom_color = Color(0.18, 0.22, 0.20)
	psky.ground_horizon_color = Color(0.55, 0.55, 0.50)
	psky.sun_angle_max = 30.0
	psky.sun_curve = 0.15
	sky.sky_material = psky
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.1
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.74, 0.83, 0.90)
	env.fog_density = 0.0035
	env.fog_aerial_perspective = 0.25
	env.fog_sky_affect = 0.4

	var we: WorldEnvironment = WorldEnvironment.new()
	we.name = "TerrainBlendEnvironment"
	we.environment = env
	add_child(we)


func _find_node_of_type(node: Node, type_name: String) -> Node:
	if node == null:
		return null
	if node.get_class() == type_name:
		return node
	for c in node.get_children():
		var r: Node = _find_node_of_type(c, type_name)
		if r != null:
			return r
	return null


# --- Mesh / material setup ---------------------------------------------------
func _build_mesh_instance() -> void:
	if _mesh_instance != null:
		return

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "TerrainBlendMesh"
	_mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	_mesh_instance.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	# Force the mesh to be visible even when the camera AABB check is
	# fooled by a procedural mesh that hasn't computed its bounds yet.
	_mesh_instance.extra_cull_margin = 64.0
	add_child(_mesh_instance)

	# Materials are set per-surface on the ArrayMesh in rebuild_now() so the
	# floor (top) and walls (skirts) can use different settings. We do NOT
	# set a material_override here because that would shadow the
	# per-surface materials on the mesh.


# Material for the FLOOR (top hex surface). Uses CULL_DISABLED so triangle
# winding bugs cannot make the floor invisible, and the ground albedo is
# multiplied by per-vertex tint colors for grass / dirt / mud / etc.
func _make_top_material() -> StandardMaterial3D:
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	sm.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
	sm.vertex_color_use_as_albedo = true
	sm.vertex_color_is_srgb = false
	sm.roughness = 0.85
	sm.metallic = 0.0
	sm.uv1_scale = Vector3(0.18, 0.18, 1.0)
	sm.uv1_triplanar = false
	sm.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	# CRITICAL: never cull the floor — even if my procedural winding is wrong
	# on this renderer, the floor will still draw.
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var ground_tex: Texture2D = _safe_load_texture(GROUND_ALB_PATH)
	if ground_tex != null:
		sm.albedo_texture = ground_tex
	else:
		push_warning("[TerrainBlendVisual] ground texture not found at " + GROUND_ALB_PATH)
	return sm


# Material for the WALL/SKIRT geometry.
# Uses the Terrain3D rock_alb_ht texture, but its alpha channel encodes a
# heightmap (not transparency). On gl_compatibility that alpha can leak
# through and make walls see-through, so we strip alpha at load time by
# converting the loaded image to RGB8 and rebuilding the texture.
func _make_wall_material() -> StandardMaterial3D:
	var sm: StandardMaterial3D = StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
	sm.albedo_color = Color(0.85, 0.80, 0.74, 1.0)  # warm rock tint
	sm.vertex_color_use_as_albedo = false
	sm.roughness = 0.95
	sm.metallic = 0.0
	sm.uv1_scale = Vector3(0.30, 0.30, 1.0)
	sm.uv1_triplanar = false
	sm.transparency = BaseMaterial3D.TRANSPARENCY_DISABLED
	# Render both sides so the rock texture is visible no matter which side
	# of a wall the camera is looking at. Rules out any winding direction
	# bug at trivial cost — walls are a small fraction of the total mesh.
	sm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var rock_tex: Texture2D = _load_texture_alpha_stripped(ROCK_ALB_PATH)
	if rock_tex == null:
		# Fallback: ground texture with darker tint
		rock_tex = _safe_load_texture(GROUND_ALB_PATH)
		sm.albedo_color = Color(0.55, 0.50, 0.45, 1.0)
	if rock_tex != null:
		sm.albedo_texture = rock_tex
	return sm


# Load a texture and strip its alpha channel so a heightmap baked into the
# alpha channel cannot be misinterpreted as transparency by the renderer.
# Caches the result so we don't do this on every rebuild.
var _rock_tex_cache: Texture2D = null
func _load_texture_alpha_stripped(path: String) -> Texture2D:
	if _rock_tex_cache != null:
		return _rock_tex_cache
	if not ResourceLoader.exists(path):
		return null
	var src: Resource = load(path)
	if not (src is Texture2D):
		return null
	var img: Image = (src as Texture2D).get_image()
	if img == null:
		return null
	# Some imported textures are compressed; decompress before format conversion.
	if img.is_compressed():
		img.decompress()
	# RGB8 has no alpha — guarantees the renderer treats this as opaque.
	img.convert(Image.FORMAT_RGB8)
	if img.get_mipmap_count() == 0:
		img.generate_mipmaps()
	_rock_tex_cache = ImageTexture.create_from_image(img)
	return _rock_tex_cache


func _safe_load_texture(path: String) -> Texture2D:
	if not ResourceLoader.exists(path):
		return null
	var r: Resource = load(path)
	if r is Texture2D:
		return r as Texture2D
	return null


# --- Hide existing cylinder visuals (NOT collision, NOT particles) -----------
func _hide_cylinder_visuals() -> void:
	if _arena == null:
		return
	var renderer: Node = _arena.get("renderer")
	if renderer == null:
		return
	if not (renderer is Node):
		return
	var mm_dict_v: Variant = renderer.get("multimesh_instances")
	if not (mm_dict_v is Dictionary):
		return
	var mm_dict: Dictionary = mm_dict_v
	for state_key in mm_dict.keys():
		var mmi: Variant = mm_dict[state_key]
		if mmi is MultiMeshInstance3D:
			(mmi as MultiMeshInstance3D).visible = false
			_hidden_cylinder_states.append(state_key)


# --- Mesh generation ---------------------------------------------------------
func _generate_terrain_mesh() -> ArrayMesh:
	if _arena == null:
		return null
	var tile_data_v: Variant = _arena.get("tile_data_grid")
	if not (tile_data_v is Array):
		return null
	var tiles: Array = tile_data_v
	if tiles.is_empty():
		return null

	var hex_size: float = float(_arena.get("hex_size"))
	if hex_size <= 0.0:
		hex_size = 1.5
	var tile_scale_v: Variant = _arena.get("tile_scale")
	var tile_scale: float = 1.0
	if tile_scale_v is float or tile_scale_v is int:
		tile_scale = float(tile_scale_v)
	if tile_scale <= 0.0:
		tile_scale = 1.0
	# Effective outer radius of the hex visual.
	var outer_r: float = hex_size

	# --- Build a position->tile lookup so we can find which tiles share corners.
	var pos_lookup: Dictionary = {}
	for t in tiles:
		var key: Vector2i = _world_pos_key(t.position)
		pos_lookup[key] = t

	# --- Step 1: For every corner XZ, compute the AVERAGE color from all
	# tiles touching that corner. Heights are NOT averaged — each tile uses
	# its own surface_y so the visual floor matches per-tile collision.
	# corner_key (quantized XZ) -> {sum_r, sum_g, sum_b, count}
	var corner_color_data: Dictionary = {}
	for t in tiles:
		var center_xz: Vector2 = Vector2(t.position.x, t.position.z)
		var tc: Color = _tint_for_state(int(t.current_state))
		for i in range(6):
			var ang: float = deg_to_rad(60.0 * float(i))
			var cxz: Vector2 = center_xz + Vector2(cos(ang), sin(ang)) * outer_r
			var ckey: Vector2i = Vector2i(int(round(cxz.x * CORNER_KEY_QUANT)), int(round(cxz.y * CORNER_KEY_QUANT)))
			var entry: Dictionary = corner_color_data.get(ckey, {
				"sum_r": 0.0, "sum_g": 0.0, "sum_b": 0.0, "count": 0
			})
			entry["sum_r"] += tc.r
			entry["sum_g"] += tc.g
			entry["sum_b"] += tc.b
			entry["count"] += 1
			corner_color_data[ckey] = entry

	# --- Step 2: Build mesh arrays.
	# Two separate surfaces so the floor and the cliff walls can use
	# different materials (and the floor can disable culling without
	# affecting the walls).
	var verts: PackedVector3Array = PackedVector3Array()
	var normals: PackedVector3Array = PackedVector3Array()
	var uvs: PackedVector2Array = PackedVector2Array()
	var colors: PackedColorArray = PackedColorArray()
	var indices: PackedInt32Array = PackedInt32Array()              # TOP surface

	var w_verts: PackedVector3Array = PackedVector3Array()
	var w_normals: PackedVector3Array = PackedVector3Array()
	var w_uvs: PackedVector2Array = PackedVector2Array()
	var w_colors: PackedColorArray = PackedColorArray()
	var w_indices: PackedInt32Array = PackedInt32Array()            # WALL surface

	# Build a fast tile-by-XZ lookup so we can fetch a neighbour's
	# surface_y when we add walls between height-different tiles.
	var tile_by_xz: Dictionary = {}
	for t in tiles:
		tile_by_xz[_world_pos_key(t.position)] = t

	# --- Step 3: Top fan per tile (per-tile FLAT hex matches collision).
	for t in tiles:
		var center_xz: Vector2 = Vector2(t.position.x, t.position.z)
		var surf_y: float = _get_surface_y(t)
		var tile_tint: Color = _tint_for_state(int(t.current_state))

		# Center vertex
		var center_idx: int = verts.size()
		verts.append(Vector3(center_xz.x, surf_y, center_xz.y))
		normals.append(Vector3.UP)
		uvs.append(Vector2(center_xz.x, center_xz.y))
		colors.append(tile_tint)

		# 6 corner vertices, all at the tile's OWN surface_y (no averaging
		# of heights). Color is averaged across tiles touching the corner so
		# same-height tiles of different states still blend visually.
		var cidx: Array = []
		cidx.resize(6)
		for i in range(6):
			var ang: float = deg_to_rad(60.0 * float(i))
			var cxz: Vector2 = center_xz + Vector2(cos(ang), sin(ang)) * outer_r
			var ckey: Vector2i = Vector2i(int(round(cxz.x * CORNER_KEY_QUANT)), int(round(cxz.y * CORNER_KEY_QUANT)))
			var d: Dictionary = corner_color_data.get(ckey, {"sum_r": tile_tint.r, "sum_g": tile_tint.g, "sum_b": tile_tint.b, "count": 1})
			var cnt: float = max(1.0, float(d["count"]))
			var avg_color: Color = Color(d["sum_r"] / cnt, d["sum_g"] / cnt, d["sum_b"] / cnt, 1.0)
			# Bias toward this tile's own tint so its center reads true and
			# the blend is only at the boundary.
			var corner_color: Color = avg_color.lerp(tile_tint, 0.35)

			var new_idx: int = verts.size()
			verts.append(Vector3(cxz.x, surf_y, cxz.y))
			normals.append(Vector3.UP)
			uvs.append(Vector2(cxz.x, cxz.y))
			colors.append(corner_color)
			cidx[i] = new_idx

		# 6 triangles fanning out from the center.
		# Top material uses CULL_DISABLED so winding direction is irrelevant.
		for i in range(6):
			var a: int = cidx[i]
			var b: int = cidx[(i + 1) % 6]
			indices.append(center_idx)
			indices.append(b)
			indices.append(a)

	# --- Step 4: Walls between adjacent tiles at DIFFERENT heights, AND
	# boundary skirts (no neighbour). Both go into the wall surface so they
	# share the rock material.
	var wall_col: Color = Color(1.0, 1.0, 1.0, 1.0)
	for t in tiles:
		var c_xz: Vector2 = Vector2(t.position.x, t.position.z)
		var t_y: float = _get_surface_y(t)
		# Precompute corner XZ positions
		var corners_xz: Array = []
		corners_xz.resize(6)
		for i in range(6):
			var ang2: float = deg_to_rad(60.0 * float(i))
			corners_xz[i] = c_xz + Vector2(cos(ang2), sin(ang2)) * outer_r

		for i in range(6):
			var a_xz: Vector2 = corners_xz[i]
			var b_xz: Vector2 = corners_xz[(i + 1) % 6]
			var mid_xz: Vector2 = (a_xz + b_xz) * 0.5
			var neighbor_xz: Vector2 = mid_xz + (mid_xz - c_xz)
			var nkey: Vector2i = _world_pos_key(Vector3(neighbor_xz.x, 0.0, neighbor_xz.y))

			var has_neighbor: bool = tile_by_xz.has(nkey)
			var bottom_y: float = SKIRT_BOTTOM_Y
			var should_add_wall: bool = false

			if has_neighbor:
				var n_tile: Object = tile_by_xz[nkey]
				var n_y: float = _get_surface_y(n_tile)
				# Only the TALLER tile draws the wall (the shorter tile would
				# draw an inverted wall, so we'd double up). Skip if heights
				# match within a tiny epsilon.
				if t_y - n_y > 0.05:
					should_add_wall = true
					bottom_y = n_y
				# else: equal or this is the shorter side — no wall here.
			else:
				# Boundary edge: skirt down to SKIRT_BOTTOM_Y.
				should_add_wall = true
				bottom_y = SKIRT_BOTTOM_Y

			if not should_add_wall:
				continue

			var top_a: Vector3 = Vector3(a_xz.x, t_y, a_xz.y)
			var top_b: Vector3 = Vector3(b_xz.x, t_y, b_xz.y)
			var bot_a: Vector3 = Vector3(a_xz.x, bottom_y, a_xz.y)
			var bot_b: Vector3 = Vector3(b_xz.x, bottom_y, b_xz.y)

			# UVs along the wall: U runs along the edge length, V runs vertically.
			# Without this, walls facing different directions stretch oddly.
			var edge_len: float = (b_xz - a_xz).length()
			var wall_h: float = max(0.01, t_y - bottom_y)
			var uv_top_a: Vector2 = Vector2(0.0, 0.0)
			var uv_top_b: Vector2 = Vector2(edge_len, 0.0)
			var uv_bot_a: Vector2 = Vector2(0.0, wall_h)
			var uv_bot_b: Vector2 = Vector2(edge_len, wall_h)

			# Outward-facing normal (away from this tile's centre)
			var edge_vec: Vector3 = top_b - top_a
			var down_vec: Vector3 = bot_a - top_a
			var normal: Vector3 = edge_vec.cross(down_vec).normalized()
			var to_centre: Vector3 = Vector3(c_xz.x, t_y, c_xz.y) - top_a
			if normal.dot(to_centre) > 0.0:
				normal = -normal
				# Re-wind so the outward face is the front face for cull_back
				var i0: int = w_verts.size()
				w_verts.append(top_b); w_normals.append(normal); w_uvs.append(uv_top_b); w_colors.append(wall_col)
				w_verts.append(top_a); w_normals.append(normal); w_uvs.append(uv_top_a); w_colors.append(wall_col)
				w_verts.append(bot_a); w_normals.append(normal); w_uvs.append(uv_bot_a); w_colors.append(wall_col)
				w_verts.append(bot_b); w_normals.append(normal); w_uvs.append(uv_bot_b); w_colors.append(wall_col)
				w_indices.append(i0); w_indices.append(i0 + 1); w_indices.append(i0 + 2)
				w_indices.append(i0); w_indices.append(i0 + 2); w_indices.append(i0 + 3)
			else:
				var i0b: int = w_verts.size()
				w_verts.append(top_a); w_normals.append(normal); w_uvs.append(uv_top_a); w_colors.append(wall_col)
				w_verts.append(top_b); w_normals.append(normal); w_uvs.append(uv_top_b); w_colors.append(wall_col)
				w_verts.append(bot_b); w_normals.append(normal); w_uvs.append(uv_bot_b); w_colors.append(wall_col)
				w_verts.append(bot_a); w_normals.append(normal); w_uvs.append(uv_bot_a); w_colors.append(wall_col)
				w_indices.append(i0b); w_indices.append(i0b + 1); w_indices.append(i0b + 2)
				w_indices.append(i0b); w_indices.append(i0b + 2); w_indices.append(i0b + 3)

	# Top surface is per-tile flat — vertex normals already point straight up.
	# No smoothing needed (and any smoothing would re-introduce the float bug).

	if verts.is_empty() or indices.is_empty():
		return null

	var mesh: ArrayMesh = ArrayMesh.new()

	# Surface 0: TOP (floor)
	var top_arrays: Array = []
	top_arrays.resize(Mesh.ARRAY_MAX)
	top_arrays[Mesh.ARRAY_VERTEX] = verts
	top_arrays[Mesh.ARRAY_NORMAL] = normals
	top_arrays[Mesh.ARRAY_TEX_UV] = uvs
	top_arrays[Mesh.ARRAY_COLOR] = colors
	top_arrays[Mesh.ARRAY_INDEX] = indices
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, top_arrays)
	mesh.surface_set_material(0, _make_top_material())

	# Surface 1: WALLS (skirts) - only added if there are any
	if not w_verts.is_empty() and not w_indices.is_empty():
		var w_arrays: Array = []
		w_arrays.resize(Mesh.ARRAY_MAX)
		w_arrays[Mesh.ARRAY_VERTEX] = w_verts
		w_arrays[Mesh.ARRAY_NORMAL] = w_normals
		w_arrays[Mesh.ARRAY_TEX_UV] = w_uvs
		w_arrays[Mesh.ARRAY_COLOR] = w_colors
		w_arrays[Mesh.ARRAY_INDEX] = w_indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, w_arrays)
		mesh.surface_set_material(1, _make_wall_material())

	print("[TerrainBlendVisual] mesh built: top=", verts.size(), " verts / ", int(indices.size() / 3), " tris; walls=", w_verts.size(), " verts / ", int(w_indices.size() / 3), " tris")
	return mesh


func _world_pos_key(p: Vector3) -> Vector2i:
	return Vector2i(int(round(p.x * CORNER_KEY_QUANT)), int(round(p.z * CORNER_KEY_QUANT)))


func _get_surface_y(tile: Object) -> float:
	# Mirrors HexGridRenderer / GridGenerator surface logic so the visual
	# stays in sync with collision and gameplay heights.
	var height_step: float = 1.0
	if _arena != null:
		var hs_v: Variant = _arena.get("height_step")
		if hs_v is float or hs_v is int:
			height_step = float(hs_v)
	var stone_state: int = TileConstants.State.STONE
	var state: int = int(tile.current_state)
	if state == stone_state:
		if tile.has_meta("stone_height"):
			return float(tile.get_meta("stone_height"))
		return float(tile.height_level) * height_step + 2.0
	return float(tile.height_level) * height_step


func _tint_for_state(state: int) -> Color:
	# Returns the final per-tile tint that gets multiplied into the ground
	# texture. Vertex tints are averaged at shared corners so seams blend.
	# Alpha is always 1.0 to keep the floor opaque.
	match state:
		TileConstants.State.GRASS:
			return Color(0.55, 0.85, 0.45, 1.0)
		TileConstants.State.DIRT:
			return Color(0.78, 0.58, 0.38, 1.0)
		TileConstants.State.MUD:
			return Color(0.45, 0.34, 0.22, 1.0)
		TileConstants.State.PUDDLE:
			return Color(0.40, 0.55, 0.78, 1.0)
		TileConstants.State.STONE:
			return Color(0.62, 0.60, 0.58, 1.0)
		TileConstants.State.FIRE:
			return Color(1.00, 0.55, 0.22, 1.0)
		_:
			return Color(0.70, 0.70, 0.65, 1.0)
