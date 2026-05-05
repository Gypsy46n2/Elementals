class_name AIFlockinState
extends AIState

var _target_reached_threshold: float = 0.2
var _retarget_timer: float = 0.0
var _retarget_interval: float = 1.0

func enter() -> void:
	_retarget_timer = 0.0
	_choose_new_target()

func physics_update(delta: float) -> void:
	if not actor or not controller or not controller.movement_component:
		return

	# Check if player goat still exists - if not, fall back to roam
	var goat_controller: GoatController = controller as GoatController
	if goat_controller:
		var player_goat: Node3D = goat_controller._get_player_goat()
		if not player_goat and state_machine:
			state_machine.change_state("roam")
			return

	var current_pos_2d := Vector2(actor.global_transform.origin.x, actor.global_transform.origin.z)
	var target_pos_2d := Vector2(controller._movement_target.x, controller._movement_target.z)

	if current_pos_2d.distance_to(target_pos_2d) < _target_reached_threshold:
		_choose_new_target()

	var direction := (target_pos_2d - current_pos_2d).normalized()
	var dir_3d := Vector3(direction.x, 0, direction.y)

	var avoidance: Vector3 = controller._get_obstacle_avoidance_vector()
	if avoidance.length_squared() > 0.01:
		dir_3d = (dir_3d + avoidance * 2.0).normalized()

	controller.movement_component.move(dir_3d, delta)
	controller.movement_component.apply_gravity(delta)

	# Periodic retargeting to keep up with the player goat
	_retarget_timer -= delta
	if _retarget_timer <= 0.0:
		_retarget_timer = _retarget_interval
		_choose_new_target()

func _choose_new_target() -> void:
	if not actor or not actor._arena_grid:
		return

	var goat_controller: GoatController = controller as GoatController
	if not goat_controller:
		return

	var player_goat: Node3D = goat_controller._get_player_goat()
	
	# Fall back to random wandering if no player goat exists
	if not player_goat:
		_fallback_wander()
		return

	actor.tile_interaction_component.update_tile_below()
	var ground_tile: HexTileData = actor.tile_interaction_component.get_ground_tile()
	if not ground_tile:
		return

	var dist_to_player = actor.global_position.distance_to(player_goat.global_position)
	var neighbors = actor.tile_navigation_component.get_traversable_neighbors(ground_tile)

	if neighbors.is_empty():
		return

	var next_tile: HexTileData = null

	if dist_to_player > goat_controller.max_follow_distance:
		# Seek player: pick neighbor closest to player
		neighbors.sort_custom(func(a, b):
			return a.position.distance_to(player_goat.global_position) < b.position.distance_to(player_goat.global_position)
		)
		next_tile = neighbors[0]
	elif dist_to_player < goat_controller.min_follow_distance:
		# Repel/Maintain: pick neighbor further from player
		neighbors.sort_custom(func(a, b):
			return a.position.distance_to(player_goat.global_position) > b.position.distance_to(player_goat.global_position)
		)
		next_tile = neighbors[0]
	else:
		# Random wander within neighbors
		var candidates = neighbors.filter(func(t): return t != controller._previous_tile)
		if candidates.size() > 0:
			next_tile = candidates[controller._rng.randi_range(0, candidates.size() - 1)]
		else:
			next_tile = neighbors.pick_random()

	if next_tile:
		controller._previous_tile = ground_tile
		controller._movement_target = next_tile.position
		controller._movement_target.y = actor.global_position.y

func _fallback_wander() -> void:
	"""Fallback behavior when no player goat is available - wander randomly."""
	actor.tile_interaction_component.update_tile_below()
	var ground_tile: HexTileData = actor.tile_interaction_component.get_ground_tile()
	if not ground_tile:
		return
	
	var neighbors = actor.tile_navigation_component.get_traversable_neighbors(ground_tile)
	if neighbors.is_empty():
		return
	
	# Try to avoid going back to the previous tile
	var candidates = neighbors.filter(func(t): return t != controller._previous_tile)
	var next_tile: HexTileData
	if candidates.size() > 0:
		next_tile = candidates[controller._rng.randi_range(0, candidates.size() - 1)]
	else:
		next_tile = neighbors[controller._rng.randi_range(0, neighbors.size() - 1)]
	
	if next_tile:
		controller._previous_tile = ground_tile
		controller._movement_target = next_tile.position
		controller._movement_target.y = actor.global_position.y

func get_debug_name() -> String:
	return "Flock"
