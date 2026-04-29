class_name TileSignalComponent
extends Node

## Manages tile-based triggers and signals. 
## Listens for player movement and activates triggers when the player enters their range.
## © 2026 Micheal Chapin

signal trigger_activated(trigger_data: Dictionary)
signal trigger_deactivated(trigger_data: Dictionary)

var arena: Node = null # ArenaGrid
var _triggers: Array[Dictionary] = []
var _connected_actor: Node3D = null
var auto_connect_player: bool = true

func setup(p_arena: Node) -> void:
	arena = p_arena
	if auto_connect_player:
		_check_player_connection()
		
		# Periodically check for player connection in case of actor swaps or deferred spawns
		var timer = Timer.new()
		timer.name = "PlayerConnectionTimer"
		timer.wait_time = 1.0
		timer.autostart = true
		timer.timeout.connect(_check_player_connection)
		add_child(timer)

func set_target_actor(p_actor: Node3D) -> void:
	auto_connect_player = false
	if _connected_actor == p_actor:
		return
		
	if _connected_actor != null:
		if _connected_actor.has_signal("tile_changed") and _connected_actor.tile_changed.is_connected(_on_actor_tile_changed):
			_connected_actor.tile_changed.disconnect(_on_actor_tile_changed)
	
	_connected_actor = p_actor
	if _connected_actor != null and _connected_actor.has_signal("tile_changed"):
		_connected_actor.tile_changed.connect(_on_actor_tile_changed)
		
		# Immediate check for current tile
		var actor_tile: HexTileData = _get_actor_current_tile(_connected_actor)
		if actor_tile:
			_on_actor_tile_changed(actor_tile)

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
	if not auto_connect_player:
		return
		
	var player_node: Node3D = _get_player_node()
	if player_node != null and player_node != _connected_actor:
		set_target_actor(player_node)

func _get_actor_current_tile(p_actor: Node3D) -> HexTileData:
	if p_actor.has_method("get_ground_tile"):
		return p_actor.call("get_ground_tile")
	elif p_actor.get("tile_interaction_component"):
		return p_actor.tile_interaction_component.get_ground_tile()
	return null

func _on_actor_tile_changed(new_tile: HexTileData) -> void:
	if new_tile == null:
		return
	
	# Activate any triggers attached to this specific tile
	if new_tile.has_meta("triggers"):
		var tile_triggers: Array = new_tile.get_meta("triggers")
		for trigger in tile_triggers:
			if trigger in _triggers and not trigger["activated"]:
				_activate_trigger(trigger)
	
	# Check proximity-based triggers
	for trigger in _triggers:
		var distance: int = _get_hex_distance(new_tile.axial_coords, trigger["center"].axial_coords)
		if distance <= trigger["radius"]:
			if not trigger["activated"]:
				_activate_trigger(trigger)
		elif trigger["activated"]:
			_deactivate_trigger(trigger)

func _activate_trigger(trigger: Dictionary) -> void:
	trigger["activated"] = true
	if trigger["callback"].is_valid():
		trigger["callback"].call(trigger["metadata"])
	trigger_activated.emit(trigger)

func _deactivate_trigger(trigger: Dictionary) -> void:
	trigger["activated"] = false
	trigger_deactivated.emit(trigger)

func _get_hex_distance(a: Vector2i, b: Vector2i) -> int:
	return (abs(a.x - b.x) + abs(a.x + a.y - b.x - b.y) + abs(a.y - b.y)) / 2

func _get_player_node() -> Node3D:
	if arena == null:
		return null
	var actor_value: Variant = arena.get("current_controlled_actor")
	if actor_value != null and is_instance_valid(actor_value) and actor_value is Node3D:
		return actor_value as Node3D
	return null
