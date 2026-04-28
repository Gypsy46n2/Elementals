class_name AIIdleState
extends AIState

var _idle_timer: float = 0.0
var _min_idle_time: float = 1.0
var _max_idle_time: float = 3.0

func enter() -> void:
	_idle_timer = controller._rng.randf_range(_min_idle_time, _max_idle_time)
	if controller.movement_component:
		controller.movement_component.stop(0.0)

func physics_update(delta: float) -> void:
	if not actor or not controller:
		return

	if controller.movement_component:
		controller.movement_component.apply_gravity(delta)
		controller.movement_component.stop(delta)

	# Transition checks
	var enemy: Node3D = controller._find_nearest_enemy()
	if enemy:
		state_machine.change_state("chase")
		return

	_idle_timer -= delta
	if _idle_timer <= 0.0:
		state_machine.change_state("roam")

func get_debug_name() -> String:
	return "Idle"
