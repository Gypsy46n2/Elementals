class_name ActorTileNavigationComponent
extends Node

## Component responsible for tile-based navigation queries.
## Provides helpers to find traversable neighboring tiles for an actor.

## Reference to the actor node this component navigates for.
@export var actor: Node3D

func _ready() -> void:
	if not actor and get_parent() is Actor:
		actor = get_parent()

## Helper to find neighbors that the NPC can actually walk onto.
func get_traversable_neighbors(tile: HexTileData, max_step_up: float = 3.0) -> Array[HexTileData]:
	if not tile or not actor or not actor._arena_grid:
		return []
	var ground_y: float = actor._arena_grid._get_tile_surface_y(tile)
	return actor._arena_grid._get_neighbors(tile).filter(func(t: HexTileData) -> bool:
		if t == null or t.current_state == TileConstants.State.STONE:
			return false
		if t.feature:
			if t.feature is TreeFeature:
				if t.feature.current_state in [TreeFeature.State.TREE, TreeFeature.State.STUMP, TreeFeature.State.BURNT_STUMP]:
					return false
			elif t.feature is FenceFeature:
				return false
		var ty: float = actor._arena_grid._get_tile_surface_y(t)
		if ty > ground_y + max_step_up:
			return false
		return true
	)
