class_name DecisionComponent
extends Node

@export var movement_component: MovementComponent
@export var is_controlled: bool = false

func _physics_process(delta: float) -> void:
	if not movement_component:
		return
	
	if is_controlled:
		_handle_controlled_input(delta)
	else:
		_handle_ai_logic(delta)

func _handle_controlled_input(delta: float) -> void:
	# Base implementation for player input
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
		
	var input_dir = Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP):
		input_dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN):
		input_dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
		input_dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
		input_dir.x += 1
	
	input_dir = input_dir.normalized()
	
	var cam_basis = camera.global_transform.basis
	var forward = -cam_basis.z
	var right = cam_basis.x
	
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()
	
	var direction = (forward * (-input_dir.y) + right * input_dir.x).normalized()
	
	movement_component.move(direction, delta)
	movement_component.apply_gravity(delta)
	
	if Input.is_key_pressed(KEY_SPACE):
		movement_component.jump()

func _choose_new_target() -> void:
	# Virtual method for choosing a new movement target
	pass

func get_debug_state() -> String:
	if is_controlled:
		return "CONTROLLED"
	return "AI"

func _handle_ai_logic(_delta: float) -> void:
	# Virtual method for AI behavior
	pass
