class_name ActorTileInteractionComponent
extends Node

var _ground_tile: HexTileData
var _actor: Actor

func setup(actor: Actor) -> void:
	_actor = actor

func update_tile_below() -> void:
	if _actor and _actor._arena_grid:
		_ground_tile = _actor._arena_grid.get_tile_data_at_world_position(_actor.global_transform.origin)
	else:
		_ground_tile = null

func apply_ground_effects() -> void:
	if _ground_tile:
		if _check_tile_damage(_ground_tile):
			return
		_do_tile_effect(_ground_tile)

func _check_tile_damage(tile: HexTileData) -> bool:
	if not _actor._arena_grid:
		return false
		
	if _actor.element_type == "fire":
		if tile.current_state == TileConstants.State.MUD:
			_actor.take_damage(1, "normal", Vector3.UP)
			_actor._arena_grid.apply_element_to_tile(tile, "fire")
			return true
		elif tile.current_state == TileConstants.State.PUDDLE:
			_actor.take_damage(2, "normal", Vector3.UP)
			_actor._arena_grid.apply_element_to_tile(tile, "fire")
			return true
	elif _actor.element_type == "water":
		if tile.current_state == TileConstants.State.FIRE:
			_actor.take_damage(1, "normal", Vector3.UP)
			_actor._arena_grid.apply_element_to_tile(tile, "water")
			return true
	return false

func _do_tile_effect(tile: HexTileData) -> void:
	_actor._do_tile_effect(tile)

func get_ground_tile() -> HexTileData:
	return _ground_tile
