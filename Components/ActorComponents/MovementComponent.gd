class_name MovementComponent
extends Node

@export var target: Node3D
@export var is_controlled: bool = false
@export var move_speed: float = 3.0
@export var acceleration: float = 60.0
@export var friction: float = 20.0
@export var gravity: float = 9.8
@export var jump_force: float = 4.0

@export var auto_jump_on_wall: bool = true
@export var auto_jump_timeout: float = 0.15
@export var max_velocity_threshold: float = 40.0
@export var max_horizontal_velocity: float = 18.0
@export var max_vertical_velocity: float = 14.0
@export var max_external_velocity: float = 10.0
@export var max_safe_height_above_floor: float = 3.5
@export var max_safe_depth_below_floor: float = 0.75

signal stuck
signal tile_changed(tile: HexTileData, previous_tile: HexTileData)

var speed_multiplier: float = 1.0
var armor_speed_multiplier: float = 1.0
var external_velocity: Vector3 = Vector3.ZERO

var _wall_stuck_timer: float = 0.0
var _is_interpolating: bool = false
var _lerp_target: Vector3
var _current_tile: HexTileData
var _last_tile_key: String = ""  # Used to detect tile changes
var _last_horizontal_pos: Vector2 = Vector2.INF
var _last_surface_y: float = 0.0
signal interpolation_finished

func _ready() -> void:
	if not target:
		var parent: Node = get_parent()
		if parent is Node3D:
			target = parent as Node3D

func apply_external_force(force: Vector3) -> void:
	if not _is_safe_vector(force):
		return

	external_velocity += _clamp_vector(force, max_external_velocity)
	external_velocity = _clamp_vector(external_velocity, max_external_velocity)

func _physics_process(delta: float) -> void:
	if not target:
		return

	if target is CharacterBody3D and external_velocity.length_squared() > 0.001:
		var cb_with_force: CharacterBody3D = target as CharacterBody3D
		cb_with_force.velocity += external_velocity
		external_velocity = Vector3.ZERO

	if target is CharacterBody3D:
		var cb: CharacterBody3D = target as CharacterBody3D
		_sanitize_character_body(cb)

	if _is_interpolating:
		_process_interpolation(delta)

	_update_auto_jump(delta)

func _sanitize_character_body(cb: CharacterBody3D) -> void:
	if not _is_safe_vector(cb.global_position):
		_reset_character_to_safe_position(cb, "Invalid position")
		return

	if not _is_safe_vector(cb.velocity):
		cb.velocity = Vector3.ZERO

	var horizontal_velocity: Vector3 = Vector3(cb.velocity.x, 0.0, cb.velocity.z)
	var too_fast: bool = cb.velocity.length() > max_velocity_threshold
	too_fast = too_fast or horizontal_velocity.length() > max_horizontal_velocity
	too_fast = too_fast or abs(cb.velocity.y) > max_vertical_velocity

	if too_fast:
		cb.velocity = Vector3.ZERO
		external_velocity = Vector3.ZERO
		_wall_stuck_timer = 0.0

	# Only do expensive grid lookup when needed (moved horizontally or haven't checked yet)
	var horizontal_pos := Vector2(cb.global_position.x, cb.global_position.z)
	var has_moved_horizontally := horizontal_pos.distance_squared_to(_last_horizontal_pos) > 0.001
	
	var surface_y: float = 0.0
	var has_surface: bool = false
	
	if has_moved_horizontally or _current_tile == null:
		var surface_result: Dictionary = _get_surface_data(cb.global_position)
		if bool(surface_result.get("found", false)):
			has_surface = true
			surface_y = float(surface_result.get("y", 0.0))
			_last_surface_y = surface_y
			# Detect tile change
			var tile: HexTileData = surface_result.get("tile") as HexTileData
			_check_and_emit_tile_changed(tile)
		else:
			# No tile found at this position
			_check_and_emit_tile_changed(null)
		
		_last_horizontal_pos = horizontal_pos
	else:
		# Use cached values
		has_surface = _current_tile != null
		surface_y = _last_surface_y

	if has_surface:
		var below_floor: bool = cb.global_position.y < surface_y - max_safe_depth_below_floor
		var above_floor: bool = cb.global_position.y > surface_y + max_safe_height_above_floor
		if below_floor or above_floor:
			var reason: String = "Below floor" if below_floor else "Above floor"
			_reset_character_to_surface(cb, surface_y, reason)
	elif cb.global_position.y > 18.0 or cb.global_position.y < -12.0:
		_reset_character_to_safe_position(cb, "No tile and unsafe height")

func _check_and_emit_tile_changed(new_tile: HexTileData) -> void:
	var tile_key: String = ""
	if new_tile:
		tile_key = str(new_tile.axial_coords.x) + "," + str(new_tile.axial_coords.y)
	
	# Check if we actually moved to a different tile by comparing to stored key
	if _last_tile_key != tile_key:
		var prev_tile: HexTileData = _current_tile
		tile_changed.emit(new_tile, prev_tile)
	
	_current_tile = new_tile
	_last_tile_key = tile_key

func _reset_character_to_surface(cb: CharacterBody3D, surface_y: float, reason: String) -> void:
	printerr("MovementComponent: ", reason, " detected on ", cb.name, ". Resetting vertical position.")
	cb.global_position.y = surface_y + 0.05
	cb.velocity = Vector3.ZERO
	external_velocity = Vector3.ZERO
	_wall_stuck_timer = 0.0

func _reset_character_to_safe_position(cb: CharacterBody3D, reason: String) -> void:
	printerr("MovementComponent: ", reason, " detected on ", cb.name, ". Resetting movement.")
	cb.velocity = Vector3.ZERO
	external_velocity = Vector3.ZERO
	_wall_stuck_timer = 0.0
	if not _is_safe_number(cb.global_position.y):
		cb.global_position.y = 0.05
	elif cb.global_position.y > 18.0 or cb.global_position.y < -12.0:
		cb.global_position.y = 0.05

func _get_surface_data(pos: Vector3) -> Dictionary:
	var result: Dictionary = {"found": false, "y": 0.0, "tile": null}
	if not target:
		return result

	var arena: Object = target.get("_arena_grid") as Object
	if not arena:
		# Fallback: try to find arena in the tree if actor doesn't have it set
		var parent = target.get_parent()
		while parent:
			if parent is ArenaGrid:
				arena = parent
				break
			parent = parent.get_parent()

	if not arena:
		return result
		
	if not arena.has_method("get_tile_at_world_position") or not arena.has_method("_get_tile_surface_y"):
		return result

	var tile: Object = arena.call("get_tile_at_world_position", pos) as Object
	if not tile:
		return result

	result["tile"] = tile
	var surface_value: Variant = arena.call("_get_tile_surface_y", tile)
	if typeof(surface_value) == TYPE_FLOAT or typeof(surface_value) == TYPE_INT:
		result["found"] = true
		result["y"] = float(surface_value)

	return result

func _update_auto_jump(delta: float) -> void:
	if is_controlled or not auto_jump_on_wall or not (target is CharacterBody3D):
		_wall_stuck_timer = 0.0
		return

	var cb: CharacterBody3D = target as CharacterBody3D
	var intended_h_vel: Vector2 = Vector2(cb.velocity.x, cb.velocity.z)
	var is_moving_horizontally: bool = intended_h_vel.length_squared() > 0.1
	var real_h_vel: Vector2 = Vector2(cb.get_real_velocity().x, cb.get_real_velocity().z)
	var is_blocked: bool = is_moving_horizontally and real_h_vel.length() < intended_h_vel.length() * 0.3

	if (cb.is_on_wall() or is_blocked) and is_moving_horizontally:
		_wall_stuck_timer += delta
		if _wall_stuck_timer >= auto_jump_timeout:
			jump()
			stuck.emit()
			_wall_stuck_timer = 0.0
	else:
		_wall_stuck_timer = move_toward(_wall_stuck_timer, 0.0, delta * 2.0)

func _process_interpolation(delta: float) -> void:
	if not target:
		_is_interpolating = false
		return

	target.global_position = target.global_position.move_toward(_lerp_target, move_speed * delta)
	if target.global_position.distance_to(_lerp_target) < 0.01:
		target.global_position = _lerp_target
		_is_interpolating = false
		interpolation_finished.emit()

func move_to(target_pos: Vector3) -> void:
	if not _is_safe_vector(target_pos):
		return
	_lerp_target = target_pos
	_is_interpolating = true

func move(direction: Vector3, delta: float) -> void:
	if not target or not (target is CharacterBody3D):
		return

	if not _is_safe_vector(direction):
		direction = Vector3.ZERO

	var cb: CharacterBody3D = target as CharacterBody3D
	var safe_direction: Vector3 = direction
	if safe_direction.length() > 1.0:
		safe_direction = safe_direction.normalized()

	var target_vel: Vector3 = safe_direction * move_speed * speed_multiplier * armor_speed_multiplier
	var horizontal_vel: Vector3 = Vector3(cb.velocity.x, 0.0, cb.velocity.z)

	if safe_direction.length() > 0.01:
		horizontal_vel = horizontal_vel.move_toward(target_vel, acceleration * delta)
	else:
		horizontal_vel = horizontal_vel.move_toward(Vector3.ZERO, friction * delta)

	horizontal_vel = _clamp_vector(horizontal_vel, max_horizontal_velocity)
	cb.velocity.x = horizontal_vel.x
	cb.velocity.z = horizontal_vel.z

func apply_gravity(delta: float) -> void:
	if not target or not (target is CharacterBody3D):
		return

	var cb: CharacterBody3D = target as CharacterBody3D
	if not cb.is_on_floor():
		cb.velocity.y -= gravity * delta
		cb.velocity.y = clamp(cb.velocity.y, -max_vertical_velocity, max_vertical_velocity)
	elif cb.velocity.y < 0:
		cb.velocity.y = 0.0

func jump() -> void:
	if not target or not (target is CharacterBody3D):
		return

	var cb: CharacterBody3D = target as CharacterBody3D
	if cb.is_on_floor() or cb.is_on_wall():
		cb.velocity.y = min(jump_force, max_vertical_velocity)

		var horizontal_vel: Vector3 = Vector3(cb.velocity.x, 0.0, cb.velocity.z)
		if horizontal_vel.length_squared() > 0.1:
			var scramble_force: Vector3 = horizontal_vel.normalized() * min(3.0, max_horizontal_velocity * 0.25)
			cb.velocity += scramble_force
			cb.velocity = _clamp_velocity(cb.velocity)

func apply_pickup_penalty() -> void:
	speed_multiplier = 0.5
	var timer: SceneTreeTimer = get_tree().create_timer(0.5)
	timer.timeout.connect(func() -> void:
		speed_multiplier = 1.0
	)

func get_move_speed() -> float:
	return move_speed

func get_jump_force() -> float:
	return jump_force

func get_current_tile() -> HexTileData:
	return _current_tile

func get_surface_y() -> float:
	if _current_tile and target:
		var arena: Object = target.get("_arena_grid") as Object
		if arena and arena.has_method("_get_tile_surface_y"):
			var surface_value: Variant = arena.call("_get_tile_surface_y", _current_tile)
			if typeof(surface_value) == TYPE_FLOAT or typeof(surface_value) == TYPE_INT:
				return float(surface_value)
	return 0.0

func stop(delta: float = 0.0) -> void:
	_is_interpolating = false
	external_velocity = Vector3.ZERO
	if target is CharacterBody3D:
		var cb: CharacterBody3D = target as CharacterBody3D
		if delta <= 0.0:
			cb.velocity.x = 0.0
			cb.velocity.z = 0.0
		else:
			move(Vector3.ZERO, delta)

func _clamp_velocity(value: Vector3) -> Vector3:
	var horizontal: Vector3 = Vector3(value.x, 0.0, value.z)
	if horizontal.length() > max_horizontal_velocity:
		horizontal = horizontal.normalized() * max_horizontal_velocity

	return Vector3(horizontal.x, clamp(value.y, -max_vertical_velocity, max_vertical_velocity), horizontal.z)

func _clamp_vector(value: Vector3, max_length: float) -> Vector3:
	if not _is_safe_vector(value):
		return Vector3.ZERO
	if value.length() > max_length:
		return value.normalized() * max_length
	return value

func _is_safe_vector(v: Vector3) -> bool:
	return _is_safe_number(v.x) and _is_safe_number(v.y) and _is_safe_number(v.z)

func _is_safe_number(value: float) -> bool:
	return value == value and abs(value) < 100000.0
