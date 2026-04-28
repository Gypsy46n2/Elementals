class_name AIFleeState
extends AIState

var _flee_timer: float = 0.0
var _flee_duration: float = 4.0

func enter() -> void:
	_flee_timer = _flee_duration
	_pick_flee_target()

func physics_update(delta: float) -> void:
	if not actor or not controller or not controller.movement_component:
		return

	var current_pos_2d := Vector2(actor.global_transform.origin.x, actor.global_transform.origin.z)
	var target_pos_2d := Vector2(controller._movement_target.x, controller._movement_target.z)

	if current_pos_2d.distance_to(target_pos_2d) < 0.5:
		controller._choose_new_target()

	var direction := (target_pos_2d - current_pos_2d).normalized()
	var dir_3d := Vector3(direction.x, 0, direction.y)

	var avoidance: Vector3 = controller._get_obstacle_avoidance_vector()
	if avoidance.length_squared() > 0.01:
		dir_3d = (dir_3d + avoidance * 2.0).normalized()

	# Move faster when fleeing
	controller.movement_component.speed_multiplier = 1.5
	controller.movement_component.move(dir_3d, delta)
	controller.movement_component.apply_gravity(delta)

	_flee_timer -= delta
	if _flee_timer <= 0.0:
		controller.movement_component.speed_multiplier = 1.0
		state_machine.change_state("roam")

func exit() -> void:
	if controller.movement_component:
		controller.movement_component.speed_multiplier = 1.0

func _pick_flee_target() -> void:
	if not actor or not actor._arena_grid:
		return

	var enemy: Node3D = controller._find_nearest_enemy()
	if not enemy:
		controller._choose_new_target()
		return

	actor.tile_interaction_component.update_tile_below()
	var ground_tile: HexTileData = actor.tile_interaction_component.get_ground_tile()
	if not ground_tile:
		controller._choose_new_target()
		return

	var neighbors: Array[HexTileData] = actor.tile_navigation_component.get_traversable_neighbors(ground_tile)
	if neighbors.is_empty():
		controller._choose_new_target()
		return

	# Pick the neighbor furthest from the enemy
	neighbors.sort_custom(func(a: HexTileData, b: HexTileData) -> bool:
		return a.position.distance_to(enemy.global_position) > b.position.distance_to(enemy.global_position)
	)

	controller._previous_tile = ground_tile
	controller._movement_target = neighbors[0].position
	controller._movement_target.y = actor.global_position.y

func get_debug_name() -> String:
	return "Flee"
