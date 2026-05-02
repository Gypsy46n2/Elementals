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
	# Check if player is far enough to enter dormant state
	var player_node: Node3D = _get_player_node()
	if player_node != null and _is_player_far(player_node):
		state_machine.change_state("dormant")
		return

	var enemy: Node3D = controller._find_nearest_enemy()
	if enemy:
		state_machine.change_state("chase")
		return

	_idle_timer -= delta
	if _idle_timer <= 0.0:
		state_machine.change_state("roam")

func get_debug_name() -> String:
	return "Idle"

func _get_player_node() -> Node3D:
	if not actor or not actor._arena_grid:
		return null
	
	var arena = actor._arena_grid
	var actor_value: Variant = arena.get("current_controlled_actor")
	if actor_value != null and is_instance_valid(actor_value) and actor_value is Node3D:
		return actor_value as Node3D
	
	var actor_list_value: Variant = arena.get("actors")
	if typeof(actor_list_value) == TYPE_ARRAY:
		var actor_list: Array = actor_list_value as Array
		for raw_actor in actor_list:
			if raw_actor != null and is_instance_valid(raw_actor) and raw_actor is Actor:
				var actor_object: Actor = raw_actor as Actor
				if actor_object.is_playable:
					return raw_actor as Node3D
	return null

func _is_player_far(player: Node3D) -> bool:
	if not actor._arena_grid:
		return false
	
	var player_tile: Object = null
	if player.tile_interaction_component:
		player_tile = player.tile_interaction_component.get_ground_tile()
	
	var actor_tile: Object = null
	if actor.tile_interaction_component:
		actor_tile = actor.tile_interaction_component.get_ground_tile()
	
	if player_tile == null or actor_tile == null:
		return false
	
	var hex_distance: int = _get_hex_distance(player_tile.axial_coords, actor_tile.axial_coords)
	return hex_distance > 15

func _get_hex_distance(a: Vector2i, b: Vector2i) -> int:
	return (abs(a.x - b.x) + abs(a.x + a.y - b.x - b.y) + abs(a.y - b.y)) / 2
