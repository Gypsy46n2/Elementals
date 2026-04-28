## GridGenerator handles the creation and initial layout of the hexagonal grid,
## including terrain generation, height mapping, and farmstead planning.
class_name GridGenerator
extends Node

const SQRT3: float = sqrt(3.0)

var arena: ArenaGrid

# Planning data
var farmstead_interior_tiles: Array[HexTileData] = []
var farmstead_perimeter_tiles: Array[HexTileData] = []
var house_tile: HexTileData = null

var _neighbor_cache: Dictionary = {}
var _tile_lookup: Dictionary = {}

func setup(p_arena: ArenaGrid) -> void:
	arena = p_arena

## Generates the hex grid, assigns initial states, and applies noise-based height.
func initialize_grid() -> void:
	var h = _grid_height_clamped()
	var w = _grid_width_clamped()
	var total_h = h + 2
	var total_w = w + 2
	var total_tiles = total_h * total_w
	
	var radius = min(w, h) / 2
	var center_x = total_w / 2
	var center_y = total_h / 2
	var center_axial = offset_to_axial(center_x, center_y)
	
	arena.renderer.setup(total_tiles)
	
	arena.tile_data_grid.clear()
	arena.tile_counts.clear()
	_neighbor_cache.clear()
	_tile_lookup.clear()
	for state in TileConstants.State.values():
		arena.tile_counts[state] = 0
	
	if not arena.noise:
		arena.noise = FastNoiseLite.new()
		var gs = get_node_or_null("/root/GameSettings")
		if gs:
			arena.noise.seed = gs.noise_seed
			arena.noise.frequency = gs.noise_frequency
			arena.height_step = gs.height_step
		else:
			arena.noise.seed = randi()
			arena.noise.frequency = 0.05
		arena.noise.noise_type = FastNoiseLite.TYPE_PERLIN
	
	for y in total_h:
		for x in total_w:
			var axial = offset_to_axial(x, y)
			var dist = axial_distance(center_axial, axial)
			
			if dist > radius:
				continue
			
			var pos_2d = calculate_hex_position(x, y)
			var pos = Vector3(pos_2d.x, 0.0, pos_2d.y)
			
			var state: int
			if dist == radius:
				state = TileConstants.State.STONE
			elif x > total_w / 2 and y > total_h / 2:
				state = TileConstants.State.DIRT
			else:
				state = TileConstants.State.GRASS
			
			var h_val = 0
			if arena.noise:
				var nv = arena.noise.get_noise_2d(float(x), float(y))
				h_val = int(clamp(floor((nv + 1.0) * 2.0), 0, 3))
			
			var tile = HexTileData.new(state, pos, axial, Vector2i(x, y), h_val)
			arena.tile_data_grid.append(tile)
			_tile_lookup[Vector2i(x, y)] = tile
			arena.tile_counts[state] += 1
			
			arena.renderer.add_tile(tile)
			if state == TileConstants.State.FIRE:
				arena.renderer.update_fire_effect(tile, true)
	
	plan_farmstead()
	spawn_initial_trees()
	
	for tile in arena.tile_data_grid:
		if tile.current_state == TileConstants.State.STONE:
			var max_neighbor_h: float = -10.0
			for n in get_neighbors(tile):
				if n.current_state != TileConstants.State.STONE:
					max_neighbor_h = max(max_neighbor_h, float(n.height_level) * arena.height_step)
			
			if max_neighbor_h > -10.0:
				tile.set_meta("stone_height", max_neighbor_h + 2.0)
			else:
				tile.set_meta("stone_height", (float(tile.height_level) * arena.height_step) + 2.0)
			
			arena.renderer.remove_tile(tile)
			arena.renderer.add_tile(tile)
	
	for tile in arena.tile_data_grid:
		arena.tile_system.check_activeness(tile)
		
	arena.tile_counts_changed.emit(arena.tile_counts)

## Instantiates farmstead features like the house and fences.
func setup_farmstead() -> void:
	if not house_tile:
		return
	
	var house = arena.house_feature_scene.instantiate()
	house.transform.origin = house_tile.position + Vector3(0, get_tile_surface_y(house_tile), 0)
	arena.add_child(house)
	house_tile.feature = house
	if house.has_method("set_tile"):
		house.set_tile(house_tile)
	
	# Spawn Selected Player Actor in the center of the yard
	if arena.actor_spawner:
		var interior_center = farmstead_interior_tiles[0] if not farmstead_interior_tiles.is_empty() else house_tile
		var player = arena.actor_spawner.spawn_selected_actor_at_tile(interior_center)
		if player:
			if player.has_node("ActorController"):
				var controller = player.get_node("ActorController")
				if "farm_center" in controller:
					controller.farm_center = interior_center.position
	
	# Spawn Fences on the rest of the perimeter
	var fences: Array[Node3D] = []
	for n in farmstead_perimeter_tiles:
		if n != house_tile and not n.feature:
			var fence = arena.fence_feature_scene.instantiate()
			fence.transform.origin = n.position + Vector3(0, get_tile_surface_y(n), 0)
			arena.add_child(fence)
			n.feature = fence
			if fence.has_method("set_tile"):
				fence.set_tile(n)
			fences.append(fence)
	
	# Update fence connections visually
	for f in fences:
		if f.has_method("update_connections"):
			f.update_connections(arena)
	
	# Spawn a scarecrow dummy just outside the yard
	if arena.actor_spawner:
		arena.actor_spawner.spawn_scarecrow()

## Determines the layout of the farmstead, including interior and perimeter tiles.
func plan_farmstead() -> void:
	var total_h = _grid_height_clamped() + 2
	var total_w = _grid_width_clamped() + 2
	var x = total_w / 2
	var y = total_h / 2
	var center_tile = get_tile_at_grid_coords(x, y)
	if not center_tile: return
	
	farmstead_interior_tiles = []
	var queue: Array[HexTileData] = [center_tile]
	farmstead_interior_tiles.append(center_tile)
	
	var i = 0
	while farmstead_interior_tiles.size() < 10 and i < farmstead_interior_tiles.size():
		var current = farmstead_interior_tiles[i]
		i += 1
		var neighbors = get_neighbors(current)
		neighbors.shuffle() # Randomize the blob shape slightly
		for n in neighbors:
			if n not in farmstead_interior_tiles and n.current_state != TileConstants.State.STONE:
				farmstead_interior_tiles.append(n)
				if farmstead_interior_tiles.size() >= 10:
					break
	
	farmstead_perimeter_tiles = []
	for tile in farmstead_interior_tiles:
		for n in get_neighbors(tile):
			if n not in farmstead_interior_tiles and n not in farmstead_perimeter_tiles:
				if n.current_state != TileConstants.State.STONE:
					farmstead_perimeter_tiles.append(n)
	
	if not farmstead_perimeter_tiles.is_empty():
		# Randomly pick a perimeter tile for the house
		var house_idx = randi() % farmstead_perimeter_tiles.size()
		house_tile = farmstead_perimeter_tiles[house_idx]

## Spawns trees across the grid, avoiding the farmstead area.
func spawn_initial_trees() -> void:
	for tile in arena.tile_data_grid:
		if tile.current_state == TileConstants.State.GRASS:
			if tile in farmstead_interior_tiles or tile in farmstead_perimeter_tiles:
				continue
			if randf() < 0.05:
				spawn_tree(tile)

## Instantiates a tree at the given tile's position.
func spawn_tree(tile: HexTileData) -> void:
	var tree = arena.tree_feature_scene.instantiate()
	tree.transform.origin = tile.position + Vector3(0, get_tile_surface_y(tile), 0)
	arena.add_child(tree)
	tile.feature = tree
	if tree.has_method("set_tile"):
		tree.set_tile(tile)

## Calculates the world position of a hex cell based on its grid coordinates.
func calculate_hex_position(column: int, row: int) -> Vector2:
	var offset = float(column % 2) * 0.5
	var x_position = (1.5 * float(column)) * arena.hex_size
	var z_position = (SQRT3 * (float(row) + offset)) * arena.hex_size
	return Vector2(x_position, z_position)

## Converts offset grid coordinates to axial coordinates.
func offset_to_axial(col: int, row: int) -> Vector2i:
	var q = col
	var r = row - (col - (col & 1)) / 2
	return Vector2i(q, r)

## Calculates the axial distance between two axial coordinates.
func axial_distance(a: Vector2i, b: Vector2i) -> int:
	var dq = a.x - b.x
	var dr = a.y - b.y
	var ds = (-a.x - a.y) - (-b.x - b.y)
	return (abs(dq) + abs(dr) + abs(ds)) / 2

## Calculates the vertical position of a tile's surface.
func get_tile_surface_y(tile: HexTileData) -> float:
	if tile.current_state == TileConstants.State.STONE:
		if tile.has_meta("stone_height"):
			return tile.get_meta("stone_height")
		return (float(tile.height_level) * arena.height_step) + 2.0
	return float(tile.height_level) * arena.height_step

## Returns an array of neighboring tiles for the given tile.
## This is a hotspot during generation and game logic, so we cache results
## to avoid redoing the 6 directional lookups every time.
func get_neighbors(tile: HexTileData) -> Array[HexTileData]:
	# Cache hit: we already computed this tile's neighbors on a previous call.
	# We skip the expensive grid math and return immediately.
	if _neighbor_cache.has(tile):
		# Return a shallow copy instead of the cached array itself.
		# Some callers (e.g., farmstead planning, fire spreading) shuffle or
		# otherwise mutate the returned array, so a copy keeps the cache safe.
		var cached: Array = _neighbor_cache[tile]
		var result: Array[HexTileData] = []
		result.assign(cached)
		return result
	
	# Cache miss: compute neighbors by walking the 6 hex directions.
	# For each direction we convert grid coords, validate bounds, and index
	# into the flat tile_data_grid. This is skipped entirely on future calls.
	var result: Array[HexTileData] = []
	var offsets = TileConstants.get_neighbor_offsets(tile.grid_coords.x)
	for offset in offsets:
		var nx = tile.grid_coords.x + offset.x
		var ny = tile.grid_coords.y + offset.y
		var n = get_tile_at_grid_coords(nx, ny)
		if n: result.append(n)
	
	# Store the result so the next call for this tile is instant.
	_neighbor_cache[tile] = result
	return result

## Checks if any neighboring tiles are grass.
func has_adjacent_grass(tile: HexTileData) -> bool:
	for n in get_neighbors(tile):
		if n.tile_type == TileConstants.Type.GRASS: return true
	return false

## Returns a neighboring dirt tile, if any.
func get_adjacent_dirt(tile: HexTileData) -> HexTileData:
	for n in get_neighbors(tile):
		if n.tile_type == TileConstants.Type.DIRT: return n
	return null

## Retrieves tile data at the specified grid coordinates.
func get_tile_at_grid_coords(x: int, y: int) -> HexTileData:
	return _tile_lookup.get(Vector2i(x, y), null)

func _grid_width_clamped() -> int: return max(1, arena.grid_width)
func _grid_height_clamped() -> int: return max(1, arena.grid_height)
