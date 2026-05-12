## TreeSpawner places HarvestableTree instances on valid tiles based on biome data.
## Spawns trees in batches to avoid frame drops on world generation.
class_name TreeSpawner
extends Node

## Reference to the arena (set via setup).
var _arena: ArenaGrid = null

## All spawned tree nodes currently in the world.
var spawned_trees: Array[Node3D] = []

## Currently queued spawn tasks (each task = {tile, blueprint}).
var _spawn_queue: Array[Dictionary] = []

## How many trees to spawn per frame when batching.
var _trees_per_batch: int = 10

## Flag: true while spawn batching is active.
var _is_spawning: bool = false

## Biome data defining spawn density (defaults to single biome).
@export var biome_data: BiomeData = null

## If true, skip the farmstead interior and perimeter when spawning.
@export var avoid_farmstead: bool = true

## RNG for deterministic spawning (seeded from GameSettings if available).
var _rng: RandomNumberGenerator

func _init() -> void:
	_rng = RandomNumberGenerator.new()
	_rng.seed = randi()


## Initializes the spawner with arena reference and biome config.
func setup(p_arena: ArenaGrid, p_biome_data: BiomeData = null) -> void:
	_arena = p_arena
	if p_biome_data:
		biome_data = p_biome_data
	if not biome_data:
		biome_data = _get_or_create_default_biome()
	
	# Apply tree_seed from GameSettings if available
	var gs = get_node_or_null("/root/GameSettings")
	if gs and "tree_seed" in gs:
		_rng.seed = gs.tree_seed


## Entry point: scans the arena grid and queues tree spawns.
## Returns the total number of trees queued (not yet spawned).
func spawn_trees() -> int:
	if not _arena:
		push_warning("TreeSpawner: No arena set. Call setup() first.")
		return 0
	
	_spawn_queue.clear()
	
	var center_tile: HexTileData = _get_center_tile()
	var farmstead_interior: Array[HexTileData] = _arena.farmstead_interior_tiles
	var farmstead_perimeter: Array[HexTileData] = _arena.farmstead_perimeter_tiles
	
	var interior_set: Dictionary = {}
	var perimeter_set: Dictionary = {}
	for t in farmstead_interior:
		interior_set[t.grid_coords] = true
	for t in farmstead_perimeter:
		perimeter_set[t.grid_coords] = true
	
	for tile in _arena.tile_data_grid:
		# Only spawn on grass tiles
		if tile.current_state != TileConstants.State.GRASS:
			continue
		
		# Skip farmstead areas
		if avoid_farmstead:
			if interior_set.has(tile.grid_coords) or perimeter_set.has(tile.grid_coords):
				continue
		
		# Skip tiles with existing features
		if tile.feature != null:
			continue
		
		# Skip tiles that are too close to existing features
		if _has_adjacent_feature(tile):
			continue
		
		# Calculate distance from center
		var distance: int = _get_hex_distance(center_tile, tile)
		
		# Calculate spawn chance
		var chance: float = biome_data.get_spawn_chance(distance)
		if _rng.randf() > chance:
			continue
		
		# Get a random blueprint
		var blueprint: Resource = biome_data.get_random_blueprint()
		if not blueprint:
			continue
		
		_spawn_queue.append({"tile": tile, "blueprint": blueprint})
	
	# Start batch spawning (this uses call_deferred so it happens next frame)
	_is_spawning = true
	_process_spawn_batch()
	
	return _spawn_queue.size()


## Returns the number of trees already spawned.
func get_tree_count() -> int:
	return spawned_trees.size()


## Immediately spawns all remaining queued trees (ignores batching).
## Use for small maps or debugging.
func spawn_all_immediately() -> void:
	for task in _spawn_queue:
		_spawn_tree_now(task["tile"], task["blueprint"])
	_spawn_queue.clear()
	_is_spawning = false


## Removes all spawned trees from the world.
func clear_all_trees() -> void:
	for tree in spawned_trees:
		if is_instance_valid(tree):
			tree.get_parent().remove_child(tree)
			tree.queue_free()
	spawned_trees.clear()


## Core batch processing loop. Spawns _trees_per_batch trees per frame.
func _process_spawn_batch() -> void:
	if _spawn_queue.is_empty():
		_is_spawning = false
		return
	
	var batch_size: int = mini(_trees_per_batch, _spawn_queue.size())
	for i in batch_size:
		var task: Dictionary = _spawn_queue.pop_front()
		var tree: Node3D = _spawn_tree_now(task["tile"], task["blueprint"])
		if tree:
			spawned_trees.append(tree)
	
	if not _spawn_queue.is_empty():
		# Continue next frame
		call_deferred("_process_spawn_batch")


## Instantiates and positions a single tree on a tile.
func _spawn_tree_now(tile: HexTileData, blueprint: Resource) -> Node3D:
	if not _arena or not is_instance_valid(tile):
		return null
	
	# Load the HarvestableTree scene
	var scene_path: String = "res://src/trees/HarvestableTree.tscn"
	var packed_scene: PackedScene = load(scene_path)
	if not packed_scene:
		push_warning("TreeSpawner: Could not load HarvestableTree.tscn")
		return null
	
	var tree: Node3D = packed_scene.instantiate()
	
	# Position at tile surface
	var surface_y: float = _arena._get_tile_surface_y(tile)
	tree.transform.origin = tile.position + Vector3(0, surface_y, 0)
	
	# Initialize with blueprint
	tree.blueprint = blueprint
	
	# Initialize HP if needed (HealthComponent handles this via blueprint)
	# The tree's _setup_from_blueprint will initialize HP from blueprint on _ready()
	# Just ensure HealthComponent exists
	if not tree.has_node("HealthComponent"):
		tree._setup_health_component()
	
	# Attach to arena
	_arena.add_child(tree)
	
	# Mark tile as having a feature
	tile.feature = tree
	
	return tree


## Returns the tile closest to grid center.
func _get_center_tile() -> HexTileData:
	var w: int = _arena._grid_width_clamped()
	var h: int = _arena._grid_height_clamped()
	var cx: int = w / 2
	var cy: int = h / 2
	return _arena.get_tile_at_grid_coords(cx, cy)


## Returns true if the tile has a feature within spacing distance.
func _has_adjacent_feature(tile: HexTileData) -> bool:
	if biome_data.min_tree_spacing <= 0:
		return false
	
	var neighbors: Array[HexTileData] = _arena._get_neighbors(tile)
	for n in neighbors:
		if n.feature and n.feature is Node3D:
			return true
	
	# Check distance-2 neighbors if spacing > 1
	if biome_data.min_tree_spacing >= 2:
		var radius2_tiles: Array[HexTileData] = _arena.get_tiles_in_radius(tile, 2)
		for t in radius2_tiles:
			if t == tile:
				continue
			if t.feature and t.feature is Node3D:
				return true
	
	return false


## Returns hex axial distance between two tiles.
func _get_hex_distance(a: HexTileData, b: HexTileData) -> int:
	var dq: int = a.axial_coords.x - b.axial_coords.x
	var dr: int = a.axial_coords.y - b.axial_coords.y
	var ds: int = (-a.axial_coords.x - a.axial_coords.y) - (-b.axial_coords.x - b.axial_coords.y)
	return (abs(dq) + abs(dr) + abs(ds)) / 2


## Creates and returns the default biome if none assigned.
func _get_or_create_default_biome() -> BiomeData:
	var biome: BiomeData = BiomeData.new()
	biome.biome_id = "default"
	biome.display_name = "Default"
	biome.base_density = 0.15
	biome.distance_multipliers = {0: 0.0, 3: 0.1, 7: 0.5, 15: 1.0, 25: 1.5, 100: 2.0}
	biome.min_tree_spacing = 1
	biome.allow_clustering = true
	biome.prefer_near_dirt = false
	biome.spawn_attempts = 5
	
	var oak: Resource = load("res://src/trees/resources/OakTree.tres")
	if oak:
		biome.tree_blueprints = [oak]
	
	return biome
