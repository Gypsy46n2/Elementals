class_name TileSystem
extends Node

var active_registry: Dictionary = {} # axial_coords -> HexTileData
var arena: ArenaGrid

func _ready() -> void:
	if not arena:
		arena = get_parent() as ArenaGrid

func process_tiles(delta: float) -> void:
	# Use a list to avoid modification issues during iteration
	var active_tiles = active_registry.values()
	for tile in active_tiles:
		match tile.tile_type:
			TileConstants.Type.FIRE:
				tile.fire_duration += delta
				if tile.fire_duration >= 4.0 and not tile.fire_spread_triggered:
					tile.fire_spread_triggered = true
					arena.tile_interaction.spread_fire(tile)
				if tile.fire_duration >= 5.0:
					tile.fire_duration = 0.0
					tile.fire_spread_triggered = false
					arena.set_tile_state(tile, TileConstants.State.DIRT)
					
			TileConstants.Type.MUD:
				if arena._has_adjacent_grass(tile):
					tile.mud_duration += delta
					if tile.mud_duration >= 5.0:
						arena.set_tile_state(tile, TileConstants.State.GRASS)
						tile.mud_duration = 0.0
				else:
					tile.mud_duration = 0.0
					check_activeness(tile)
					
			TileConstants.Type.PUDDLE:
				var dirt_neighbor = arena._get_adjacent_dirt(tile)
				if dirt_neighbor:
					tile.puddle_duration += delta
					if tile.puddle_duration >= 5.0:
						arena.set_tile_state(dirt_neighbor, TileConstants.State.MUD)
						tile.puddle_duration = 0.0
				else:
					tile.puddle_duration = 0.0
					check_activeness(tile)

func check_activeness(tile: HexTileData) -> void:
	var should_be_active = false
	match tile.tile_type:
		TileConstants.Type.FIRE:
			should_be_active = true
		TileConstants.Type.MUD:
			if arena._has_adjacent_grass(tile):
				should_be_active = true
		TileConstants.Type.PUDDLE:
			if arena._get_adjacent_dirt(tile):
				should_be_active = true
	
	if should_be_active:
		active_registry[tile.axial_coords] = tile
	else:
		active_registry.erase(tile.axial_coords)
