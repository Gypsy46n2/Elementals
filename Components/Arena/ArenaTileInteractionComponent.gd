class_name ArenaTileInteractionComponent
extends Node

var arena: ArenaGrid

func setup(p_arena: ArenaGrid) -> void:
	arena = p_arena

## Attempts to spread fire to a random neighbor of the given tile.
func spread_fire(tile: HexTileData) -> void:
	var neighbors = arena._get_neighbors(tile)
	neighbors.shuffle()
	for n in neighbors:
		if apply_element_to_tile(n, "fire"):
			break

## Applies elemental effects (fire, water) to a tile and its features.
func apply_element_to_tile(tile: HexTileData, element: String, direction: Vector3 = Vector3.ZERO) -> bool:
	if not tile: return false
	
	var feature_handled = false
	if tile.feature:
		feature_handled = DamageComponent.apply_element(tile.feature, element, direction)
	
	match element:
		"fire":
			if tile.tile_type == TileConstants.Type.FIRE or tile.tile_type == TileConstants.Type.STONE:
				return feature_handled
			match tile.tile_type:
				TileConstants.Type.GRASS:
					arena.set_tile_state(tile, TileConstants.State.FIRE)
					tile.fire_duration = 0.0
					tile.fire_spread_triggered = false
					return true
				TileConstants.Type.MUD:
					arena.set_tile_state(tile, TileConstants.State.DIRT)
					return true
				TileConstants.Type.PUDDLE:
					arena.set_tile_state(tile, TileConstants.State.MUD)
					return true
		"water":
			if tile.tile_type == TileConstants.Type.FIRE:
				arena.set_tile_state(tile, TileConstants.State.DIRT)
				tile.fire_spread_triggered = false
				tile.fire_duration = 0.0
				return true
			match tile.tile_type:
				TileConstants.Type.DIRT:
					arena.set_tile_state(tile, TileConstants.State.MUD)
					tile.mud_duration = 0.0
					return true
				TileConstants.Type.MUD:
					arena.set_tile_state(tile, TileConstants.State.PUDDLE)
					tile.puddle_duration = 0.0
					return true
					
	return feature_handled
