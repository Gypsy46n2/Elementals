class_name AIState
extends RefCounted

## Reference to the state machine managing this state.
var state_machine: Variant
## Reference to the actor this state controls.
var actor: Node3D
## Reference to the AI controller that owns this state.
var controller: Variant

## Called when the state machine enters this state.
func enter() -> void:
	pass

## Called when the state machine exits this state.
func exit() -> void:
	pass

## Called every frame during _process.
func update(_delta: float) -> void:
	pass

## Called every physics tick during _physics_process.
func physics_update(_delta: float) -> void:
	pass

## Returns a debug-friendly name for this state.
func get_debug_name() -> String:
	return "AIState"
