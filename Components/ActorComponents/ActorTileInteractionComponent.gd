class_name ActorTileInteractionComponent
extends Node

var _ground_tile: HexTileData
var _actor: Node3D
var _movement_component: MovementComponent
var _pending_tile: HexTileData  # Cached tile from signal

func setup(actor: Node3D) -> void:
	_actor = actor
	_connect_to_movement_component()

func _connect_to_movement_component() -> void:
	if not _actor:
		return
	
	# Look for MovementComponent as a direct child of the actor
	var movement_node: MovementComponent = _actor.get_node_or_null("MovementComponent")
	if not movement_node:
		# Search all children if name is not exact
		for child in _actor.get_children():
			if child is MovementComponent:
				movement_node = child
				break
	
	if movement_node:
		_movement_component = movement_node
		if not _movement_component.tile_changed.is_connected(_on_tile_changed):
			_movement_component.tile_changed.connect(_on_tile_changed)
		
		# Get initial tile
		_pending_tile = _movement_component.get_current_tile()
		_ground_tile = _pending_tile
		if _ground_tile:
			# If we already have a tile, apply effects and notify others immediately
			apply_ground_effects(_ground_tile)
			tile_changed.emit(_ground_tile)

signal tile_changed(new_tile: HexTileData)

func _on_tile_changed(new_tile: HexTileData, previous_tile: HexTileData) -> void:
	if new_tile != _ground_tile:
		tile_changed.emit(new_tile)
	apply_ground_effects(new_tile)

func apply_ground_effects(tile: HexTileData) -> void:
	_ground_tile = tile
	if not tile:
		return
		
	if _check_tile_damage(tile):
		return
	_handle_tile_interaction(tile)

func _handle_tile_interaction(tile: HexTileData) -> void:
	var arena_grid = _actor.get("_arena_grid")
	if not arena_grid:
		return
		
	var element_type = _actor.get("element_type")
	if element_type == "fire":
		if arena_grid.apply_element_to_tile(tile, "fire"):
			if tile.current_state == TileConstants.State.FIRE:
				_actor.current_mana = min(_actor.current_mana + 1.0, _actor.max_mana)
	elif element_type == "water":
		if arena_grid.apply_element_to_tile(tile, "water"):
			if tile.current_state == TileConstants.State.PUDDLE:
				_actor.current_mana = min(_actor.current_mana + 1.0, _actor.max_mana)

func _check_tile_damage(tile: HexTileData) -> bool:
	var arena_grid = _actor.get("_arena_grid")
	if not arena_grid:
		return false
		
	var element_type = _actor.get("element_type")
	if element_type == "fire":
		if tile.current_state == TileConstants.State.MUD:
			_actor.take_damage(1, "normal", Vector3.UP)
			arena_grid.apply_element_to_tile(tile, "fire")
			return true
		elif tile.current_state == TileConstants.State.PUDDLE:
			_actor.take_damage(2, "normal", Vector3.UP)
			arena_grid.apply_element_to_tile(tile, "fire")
			return true
	elif element_type == "water":
		if tile.current_state == TileConstants.State.FIRE:
			_actor.take_damage(1, "normal", Vector3.UP)
			arena_grid.apply_element_to_tile(tile, "water")
			return true
	return false

func get_ground_tile() -> HexTileData:
	return _ground_tile

## Manual update no longer needed - tile updates via MovementComponent.tile_changed signal
func update_tile_below() -> void:
	pass  # Tile is now updated via signal from MovementComponent
