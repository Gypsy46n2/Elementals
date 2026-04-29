class_name ActorTileInteractionComponent
extends Node

var _ground_tile: HexTileData
var _actor: Node3D

func setup(actor: Node3D) -> void:
	_actor = actor

signal tile_changed(new_tile: HexTileData)

func _physics_process(_delta: float) -> void:
	if _actor and _actor.has_method("is_on_floor") and _actor.is_on_floor():
		var old_tile: HexTileData = _ground_tile
		update_tile_below()
		if _ground_tile != old_tile:
			tile_changed.emit(_ground_tile)
			apply_ground_effects()

func update_tile_below() -> void:
	if _actor and _actor.get("_arena_grid"):
		_ground_tile = _actor.get("_arena_grid").get_tile_data_at_world_position(_actor.global_transform.origin)
	else:
		_ground_tile = null

func apply_ground_effects() -> void:
	if _ground_tile:
		if _check_tile_damage(_ground_tile):
			return
		_handle_tile_interaction(_ground_tile)

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
