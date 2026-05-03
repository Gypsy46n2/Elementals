class_name TileSignalComponent
extends Node

## Manages tile-based triggers and signals.
## Centralizes hex proximity checks, tracks actor tiles, and dispatches enter/exit events so gameplay systems can respond without duplicate distance math. 
## Listens for player movement and activates triggers when the player enters their range.

signal trigger_activated(trigger_data: Dictionary, actor: Node3D)
signal trigger_deactivated(trigger_data: Dictionary, actor: Node3D)

var arena: Node = null # ArenaGrid
var _triggers: Array[Dictionary] = []
var _actor_tiles: Dictionary = {} # actor -> Object (HexTileData)
var _tile_to_actors: Dictionary = {} # Object (HexTileData) -> Array[Node3D]

func setup(p_arena: Node) -> void:
	arena = p_arena
	_refresh_tracked_actors()
	
	var timer = Timer.new()
	timer.name = "ActorTrackingTimer"
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_refresh_tracked_actors)
	add_child(timer)

func _refresh_tracked_actors() -> void:
	if not arena: return
	for actor in arena.get("actors"):
		if is_instance_valid(actor) and not _actor_tiles.has(actor):
			_track_actor(actor)

func _get_actor_current_tile(p_actor: Node3D) -> Object:
	if p_actor.has_method("get_ground_tile"):
		return p_actor.call("get_ground_tile")
	elif p_actor.get("tile_interaction_component"):
		return p_actor.tile_interaction_component.get_ground_tile()
	return null

func register_actor(actor: Node3D) -> void:
	if is_instance_valid(actor):
		_track_actor(actor)

func _track_actor(actor: Node3D) -> void:
	if actor.has_signal("tile_changed"):
		if not actor.tile_changed.is_connected(_on_actor_tile_changed.bind(actor)):
			actor.tile_changed.connect(_on_actor_tile_changed.bind(actor))
		
		var current_tile = _get_actor_current_tile(actor)
		if current_tile:
			_update_actor_tile_mapping(actor, current_tile)

func _update_actor_tile_mapping(actor: Node3D, new_tile: Object) -> void:
	var old_tile = _actor_tiles.get(actor)
	if old_tile:
		if _tile_to_actors.has(old_tile):
			_tile_to_actors[old_tile].erase(actor)
	
	_actor_tiles[actor] = new_tile
	if not _tile_to_actors.has(new_tile):
		_tile_to_actors[new_tile] = []
	_tile_to_actors[new_tile].append(actor)

func register_trigger(center_tile: Object, radius: int, callback: Callable, metadata: Dictionary = {}) -> Dictionary:
	if center_tile == null:
		return {}
		
	var trigger: Dictionary = {
		"center": center_tile,
		"radius": radius,
		"callback": callback,
		"metadata": metadata,
		"active_actors": []
	}
	
	_triggers.append(trigger)
	
	for actor in _actor_tiles:
		if is_instance_valid(actor):
			var tile = _actor_tiles[actor]
			var distance = _get_hex_distance(tile.axial_coords, center_tile.axial_coords)
			if distance <= radius:
				_activate_trigger_for_actor(trigger, actor)
				
	return trigger

func remove_trigger(trigger: Dictionary) -> void:
	# Find and remove by reference identity, not value equality.
	# Array.erase() uses value equality which fails for dictionaries with nested content.
	for i in range(_triggers.size() - 1, -1, -1):
		if _triggers[i] == trigger:
			_triggers.remove_at(i)
			return

func _on_actor_tile_changed(new_tile: Object, actor: Node3D) -> void:
	if not is_instance_valid(actor) or new_tile == null:
		return
		
	_update_actor_tile_mapping(actor, new_tile)
	
	for trigger in _triggers:
		var distance: int = _get_hex_distance(new_tile.axial_coords, trigger["center"].axial_coords)
		var is_inside = distance <= trigger["radius"]
		var was_inside = actor in trigger["active_actors"]
		
		if is_inside and not was_inside:
			_activate_trigger_for_actor(trigger, actor)
		elif not is_inside and was_inside:
			_deactivate_trigger_for_actor(trigger, actor)

func _activate_trigger_for_actor(trigger: Dictionary, actor: Node3D) -> void:
	if not actor in trigger["active_actors"]:
		trigger["active_actors"].append(actor)
		if trigger["callback"].is_valid():
			trigger["callback"].call(actor, trigger["metadata"])
		trigger_activated.emit(trigger, actor)

func _deactivate_trigger_for_actor(trigger: Dictionary, actor: Node3D) -> void:
	if actor in trigger["active_actors"]:
		trigger["active_actors"].erase(actor)
		trigger_deactivated.emit(trigger, actor)

func _get_hex_distance(a: Vector2i, b: Vector2i) -> int:
	return (abs(a.x - b.x) + abs(a.x + a.y - b.x - b.y) + abs(a.y - b.y)) / 2

func update_trigger_center(trigger: Dictionary, new_tile: Object) -> void:
	if trigger.get("center") == new_tile:
		return
	trigger["center"] = new_tile
	
	for tracked_actor in _actor_tiles.keys():
		if not is_instance_valid(tracked_actor):
			continue
		var tile = _actor_tiles[tracked_actor]
		if tile == null:
			continue
		var distance: int = _get_hex_distance(tile.axial_coords, new_tile.axial_coords)
		var is_inside: bool = distance <= trigger["radius"]
		var was_inside: bool = tracked_actor in trigger["active_actors"]
		
		if is_inside and not was_inside:
			_activate_trigger_for_actor(trigger, tracked_actor)
		elif not is_inside and was_inside:
			_deactivate_trigger_for_actor(trigger, tracked_actor)
