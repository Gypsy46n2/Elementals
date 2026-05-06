class_name AIStunnedState
extends AIState

## Affected state that overrides all base behavior while the actor is stunned.

func enter() -> void:
	if controller and controller.movement_component:
		controller.movement_component.stop(0.0)

func physics_update(delta: float) -> void:
	if not controller:
		return
	if controller.movement_component:
		controller.movement_component.apply_gravity(delta)
		controller.movement_component.stop(delta)

func get_debug_name() -> String:
	return "Stunned"
