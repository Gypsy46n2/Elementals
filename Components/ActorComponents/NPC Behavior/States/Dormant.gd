extends AIState

## State that puts the actor into a dormant/idle state when the player is far away.
## Actors will return to their previous state (typically Idle) when the player
## moves back within the 15 tile range.

## Distance in tiles beyond which the actor becomes dormant.
var dormant_radius_tiles: int = 15

## The previous base state to restore when player returns.
var _previous_state: String = "idle"

## Reference to TileSignalComponent for efficient event-driven triggering.
var _tile_signal_component: TileSignalComponent = null

## The trigger registered with TileSignalComponent, used for cleanup.
var _trigger: Dictionary = {}

## Callback handle for the trigger, used for proper disconnection.
var _callback_instance: Callable = Callable()

func enter() -> void:
	_previous_state = state_machine.get_base_state_name()
	_trigger = {}
	_tile_signal_component = null
	
	# Try to register a tile-based trigger for efficient event-driven activation.
	_register_tile_trigger()
	
	# Stop movement while dormant.
	if controller.movement_component:
		controller.movement_component.stop(0.0)

func exit() -> void:
	# Clean up the tile trigger when exiting the Dormant state.
	_cleanup_tile_trigger()

func _register_tile_trigger() -> void:
	if not actor or not actor._arena_grid:
		return
	
	_tile_signal_component = actor._arena_grid.tile_signals as TileSignalComponent
	if _tile_signal_component == null:
		push_warning("Dormant: No TileSignalComponent found, using fallback polling")
		return
	
	# Get the actor's current tile for trigger center.
	var current_tile: Object = null
	if actor.tile_interaction_component:
		current_tile = actor.tile_interaction_component.get_ground_tile()
	elif actor.has_method("get_ground_tile"):
		current_tile = actor.call("get_ground_tile")
	
	if current_tile == null:
		push_warning("Dormant: Could not get actor's current tile")
		return
	
	# Create callback to handle player entering range.
	_callback_instance = _on_trigger_activated.bind()
	
	var metadata: Dictionary = {"previous_state": _previous_state}
	_trigger = _tile_signal_component.register_trigger(current_tile, dormant_radius_tiles, _callback_instance, metadata)

func _cleanup_tile_trigger() -> void:
	if _tile_signal_component != null and not _trigger.is_empty():
		_tile_signal_component.remove_trigger(_trigger)
	_trigger = {}
	_tile_signal_component = null
	_callback_instance = Callable()

func _on_trigger_activated(entered_actor: Node3D, metadata: Dictionary) -> void:
	# Only respond when the player (is_playable) enters our range.
	# Ignore activations from other NPCs since they're already in dormant states.
	if not is_instance_valid(entered_actor):
		return
	
	if entered_actor.get("is_playable") == true:
		var target_state: String = metadata.get("previous_state", "idle")
		state_machine.change_state(target_state)

## Fallback: Check if player is within range using hex-aware distance calculation.
## Used when TileSignalComponent is not available.
func _is_player_in_range() -> bool:
	var player_node: Node3D = _get_player_node()
	if player_node == null or not is_instance_valid(player_node):
		return false
	
	if not actor._arena_grid:
		return false
	
	var player_tile: Object = null
	if player_node.tile_interaction_component:
		player_tile = player_node.tile_interaction_component.get_ground_tile()
	
	var actor_tile: Object = null
	if actor.tile_interaction_component:
		actor_tile = actor.tile_interaction_component.get_ground_tile()
	
	if player_tile == null or actor_tile == null:
		return false
	
	var hex_distance: int = _get_hex_distance(player_tile.axial_coords, actor_tile.axial_coords)
	return hex_distance <= dormant_radius_tiles

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

func _get_hex_distance(a: Vector2i, b: Vector2i) -> int:
	return (abs(a.x - b.x) + abs(a.x + a.y - b.x - b.y) + abs(a.y - b.y)) / 2

func get_debug_name() -> String:
	return "Dormant"
