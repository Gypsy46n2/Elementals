class_name AIDeathState
extends AIState

## Death state: disables all movement and AI behavior.
## The actor remains as a lootable corpse until resurrected.

func enter() -> void:
	if controller and controller.movement_component:
		controller.movement_component.stop(0.0)

func physics_update(_delta: float) -> void:
	# Dead actors do nothing.
	pass

func get_debug_name() -> String:
	return "Death"
