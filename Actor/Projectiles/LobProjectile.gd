class_name LobProjectile
extends WaveProjectile

var _target_position: Vector3
var _peak_height: float = 4.0
var _total_distance: float
var _horizontal_dir: Vector3
var _landing_radius: float = 2.0

func initialize_lob(arena: ArenaGrid, caster_position: Vector3, target_position: Vector3, velocity: float, max_charges: int, projectile_lifetime: float) -> void:
	# BaseProjectile needs a direction, we'll give it the horizontal one
	var dir = (target_position - caster_position)
	dir.y = 0
	var horizontal_dir = dir.normalized()
	
	# We call regular initialize but we'll override the movement
	super.initialize(arena, caster_position, 0.0, horizontal_dir, velocity, max_charges, projectile_lifetime, caster_position.distance_to(target_position) + 1.0)
	
	_target_position = target_position
	_horizontal_dir = horizontal_dir
	_total_distance = caster_position.distance_to(Vector3(target_position.x, caster_position.y, target_position.z))
	
	# Adjust peak height based on distance
	_peak_height = max(2.0, _total_distance * 0.4)

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime or remaining_charges <= 0:
		_land()
		return
	
	var progress = (_elapsed * speed) / _total_distance
	if progress >= 1.0:
		_land()
		return
	
	# Calculate horizontal position
	var current_horizontal_pos = _start_position + _horizontal_dir * (_elapsed * speed)
	
	# Parabolic arc for Y
	# y = 4 * peak * progress * (1 - progress)
	var arc_y = 4.0 * _peak_height * progress * (1.0 - progress)
	
	global_transform.origin = Vector3(current_horizontal_pos.x, _start_position.y + arc_y, current_horizontal_pos.z)
	
	_update_visuals(delta)

func _land() -> void:
	if not _arena:
		queue_free()
		return
		
	# Affect tiles in a radius
	var tiles = _arena.get_tiles_within_distance(global_transform.origin, _landing_radius)
	for tile in tiles:
		if is_instance_valid(tile):
			_arena.apply_element_to_tile(tile, element_type, _horizontal_dir)
	
	# Check for actors in radius (manual check since we are not using Area3D overlap here for landing)
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = _landing_radius
	query.shape = sphere
	query.transform = global_transform
	query.collision_mask = 1 # Assuming actors are on layer 1
	
	var results = space_state.intersect_shape(query)
	for result in results:
		var body = result.collider
		if body is Actor and body.element_type != element_type:
			body.take_damage(remaining_charges)
			
	queue_free()

func _apply_effect_to_tiles() -> void:
	# Lob projectiles don't affect tiles while in the air
	pass
