class_name AIAttackState
extends AIState

var _target_actor: Node3D = null

func enter() -> void:
	_target_actor = controller._find_nearest_enemy()

func physics_update(delta: float) -> void:
	if not actor or not controller or not controller.movement_component:
		return

	if not is_instance_valid(_target_actor):
		state_machine.change_state("roam")
		return

	var dist_to_target := actor.global_position.distance_to(_target_actor.global_position)

	# If target moved out of attack range, chase
	if dist_to_target > controller.attack_range:
		state_machine.change_state("chase")
		return

	# Face target
	controller._face_target(_target_actor.global_position)

	# Stop moving or circle strafe (for now, stop)
	controller.movement_component.stop(delta)
	controller.movement_component.apply_gravity(delta)

	# Combat: auto-fire when mana is full
	if actor.mana_component and actor.projectile_component:
		if actor.mana_component.current_mana >= actor.mana_component.max_mana and not actor.is_stunned():
			actor.projectile_component.launch_projectile_ai(actor.mana_component)

	if controller._should_flee():
		state_machine.change_state("flee")

func exit() -> void:
	_target_actor = null

func get_debug_name() -> String:
	return "Attack"
