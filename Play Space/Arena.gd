## ArenaGrid manages the hexagonal game world, including tile data, actor spawning, 
## farmstead generation, and player control orchestration.
## It acts as a central hub for various sub-systems like rendering, physics, and tile logic.
class_name ArenaGrid
extends Node3D

@export var tree_feature_scene: PackedScene = preload("res://Play Space/tree_feature.tscn")
@export var house_feature_scene: PackedScene = preload("res://Play Space/house_feature.tscn")
@export var fence_feature_scene: PackedScene = preload("res://Play Space/fence_feature.tscn")
@export var grid_width: int = 20
@export var grid_height: int = 20
@export var hex_size: float = 1.5
@export_range(0.25, 3.0, 0.05) var tile_scale: float = 1.5
@export var noise: FastNoiseLite
@export var height_step: float = 1.0
@export var noise_scale: float = 1.0

const SQRT3: float = sqrt(3.0)

# Data storage
var tile_data_grid: Array[HexTileData] = []
var actors: Array[Node3D] = []

# Components
var renderer: HexGridRenderer
var tile_system: TileSystem
var physics: ArenaPhysics
var tile_interaction: ArenaTileInteractionComponent
var ui_component: Node # ArenaUIHandler
var actor_spawner: Node # ArenaSpawner
var player_input: PlayerInputComponent
var grid_generator: GridGenerator

var farmstead_interior_tiles: Array[HexTileData]:
	get: return grid_generator.farmstead_interior_tiles if grid_generator else []

var farmstead_perimeter_tiles: Array[HexTileData]:
	get: return grid_generator.farmstead_perimeter_tiles if grid_generator else []

var house_tile: HexTileData:
	get: return grid_generator.house_tile if grid_generator else null

signal tile_counts_changed(counts: Dictionary)
var tile_counts: Dictionary = {}

@onready var _camera_follower: CameraFollower = get_node_or_null("Camera3D")

var current_controlled_actor: Actor:
	get:
		return player_input.current_controlled_actor if player_input else null
	set(value):
		if player_input:
			player_input.current_controlled_actor = value

# Initializes the arena, sets up components, grid, physics, actors, and UI.
# Should not be moved (Main entry point for scene initialization).
func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		grid_width = gs.grid_width
		grid_height = gs.grid_height
	
	_setup_components()
	grid_generator.initialize_grid()
	_setup_physics()
	if actor_spawner:
		actor_spawner.spawn_initial_actors()
	grid_generator.setup_farmstead()
	add_to_group("arena")
	
	if player_input:
		player_input.select_initial_actor()
	
	GameEvents.actor_died.connect(_on_actor_died)

# Instantiates and attaches core logic components.
# Should not be moved (Orchestrates arena-specific components).
func _setup_components() -> void:
	renderer = HexGridRenderer.new()
	renderer.name = "HexGridRenderer"
	renderer.tile_scale = tile_scale
	renderer.hex_size = hex_size
	renderer.height_step = height_step
	add_child(renderer)
	
	tile_system = TileSystem.new()
	tile_system.name = "TileSystem"
	tile_system.arena = self
	add_child(tile_system)
	
	physics = ArenaPhysics.new()
	physics.name = "ArenaPhysics"
	add_child(physics)
	
	tile_interaction = ArenaTileInteractionComponent.new()
	tile_interaction.name = "ArenaTileInteractionComponent"
	tile_interaction.setup(self)
	add_child(tile_interaction)
	
	actor_spawner = ArenaSpawner.new()
	actor_spawner.name = "ArenaSpawner"
	add_child(actor_spawner)
	
	player_input = PlayerInputComponent.new()
	player_input.name = "PlayerInputComponent"
	add_child(player_input)
	
	ui_component = ArenaUIHandler.new()
	ui_component.name = "ArenaUIHandler"
	add_child(ui_component)
	
	grid_generator = GridGenerator.new()
	grid_generator.name = "GridGenerator"
	add_child(grid_generator)
	grid_generator.setup(self)
	
	actor_spawner.setup(self)
	player_input.setup(self)
	ui_component.setup(self)

# Handles cleanup and logic when an actor dies, including game over checks.
# Should not be moved (Maintains high-level game session state).
func _on_actor_died(e: Node3D) -> void:
	if actors.has(e):
		actors.erase(e)
	
	if e == current_controlled_actor:
		if player_input:
			player_input.next_actor()
	
	# Only check for extinction if a friendly unit just died
	if e is Actor and e.is_friendly:
		var friendlies_left = false
		for actor in actors:
			if actor is Actor and actor.is_friendly:
				friendlies_left = true
				break
		
		if not friendlies_left:
			if ui_component:
				ui_component.handle_game_over()

# Proxies for grid generation and layout logic
func _get_tile_surface_y(tile: HexTileData) -> float:
	return grid_generator.get_tile_surface_y(tile)

func _get_neighbors(tile: HexTileData) -> Array[HexTileData]:
	return grid_generator.get_neighbors(tile)

func _has_adjacent_grass(tile: HexTileData) -> bool:
	return grid_generator.has_adjacent_grass(tile)

func _get_adjacent_dirt(tile: HexTileData) -> HexTileData:
	return grid_generator.get_adjacent_dirt(tile)

func get_tile_at_grid_coords(x: int, y: int) -> HexTileData:
	return grid_generator.get_tile_at_grid_coords(x, y)

func _grid_width_clamped() -> int:
	return grid_generator._grid_width_clamped()

func _grid_height_clamped() -> int:
	return grid_generator._grid_height_clamped()

# Updates a tile's state, notifies the renderer, and triggers neighbor updates.
# Should not be moved (Central authority for tile state changes).
func set_tile_state(tile: HexTileData, new_state: int) -> void:
	if tile.current_state == new_state:
		return
		
	var old_state = tile.current_state
	renderer.remove_tile(tile)
	
	if old_state == TileConstants.State.FIRE:
		renderer.update_fire_effect(tile, false)
	
	tile.current_state = new_state
	tile._sync_type()
	
	renderer.add_tile(tile)
	
	if new_state == TileConstants.State.FIRE:
		renderer.update_fire_effect(tile, true)
	
	tile_counts[old_state] -= 1
	tile_counts[new_state] += 1
	tile_counts_changed.emit(tile_counts)
	
	tile_system.check_activeness(tile)
	for n in _get_neighbors(tile):
		tile_system.check_activeness(n)

# Processes tile logic every frame.
# Should not be moved (Main process loop).
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	tile_system.process_tiles(delta)

# Proxies elemental application to the ArenaTileInteractionComponent.
# Should not be moved (Maintains backward compatibility for actors and projectiles).
func apply_element_to_tile(tile: HexTileData, element: String, direction: Vector3 = Vector3.ZERO) -> bool:
	if tile_interaction:
		return tile_interaction.apply_element_to_tile(tile, element, direction)
	return false

# Converts a world position to tile data using hexagonal math.
func get_tile_data_at_world_position(world_position: Vector3) -> HexTileData:
	var local_pos = to_local(world_position)
	var x = local_pos.x
	var z = local_pos.z
	
	var q_float = x / (1.5 * hex_size)
	var r_float = (z / (SQRT3 * hex_size)) - (q_float * 0.5)
	
	var q = q_float
	var r = r_float
	var s = -q - r
	
	var rq = round(q)
	var rr = round(r)
	var rs = round(s)
	
	var dq = abs(rq - q)
	var dr = abs(rr - r)
	var ds = abs(rs - s)
	
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	
	var col = int(rq)
	var row = int(rr) + (col - (col & 1)) / 2
	
	return get_tile_at_grid_coords(col, row)

# Alias for get_tile_data_at_world_position.
func get_tile_at_world_position(world_position: Vector3) -> HexTileData:
	return get_tile_data_at_world_position(world_position)

# Initializes physics collision for the grid.
func _setup_physics() -> void:
	if physics:
		physics.setup_physics(tile_data_grid, hex_size, tile_scale, height_step, grid_width, grid_height)

# Returns an array of tiles within a given world-space radius.
# Could be moved to a GridManager component.
func get_tiles_within_distance(world_position: Vector3, radius: float) -> Array[HexTileData]:
	var results: Array[HexTileData] = []
	var radius_sq = radius * radius
	for tile in tile_data_grid:
		var d = tile.position - world_position
		d.y = 0
		if d.length_squared() <= radius_sq:
			results.append(tile)
	return results
