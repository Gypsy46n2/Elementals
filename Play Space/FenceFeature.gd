class_name FenceFeature
extends Node3D

@onready var collision_body: StaticBody3D = $StaticBody3D

var health_component: HealthComponent
var tile: HexTileData
var rails: Array[MeshInstance3D] = []
var rail_collision_shapes: Array[CollisionShape3D] = []
var post_mesh: MeshInstance3D

func _ready() -> void:
	_setup_health_component()
	if has_node("Sprite3D"):
		get_node("Sprite3D").queue_free()
	
	_setup_collision()
	_create_post()
	_create_rails()

func _setup_collision() -> void:
	var shape: CollisionShape3D = get_node_or_null("StaticBody3D/CollisionShape3D")
	if shape:
		var box: BoxShape3D = BoxShape3D.new()
		box.size = Vector3(0.5, 1.5, 0.5) # Slightly larger than the post for easier interaction
		shape.shape = box
		shape.position.y = 0.75

func _create_post() -> void:
	post_mesh = MeshInstance3D.new()
	post_mesh.mesh = BoxMesh.new()
	post_mesh.mesh.size = Vector3(0.3, 1.5, 0.3)
	
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 0.25, 0.1) # Brown
	mat.shading_mode = StandardMaterial3D.SHADING_MODE_PER_PIXEL
	
	post_mesh.material_override = mat
	post_mesh.position.y = 0.75 # Half height to put bottom at origin
	add_child(post_mesh)

func _create_rails() -> void:
	var rail_mat: StandardMaterial3D = StandardMaterial3D.new()
	rail_mat.albedo_color = Color(0.45, 0.3, 0.15) # Slightly lighter brown
	
	for i in range(16): # Enough for 6 neighbors * 2 rails + some buffer
		var r: MeshInstance3D = MeshInstance3D.new()
		r.mesh = BoxMesh.new()
		r.mesh.size = Vector3(0.1, 0.15, 1.0) # Thinner height: 0.15
		r.material_override = rail_mat
		r.visible = false
		add_child(r)
		rails.append(r)
		
		# Add collision for each rail
		var sb: StaticBody3D = StaticBody3D.new()
		r.add_child(sb)
		var cs: CollisionShape3D = CollisionShape3D.new()
		sb.add_child(cs)
		rail_collision_shapes.append(cs)

func update_connections(p_arena: Node3D) -> void:
	if not tile or not p_arena: return
	var arena: ArenaGrid = p_arena as ArenaGrid
	if not arena: return
	
	var neighbors: Array[HexTileData] = arena._get_neighbors(tile)
	
	# Clear previous
	for i in range(rails.size()):
		rails[i].visible = false
		rail_collision_shapes[i].disabled = true
	
	var rail_idx: int = 0
	for n in neighbors:
		var connected: bool = false
		if n.feature:
			if n.feature is FenceFeature or n == arena.house_tile:
				connected = true
		
		if connected:
			var target_surface: float = arena._get_tile_surface_y(n)
			# Top rail at 1.1m
			var target_pos_top: Vector3 = n.position + Vector3(0, target_surface + 1.1, 0)
			_add_connection_to(target_pos_top, 1.1, rail_idx)
			rail_idx += 1
			
			# Bottom rail at 0.5m
			var target_pos_bottom: Vector3 = n.position + Vector3(0, target_surface + 0.5, 0)
			_add_connection_to(target_pos_bottom, 0.5, rail_idx)
			rail_idx += 1

func _add_connection_to(target_world_pos: Vector3, local_height: float, rail_idx: int) -> void:
	if rail_idx >= rails.size(): return
	var r: MeshInstance3D = rails[rail_idx]
	var cs: CollisionShape3D = rail_collision_shapes[rail_idx]
	
	# Rail connects from current post height to target post height
	var my_pos: Vector3 = global_position + Vector3(0, local_height, 0)
	var diff: Vector3 = target_world_pos - my_pos
	var dist: float = diff.length()
	var midpoint: Vector3 = my_pos + diff * 0.5
	
	r.visible = true
	r.global_position = midpoint
	
	# Create a box mesh with the exact length needed
	var mesh_size = Vector3(0.1, 0.15, dist)
	r.mesh = BoxMesh.new() # Unique mesh for unique length
	r.mesh.size = mesh_size
	
	# Update collision shape
	var box = BoxShape3D.new()
	box.size = mesh_size
	cs.shape = box
	cs.disabled = false
	
	r.look_at(target_world_pos, Vector3.UP)

func _setup_health_component() -> void:
	health_component = DamageComponent.find_health_component(self)
	if not health_component:
		health_component = HealthComponent.new()
		add_child(health_component)
	
	health_component.max_health = 10.0
	health_component.current_health = 10.0
	health_component.bar_color = Color.BROWN
	health_component.bar_offset = Vector3(0, 1.6, 0)
	health_component.health_depleted.connect(_on_health_depleted)

func _on_health_depleted() -> void:
	queue_free()

func set_tile(p_tile: HexTileData) -> void:
	tile = p_tile

func apply_element(element: String, _direction: Vector3 = Vector3.ZERO) -> bool:
	if element == "fire":
		take_damage(2.0, true)
		return true
	if element == "headbutt":
		take_damage(5.0, false)
		return true
	return false

func take_damage(amount: float, is_fire: bool) -> void:
	if health_component:
		health_component.take_damage(amount, "fire" if is_fire else "normal")
