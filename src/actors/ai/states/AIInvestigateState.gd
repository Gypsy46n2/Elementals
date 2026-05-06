class_name AIInvestigateState
extends AIState

var _investigate_target: Vector3 = Vector3.ZERO
var _investigate_timer: float = 0.0
var _max_investigate_time: float = 5.0

func enter() -> void:
	_investigate_timer = _max_investigate_time
	# Default to current movement target if no specific point was set
	_investigate_target = controller._movement_target

func physics_update(delta: float) -> void:
	if not actor or not controller or not controller.movement_component:
		return

	var current_pos_2d := Vector2(actor.global_transform.origin.x, actor.global_transform.origin.z)
	var target_pos_2d := Vector2(_investigate_target.x, _investigate_target.z)

	if current_pos_2d.distance_to(target_pos_2d) < 0.5:
		# Look around briefly then go back to idle
		controller.movement_component.stop(delta)
		controller.movement_component.apply_gravity(delta)
		_investigate_timer -= delta
		if _investigate_timer <= 0.0:
			state_machine.change_state("idle")
		return

	var direction := (target_pos_2d - current_pos_2d).normalized()
	var dir_3d := Vector3(direction.x, 0, direction.y)

	var avoidance: Vector3 = controller._get_obstacle_avoidance_vector()
	if avoidance.length_squared() > 0.01:
		dir_3d = (dir_3d + avoidance * 2.0).normalized()

	controller.movement_component.move(dir_3d, delta)
	controller.movement_component.apply_gravity(delta)

	# If we see an enemy while investigating, chase them
	var enemy: Node3D = controller._find_nearest_enemy()
	if enemy:
		state_machine.change_state("chase")

	_investigate_timer -= delta
	if _investigate_timer <= 0.0:
		state_machine.change_state("roam")

func get_debug_name() -> String:
	return "Investigate"
