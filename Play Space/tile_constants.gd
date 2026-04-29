class_name TileConstants
extends Object

enum State { GRASS, DIRT, MUD, FIRE, PUDDLE, STONE }
enum Type { GRASS, DIRT, FIRE, STONE, MUD, PUDDLE }

const COLORS = {
	State.GRASS: Color.WHITE,
	State.DIRT: Color.WHITE,
	State.MUD: Color.WHITE,
	State.FIRE: Color(1.0, 0.4, 0.0),
	State.PUDDLE: Color.WHITE,
	State.STONE: Color(0.35, 0.35, 0.4), # Slate grey
}

const TEXTURES = {
	State.GRASS: preload("res://assets/generated/grass_hex_tile_organic_frame_0_1777431864.png"),
	State.DIRT: preload("res://assets/generated/dirt_hex_tile_organic_frame_0_1777434292.png"),
	State.MUD: preload("res://assets/generated/mud_hex_tile_organic_frame_0_1777434292.png"),
	State.PUDDLE: preload("res://assets/generated/water_hex_tile_1774844916.png"),
	State.STONE: null,
	State.FIRE: preload("res://assets/generated/dirt_hex_tile_organic_frame_0_1777434292.png"),
}

const CLIFF_TEXTURES = {
	State.GRASS: preload("res://assets/generated/natural_grass_cliff_face_frame_0_1776195222.png"),
	State.DIRT: preload("res://assets/generated/dirt_cliff_face_frame_0_1776194866.png"),
	State.MUD: preload("res://assets/generated/mud_cliff_face_frame_0_1776194867.png"),
	State.PUDDLE: preload("res://assets/generated/waterfall_flow_side_frame_0_1776195242.png"),
	State.STONE: null,
	State.FIRE: preload("res://assets/generated/lava_cliff_face_frame_0_1776194867.png"),
}

const CLIFF_OVERLAYS = {
	State.PUDDLE: preload("res://assets/generated/waterfall_mist_overlay_frame_0_1776195259.png"),
	State.FIRE: preload("res://assets/generated/lava_smoke_overlay_frame_0_1776195282.png"),
}


# Flat-topped (Odd-Q) hex directions
static func get_neighbor_offsets(col: int) -> Array[Vector2i]:
	if col % 2 == 0:
		# Even Column
		return [
			Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1),
			Vector2i(-1, -1), Vector2i(-1, 0), Vector2i(0, 1)
		]
	else:
		# Odd Column
		return [
			Vector2i(1, 1), Vector2i(1, 0), Vector2i(0, -1),
			Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)
		]
