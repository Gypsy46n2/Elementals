class_name LobProjectile
extends WaveProjectile

var _target_position: Vector3
var _peak_height: float = 4.0
var _total_distance: float
var _horizontal_dir: Vector3
var _landing_radius: float = 2.0

func initialize_lob(arena: ArenaGrid, p_caster: Node3D, caster_position: Vector3, target_position: Vector3, velocity: float, max_charges: int, projectile_lifetime: float, p_damage: float = -1.0) -> void:
	# BaseProjectile needs a direction, we'll give it the horizontal one
	var dir = (target_position - caster_position)
	dir.y = 0
	var horizontal_dir = dir.normalized()
	
	# We call regular initialize but we'll override the movement
	super.initialize(arena, p_caster, caster_position, 0.0, horizontal_dir, velocity, max_charges, projectile_lifetime, caster_position.distance_to(target_position) + 1.0, p_damage)
	
	_target_position = target_position
	_horizontal_dir = horizontal_dir
	_total_distance = caster_position.distance_to(Vector3(target_position.x, caster_position.y, target_position.z))
	
	# Adjust peak height based on distance
	_peak_height = max(2.0, _total_distance * 0.4)

func _move_projectile(_delta: float) -> void:
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

func _on_expire() -> void:
	_land()

func _land() -> void:
	if not _arena:
		queue_free()
		return
		
	var center = _arena.get_tile_at_world_position(global_transform.origin)
	if center and _arena.tile_signals:
		var hex_radius = int(ceil(_landing_radius / (1.732 * _arena.hex_size)))
		
	# Define the impact effect as a persistent trigger to avoid O(N) scanning
		# Captured variables for the lambda
		var dmg = damage_amount
		var pos = global_position
		var elem = element_type
		
		var impact_callback = func(actor: Node3D, _meta: Dictionary):
			if is_instance_valid(actor) and actor is Actor and actor.element_type != elem:
				actor.take_damage(dmg, "normal", (actor.global_position - pos).normalized())
		
		# Register the trigger. It will immediately fire for actors already in the radius.
		var trigger = _arena.tile_signals.register_trigger(center, hex_radius, impact_callback)
		
		# Apply elemental effects to tiles (optimized BFS)
		var tiles = _arena.get_tiles_in_radius(center, hex_radius)
		for tile in tiles:
			if is_instance_valid(tile):
				_arena.apply_element_to_tile(tile, elem, _horizontal_dir)
		
		# Optional: remove the trigger after a short duration if it's just an explosion
		# but the prompt implies we want to rely on the signal system's persistence.
		# We'll let it linger for 0.5s to catch immediate movement.
		get_tree().create_timer(0.5).timeout.connect(func():
			if is_instance_valid(_arena) and _arena.tile_signals:
				_arena.tile_signals.remove_trigger(trigger)
		)
			
	queue_free()

func _apply_effect_to_tiles() -> void:
	# Lob projectiles don't affect tiles while in the air
	pass
