class_name HexGridRenderer
extends Node3D

@export var tile_scale: float = 1.5
@export var hex_size: float = 1.5
@export var height_step: float = 1.0

var multimesh_instances: Dictionary = {} # State -> MultiMeshInstance3D
var multimesh_tile_lists: Dictionary = {} # State -> Array[HexTileData]

var _fire_particles_container: Node3D
var _fire_particles_pool: Array[GPUParticles3D] = []
var _active_fire_particles: Dictionary = {} # HexTileData -> GPUParticles3D

func setup(max_instances: int) -> void:
	_setup_multimeshes(max_instances)
	_setup_fire_particles()

func _setup_fire_particles() -> void:
	if not _fire_particles_container:
		_fire_particles_container = Node3D.new()
		_fire_particles_container.name = "FireParticlesContainer"
		add_child(_fire_particles_container)

func update_fire_effect(tile: HexTileData, active: bool) -> void:
	if active:
		if _active_fire_particles.has(tile): return
		var p = _get_fire_particle_from_pool()
		var h_offset = _get_tile_surface_y(tile)
		p.position = tile.position + Vector3(0, 0.5 + h_offset, 0)
		p.emitting = true
		_active_fire_particles[tile] = p
	else:
		if _active_fire_particles.has(tile):
			var p = _active_fire_particles.get(tile)
			if p:
				p.emitting = false
			_active_fire_particles.erase(tile)
			if p:
				_fire_particles_pool.append(p)

func _get_fire_particle_from_pool() -> GPUParticles3D:
	if not _fire_particles_pool.is_empty():
		return _fire_particles_pool.pop_back()
	
	var p = GPUParticles3D.new()
	if _fire_particles_container:
		_fire_particles_container.add_child(p)
	
	ActorParticleComponent.setup_gpu_particles(p, {
		"amount": 10,
		"lifetime": 0.8,
		"velocity_min": 0.3,
		"velocity_max": 0.5,
		"gravity": Vector3(0, 1.4, 0),
		"scale_min": 0.4 * tile_scale,
		"scale_max": 0.7 * tile_scale,
		"texture": preload("res://assets/generated/fire_particle_1774823455.png"),
		"local_coords": false,
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_BOX,
		"emission_box_extents": Vector3(hex_size * 0.7, 0.1, hex_size * 0.7)
	})
	
	return p

func _setup_multimeshes(max_instances: int) -> void:
	var hex_mesh = CylinderMesh.new()
	hex_mesh.top_radius = 1.0
	hex_mesh.bottom_radius = 1.0
	hex_mesh.height = 2.0
	hex_mesh.radial_segments = 6
	
	for state in TileConstants.State.values():
		var mmi = MultiMeshInstance3D.new()
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = hex_mesh
		mm.instance_count = max_instances
		mm.visible_instance_count = 0
		mmi.multimesh = mm
		
		var mat = ShaderMaterial.new()
		mat.shader = preload("res://Play Space/hex_tile.gdshader")
		mat.set_shader_parameter("top_texture", TileConstants.TEXTURES[state])
		mat.set_shader_parameter("side_texture", TileConstants.CLIFF_TEXTURES[state])
		mat.set_shader_parameter("albedo_color", TileConstants.COLORS[state])
		
		# Vertical flow animation and overlays for water and fire
		if state == TileConstants.State.PUDDLE:
			mat.set_shader_parameter("side_animation_speed", 0.8) # Waterfall speed
			if TileConstants.CLIFF_OVERLAYS.has(state):
				mat.set_shader_parameter("overlay_texture", TileConstants.CLIFF_OVERLAYS[state])
				mat.set_shader_parameter("overlay_animation_speed", 0.1) # Slowly boil mist
		elif state == TileConstants.State.FIRE:
			mat.set_shader_parameter("side_animation_speed", 0.4) # Lava flow speed
			if TileConstants.CLIFF_OVERLAYS.has(state):
				mat.set_shader_parameter("overlay_texture", TileConstants.CLIFF_OVERLAYS[state])
				mat.set_shader_parameter("overlay_animation_speed", -0.1) # Slowly drift smoke up
		
		mat.set_shader_parameter("side_scale", 1.0)
		mat.set_shader_parameter("height_darkening", 0.4)
		mat.set_shader_parameter("rim_highlight", 0.4)
		mat.set_shader_parameter("rim_size", 0.1)
		mat.set_shader_parameter("top_edge_darkening", 0.4)
		mat.set_shader_parameter("top_edge_softness", 0.15)
		
		# Edge details for different materials
		match state:
			TileConstants.State.GRASS:
				mat.set_shader_parameter("edge_noise_amplitude", 0.45) # Extreme overhang for grass
				mat.set_shader_parameter("edge_noise_frequency", 18.0)
				mat.set_shader_parameter("edge_noise_bias", 0.25) # Pull down even further
				mat.set_shader_parameter("top_noise_scale", 0.25)
				mat.set_shader_parameter("top_noise_strength", 0.8)
			TileConstants.State.DIRT, TileConstants.State.MUD:
				mat.set_shader_parameter("edge_noise_amplitude", 0.3) # High crumbling noise
				mat.set_shader_parameter("edge_noise_frequency", 14.0)
				mat.set_shader_parameter("edge_noise_bias", -0.15) # Jagged/recessed edge
				mat.set_shader_parameter("top_noise_scale", 0.25)
				mat.set_shader_parameter("top_noise_strength", 0.7)
			TileConstants.State.STONE:
				mat.set_shader_parameter("edge_noise_amplitude", 0.12)
				mat.set_shader_parameter("edge_noise_frequency", 8.0)
				mat.set_shader_parameter("rim_highlight", 0.5) # Sharper stone edges
			TileConstants.State.PUDDLE:
				mat.set_shader_parameter("edge_noise_amplitude", 0.2)
				mat.set_shader_parameter("edge_noise_frequency", 22.0)
				mat.set_shader_parameter("rim_highlight", 0.7) # Extra shiny water surface
		
		mmi.material_override = mat
		
		add_child(mmi)
		multimesh_instances[state] = mmi
		multimesh_tile_lists[state] = []

func add_tile(tile: HexTileData) -> void:
	var state = tile.current_state
	var mmi = multimesh_instances[state]
	var list = multimesh_tile_lists[state]
	
	tile.set_meta("mm_index", list.size())
	list.append(tile)
	mmi.multimesh.visible_instance_count = list.size()
	mmi.multimesh.set_instance_transform(list.size() - 1, _get_tile_transform(tile))

func remove_tile(tile: HexTileData) -> void:
	var state = tile.current_state
	var mmi = multimesh_instances[state]
	var list = multimesh_tile_lists[state]
	var idx = tile.get_meta("mm_index")
	
	var last_tile = list.back()
	if last_tile != tile:
		list[idx] = last_tile
		last_tile.set_meta("mm_index", idx)
		mmi.multimesh.set_instance_transform(idx, _get_tile_transform(last_tile))
	
	list.pop_back()
	mmi.multimesh.visible_instance_count = list.size()

func _get_tile_transform(tile: HexTileData) -> Transform3D:
	var surface_y = _get_tile_surface_y(tile)
	
	var bottom_y = -10.0 # Deep base to cover gaps
	var height = surface_y - bottom_y
	var center_y = (surface_y + bottom_y) / 2.0
	var scale_y = height / 2.0 # Cylinder mesh height is 2.0
	
	var t = Transform3D()
	t.origin = tile.position + Vector3(0, center_y, 0)
	# Rotate 30 degrees to convert pointed-top mesh to flat-topped
	t = t.rotated_local(Vector3.UP, deg_to_rad(30))
	t = t.scaled_local(Vector3(tile_scale, scale_y, tile_scale))
	
	return t

func _get_tile_surface_y(tile: HexTileData) -> float:
	if tile.current_state == TileConstants.State.STONE:
		if tile.has_meta("stone_height"):
			return tile.get_meta("stone_height")
		return (float(tile.height_level) * height_step) + 2.0
	return float(tile.height_level) * height_step
