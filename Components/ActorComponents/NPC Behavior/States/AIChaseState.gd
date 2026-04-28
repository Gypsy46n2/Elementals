class_name AIChaseState
extends AIState

var _target_actor: Node3D = null
var _lose_interest_timer: float = 0.0
var _lose_interest_time: float = 5.0

func enter() -> void:
	_target_actor = controller._find_nearest_enemy()
	_lose_interest_timer = _lose_interest_time

func physics_update(delta: float) -> void:
	if not actor or not controller or not controller.movement_component:
		return

	if not is_instance_valid(_target_actor):
		state_machine.change_state("roam")
		return

	var dist_to_target := actor.global_position.distance_to(_target_actor.global_position)

	# If in attack range, switch to attack
	if dist_to_target <= controller.attack_range:
		state_machine.change_state("attack")
		return

	# Move toward target
	var target_pos_2d := Vector2(_target_actor.global_position.x, _target_actor.global_position.z)
	var current_pos_2d := Vector2(actor.global_position.x, actor.global_position.z)
	var direction := (target_pos_2d - current_pos_2d).normalized()
	var dir_3d := Vector3(direction.x, 0, direction.y)

	var avoidance: Vector3 = controller._get_obstacle_avoidance_vector()
	if avoidance.length_squared() > 0.01:
		dir_3d = (dir_3d + avoidance * 2.0).normalized()

	controller.movement_component.move(dir_3d, delta)
	controller.movement_component.apply_gravity(delta)

	# Face target
	controller._face_target(_target_actor.global_position)

	# Lose interest if target gets too far for too long
	if dist_to_target > controller.detection_range:
		_lose_interest_timer -= delta
		if _lose_interest_timer <= 0.0:
			state_machine.change_state("roam")
	else:
		_lose_interest_timer = _lose_interest_time

	if controller._should_flee():
		state_machine.change_state("flee")

func exit() -> void:
	_target_actor = null

func get_debug_name() -> String:
	return "Chase"
