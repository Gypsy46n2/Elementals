class_name TileSignalComponent
extends Node

## Manages tile-based triggers and signals. 
## Listens for player movement and activates triggers when the player enters their range.
## © 2026 Micheal Chapin

signal trigger_activated(trigger_data: Dictionary)

var arena: Node = null # ArenaGrid
var _triggers: Array[Dictionary] = []
var _connected_actor: Node3D = null

func setup(p_arena: Node) -> void:
	arena = p_arena
	_check_player_connection()
	
	# Periodically check for player connection in case of actor swaps or deferred spawns
	var timer = Timer.new()
	timer.name = "PlayerConnectionTimer"
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_check_player_connection)
	add_child(timer)

func register_trigger(center_tile: HexTileData, radius: int, callback: Callable, metadata: Dictionary = {}) -> void:
	if center_tile == null:
		return
		
	# Attach trigger to the tile data for direct access if needed
	if not center_tile.has_meta("triggers"):
		center_tile.set_meta("triggers", [])
	
	var trigger: Dictionary = {
		"center": center_tile,
		"radius": radius,
		"callback": callback,
		"metadata": metadata,
		"activated": false
	}
	
	var tile_triggers: Array = center_tile.get_meta("triggers")
	tile_triggers.append(trigger)
	
	_triggers.append(trigger)

func _check_player_connection() -> void:
	var player_node: Node3D = _get_player_node()
	if player_node != null and player_node != _connected_actor:
		if _connected_actor != null:
			if _connected_actor.has_signal("tile_changed") and _connected_actor.tile_changed.is_connected(_on_player_tile_changed):
				_connected_actor.tile_changed.disconnect(_on_player_tile_changed)
		
		if player_node.has_signal("tile_changed"):
			player_node.tile_changed.connect(_on_player_tile_changed)
			_connected_actor = player_node
			# Immediate check for current tile
			var player_tile: HexTileData = null
			if player_node.has_method("get_ground_tile"):
				player_tile = player_node.call("get_ground_tile")
			elif player_node.get("tile_interaction_component"):
				player_tile = player_node.tile_interaction_component.get_ground_tile()
			
			if player_tile:
				_on_player_tile_changed(player_tile)

func _on_player_tile_changed(new_tile: HexTileData) -> void:
	if new_tile == null:
		return
	
	# Activate any triggers attached to this specific tile
	if new_tile.has_meta("triggers"):
		var tile_triggers: Array = new_tile.get_meta("triggers")
		for trigger in tile_triggers:
			if not trigger.activated:
				_activate_trigger(trigger)
	
	# Check proximity-based triggers
	for trigger in _triggers:
		if trigger.activated:
			continue
		
		var distance: int = _get_hex_distance(new_tile.axial_coords, trigger.center.axial_coords)
		if distance <= trigger.radius:
			_activate_trigger(trigger)

func _activate_trigger(trigger: Dictionary) -> void:
	trigger.activated = true
	if trigger.callback.is_valid():
		trigger.callback.call(trigger.metadata)
	trigger_activated.emit(trigger)

func _get_hex_distance(a: Vector2i, b: Vector2i) -> int:
	return (abs(a.x - b.x) + abs(a.x + a.y - b.x - b.y) + abs(a.y - b.y)) / 2

func _get_player_node() -> Node3D:
	if arena == null:
		return null
	var actor_value: Variant = arena.get("current_controlled_actor")
	if actor_value != null and is_instance_valid(actor_value) and actor_value is Node3D:
		return actor_value as Node3D
	return null
