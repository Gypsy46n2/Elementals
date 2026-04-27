## Base class for all actor decision-making logic.
## This component acts as the 'brain' of an Actor, deciding where to move and 
## how to react, then passing those intentions to the MovementComponent.
class_name ActorController
extends Node

## The movement component that this controller will control.
@export var movement_component: MovementComponent

## If true, this component ignores AI logic and listens for player input instead.
@export var is_controlled: bool = false

## Main update loop that dispatches control to either player input or AI logic.
func _physics_process(delta: float) -> void:
	if not movement_component:
		return
	
	if is_controlled:
		_handle_controlled_input(delta)
	else:
		_handle_ai_logic(delta)

## Processes keyboard input (WASD/Arrows) to move the actor.
## Translates 2D input into 3D movement relative to the current camera's orientation.
func _handle_controlled_input(delta: float) -> void:
	# Base implementation for player input
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
		
	# Gather 2D input vector from keyboard
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
	
	# Project camera basis onto the XZ plane to determine 'forward' and 'right' in world space
	var cam_basis = camera.global_transform.basis
	var forward = -cam_basis.z
	var right = cam_basis.x
	
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()
	
	# Calculate final 3D direction vector
	var direction = (forward * (-input_dir.y) + right * input_dir.x).normalized()
	
	# Apply movement and physics via the MovementComponent
	movement_component.move(direction, delta)
	movement_component.apply_gravity(delta)
	
	# Handle jump input
	if Input.is_key_pressed(KEY_SPACE):
		movement_component.jump()

## Virtual method intended to be overridden by subclasses.
## Should implement the logic for picking a new destination (e.g., random wandering).
func _choose_new_target() -> void:
	# Virtual method for choosing a new movement target
	pass

## Returns a string representation of the current control state for debugging tools.
func get_debug_state() -> String:
	if is_controlled:
		return "CONTROLLED"
	return "AI"

## Virtual method intended to be overridden by subclasses.
## Should implement the autonomous behavior (FSM, steering, etc.) for the NPC.
func _handle_ai_logic(_delta: float) -> void:
	# Virtual method for AI behavior
	pass
