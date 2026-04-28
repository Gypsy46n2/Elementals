class_name AIRoamState
extends AIState

var _target_reached_threshold: float = 0.2
var _roam_timer: float = 0.0

func enter() -> void:
	_roam_timer = controller._rng.randf_range(4.0, 8.0)
	if controller._movement_target.distance_to(actor.global_position) < 0.1:
		controller._choose_new_target()

func physics_update(delta: float) -> void:
	if not actor or not controller or not controller.movement_component:
		return

	var current_pos_2d := Vector2(actor.global_transform.origin.x, actor.global_transform.origin.z)
	var target_pos_2d := Vector2(controller._movement_target.x, controller._movement_target.z)

	if current_pos_2d.distance_to(target_pos_2d) < _target_reached_threshold:
		controller._choose_new_target()

	var direction := (target_pos_2d - current_pos_2d).normalized()
	var dir_3d := Vector3(direction.x, 0, direction.y)

	var avoidance: Vector3 = controller._get_obstacle_avoidance_vector()
	if avoidance.length_squared() > 0.01:
		dir_3d = (dir_3d + avoidance * 2.0).normalized()

	controller.movement_component.move(dir_3d, delta)
	controller.movement_component.apply_gravity(delta)

	# Combat: auto-fire when mana is full
	if actor.mana_component and actor.projectile_component:
		if actor.mana_component.current_mana >= actor.mana_component.max_mana and not actor.is_stunned():
			actor.projectile_component.launch_projectile_ai(actor.mana_component)

	# Transition checks
	var enemy: Node3D = controller._find_nearest_enemy()
	if enemy:
		state_machine.change_state("chase")
		return

	if controller._should_flee():
		state_machine.change_state("flee")
		return

	_roam_timer -= delta
	if _roam_timer <= 0.0:
		state_machine.change_state("idle")

func get_debug_name() -> String:
	return "Roam"
