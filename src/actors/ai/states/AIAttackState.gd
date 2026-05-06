class_name AIAttackState
extends AIState

var _target_actor: Node3D = null
var _strafe_dir: int = 1
var _strafe_change_timer: float = 0.0

func enter() -> void:
	_target_actor = controller._find_nearest_enemy()
	_strafe_change_timer = 0.0
	_strafe_dir = 1 if randf() > 0.5 else -1

func physics_update(delta: float) -> void:
	if not actor or not controller or not controller.movement_component:
		return

	if not is_instance_valid(_target_actor):
		state_machine.change_state("roam")
		return

	var dist_to_target := actor.global_position.distance_to(_target_actor.global_position)

	# Determine effective attack distance based on weapon
	var is_melee := false
	var effective_attack_range: float = controller.attack_range
	var min_approach_dist: float = 0.0
	if actor.weapon_component and actor.weapon_component.weapon_data:
		var wd: WeaponData = actor.weapon_component.weapon_data
		if not wd.is_ranged and not wd.is_thrown:
			is_melee = true
			effective_attack_range = wd.reach * 1.5
			min_approach_dist = wd.reach * 0.5
		elif wd.is_thrown and actor.weapon_component.current_ammo <= 1:
			# Save the last thrown weapon ammo for melee
			is_melee = true
			effective_attack_range = wd.reach * 1.5
			min_approach_dist = wd.reach * 0.5

	# If target moved out of attack range, chase
	if dist_to_target > controller.attack_range:
		state_machine.change_state("chase")
		return
	
	# If target is beyond 2× detection range, give up and roam
	if dist_to_target > controller.detection_range * 2.0:
		state_machine.change_state("roam")
		return

	# Face target
	controller._face_target(_target_actor.global_position)

	# Melee movement: pursue + strafe, stopping forward movement at 0.75× reach
	if is_melee:
		_strafe_change_timer -= delta
		if _strafe_change_timer <= 0.0:
			_strafe_dir = 1 if randf() > 0.5 else -1
			_strafe_change_timer = randf_range(0.3, 0.8)

		var target_pos_2d := Vector2(_target_actor.global_position.x, _target_actor.global_position.z)
		var current_pos_2d := Vector2(actor.global_position.x, actor.global_position.z)
		var to_target := (target_pos_2d - current_pos_2d).normalized()
		var forward := Vector3(to_target.x, 0, to_target.y)
		
		# Perpendicular strafe
		var strafe := Vector3(-to_target.y, 0, to_target.x) * _strafe_dir
		
		var move_dir := Vector3.ZERO
		
		# Pursue if not too close
		if dist_to_target > min_approach_dist:
			move_dir += forward
		
		# Always strafe
		move_dir += strafe
		
		# Apply obstacle avoidance
		var avoidance: Vector3 = controller._get_obstacle_avoidance_vector()
		if avoidance.length_squared() > 0.01:
			move_dir = (move_dir + avoidance * 2.0).normalized()
		elif move_dir.length_squared() > 0.01:
			move_dir = move_dir.normalized()
		
		controller.movement_component.move(move_dir, delta)
		controller.movement_component.apply_gravity(delta)
		
		# Attack when within effective range
		if dist_to_target <= effective_attack_range and actor.weapon_component:
			actor.weapon_component.attack_target(_target_actor.global_position)
		
		if controller._should_flee():
			state_machine.change_state("flee")
		
		return

	# Non-melee: stop and attack from range
	controller.movement_component.stop(delta)
	controller.movement_component.apply_gravity(delta)

	# Combat: weapon attack or auto-fire when mana is full
	if actor.weapon_component:
		actor.weapon_component.attack_target(_target_actor.global_position)
	elif actor.mana_component and actor.projectile_component:
		if actor.mana_component.current_mana >= actor.mana_component.max_mana and not actor.is_stunned():
			actor.projectile_component.launch_projectile_ai(actor.mana_component)

	if controller._should_flee():
		state_machine.change_state("flee")

func exit() -> void:
	_target_actor = null

func get_debug_name() -> String:
	return "Attack"
