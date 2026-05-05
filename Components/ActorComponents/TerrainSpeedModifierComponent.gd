class_name TerrainSpeedModifierComponent
extends Node

## Component that modifies an actor's speed based on the terrain type they are standing on.

var _actor: Node
var _tile_multipliers: Dictionary = {} # TileConstants.Type -> float
var _current_multiplier: float = 1.0

func setup(p_actor: Node) -> void:
	_actor = p_actor
	var tic = _actor.get("tile_interaction_component")
	if tic:
		if not tic.tile_changed.is_connected(_on_tile_changed):
			tic.tile_changed.connect(_on_tile_changed)
		
		# Initialize with current tile if it exists
		var current_tile: HexTileData = tic.get_ground_tile()
		if current_tile:
			_update_multiplier(current_tile)

func configure_multipliers(multipliers: Dictionary) -> void:
	_tile_multipliers = multipliers
	# Force update based on current tile
	var tic = _actor.get("tile_interaction_component")
	var current_tile: HexTileData = tic.get_ground_tile() if tic else null
	if current_tile:
		_update_multiplier(current_tile)

func set_multiplier(tile_type: int, multiplier: float) -> void:
	_tile_multipliers[tile_type] = multiplier
	# If we are currently on this tile type, update the multiplier
	var tic = _actor.get("tile_interaction_component")
	var current_tile: HexTileData = tic.get_ground_tile() if tic else null
	if current_tile and current_tile.tile_type == tile_type:
		_update_multiplier(current_tile)

func get_speed_multiplier() -> float:
	return _current_multiplier

func _on_tile_changed(new_tile: HexTileData) -> void:
	_update_multiplier(new_tile)

func _update_multiplier(tile: HexTileData) -> void:
	if not tile:
		_current_multiplier = 1.0
		return
	
	if _tile_multipliers.has(tile.tile_type):
		_current_multiplier = _tile_multipliers[tile.tile_type]
	else:
		_current_multiplier = 1.0
