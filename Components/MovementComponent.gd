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

signal stuck

var speed_multiplier: float = 1.0
var external_velocity: Vector3 = Vector3.ZERO

var _wall_stuck_timer: float = 0.0
var _is_interpolating: bool = false
var _lerp_target: Vector3
signal interpolation_finished

func _ready() -> void:
	if not target:
		var parent = get_parent()
		if parent is Node3D:
			target = parent

func _physics_process(delta: float) -> void:
	if not target:
		return
		
	if _is_interpolating:
		_process_interpolation(delta)
	
	_update_auto_jump(delta)

func _update_auto_jump(delta: float) -> void:
	if is_controlled or not auto_jump_on_wall or not (target is CharacterBody3D):
		_wall_stuck_timer = 0.0
		return
		
	var cb = target as CharacterBody3D
	
	# Only consider ourselves "stuck" if we are trying to move
	var intended_h_vel = Vector2(cb.velocity.x, cb.velocity.z)
	var is_moving_horizontally = intended_h_vel.length_squared() > 0.1
	
	# More robust stuck detection: if we are trying to move but our real velocity is much lower
	# Note: get_real_velocity() is from the previous frame's move_and_slide()
	var real_h_vel = Vector2(cb.get_real_velocity().x, cb.get_real_velocity().z)
	var is_blocked = is_moving_horizontally and real_h_vel.length() < intended_h_vel.length() * 0.3
	
	if (cb.is_on_wall() or is_blocked) and is_moving_horizontally:
		_wall_stuck_timer += delta
		if _wall_stuck_timer >= auto_jump_timeout:
			jump()
			stuck.emit()
			_wall_stuck_timer = 0.0
	else:
		_wall_stuck_timer = move_toward(_wall_stuck_timer, 0.0, delta * 2.0)

func _process_interpolation(delta: float) -> void:
	target.global_position = target.global_position.move_toward(_lerp_target, move_speed * delta)
	if target.global_position.distance_to(_lerp_target) < 0.01:
		target.global_position = _lerp_target
		_is_interpolating = false
		interpolation_finished.emit()

func move_to(target_pos: Vector3) -> void:
	_lerp_target = target_pos
	_is_interpolating = true

func move(direction: Vector3, delta: float) -> void:
	if not target or not (target is CharacterBody3D):
		return
	
	var cb = target as CharacterBody3D
	var target_vel = direction * move_speed * speed_multiplier
	
	# Horizontal movement
	var horizontal_vel = Vector3(cb.velocity.x, 0, cb.velocity.z)
	
	if direction.length() > 0.01:
		horizontal_vel = horizontal_vel.move_toward(target_vel, acceleration * delta)
	else:
		horizontal_vel = horizontal_vel.move_toward(Vector3.ZERO, friction * delta)
	
	cb.velocity.x = horizontal_vel.x
	cb.velocity.z = horizontal_vel.z

func apply_gravity(delta: float) -> void:
	if not target or not (target is CharacterBody3D):
		return
	
	var cb = target as CharacterBody3D
	if not cb.is_on_floor():
		cb.velocity.y -= gravity * delta
	elif cb.velocity.y < 0:
		# Reset vertical velocity when on floor only if we're falling
		cb.velocity.y = 0.0

func jump() -> void:
	if not target or not (target is CharacterBody3D):
		return
	
	var cb = target as CharacterBody3D
	# Allow jumping if on floor OR if we are against a wall (climbing/scrambling)
	if cb.is_on_floor() or cb.is_on_wall():
		cb.velocity.y = jump_force
		
		# Add a "scramble" nudge: a little extra push in the direction we are trying to move
		# This helps clear the lip of a cliff or a tree's collision shape
		var horizontal_vel = Vector3(cb.velocity.x, 0, cb.velocity.z)
		if horizontal_vel.length_squared() > 0.1:
			cb.velocity += horizontal_vel.normalized() * 3.0
			
		# print("Jumping/Scrambling: ", cb.name)

func apply_external_force(force: Vector3) -> void:
	if not target:
		return
	
	if target is CharacterBody3D:
		target.velocity += force
	else:
		# Maybe push it for a duration?
		# For now just jump there
		move_to(target.global_position + force)

func stop(delta: float) -> void:
	if target is CharacterBody3D:
		move(Vector3.ZERO, delta)
	else:
		_is_interpolating = false
