## ArenaGrid manages the hexagonal game world, including tile data, actor spawning, 
## farmstead generation, and player control orchestration.
## It acts as a central hub for various sub-systems like rendering, physics, and tile logic.
class_name ArenaGrid
extends Node3D

@export var tree_feature_scene: PackedScene = preload("res://Play Space/tree_feature.tscn")
@export var house_feature_scene: PackedScene = preload("res://Play Space/house_feature.tscn")
@export var fence_feature_scene: PackedScene = preload("res://Play Space/fence_feature.tscn")
@export var farmer_actor_scene: PackedScene = preload("res://Actor/FarmerActor.tscn")
@export var grid_width: int = 20
@export var grid_height: int = 20
@export var hex_size: float = 1.5
@export_range(0.25, 3.0, 0.05) var tile_scale: float = 1.5
@export var fire_actor_scene: PackedScene = preload("res://Actor/FireActor.tscn")
@export var water_actor_scene: PackedScene = preload("res://Actor/WaterActor.tscn")
@export var goat_actor_scene: PackedScene = preload("res://Actor/GoatActor.tscn")
@export var goblin_actor_scene: PackedScene = preload("res://Actor/GoblinMinion.tscn")
@export var scarecrow_dummy_scene: PackedScene = preload("res://Actor/ScarecrowDummy.tscn")
@export var noise: FastNoiseLite
@export var height_step: float = 1.0
@export var noise_scale: float = 1.0

const SQRT3: float = sqrt(3.0)

# Data storage
var tile_data_grid: Array[HexTileData] = []
var actors: Array[Node3D] = []
var farmstead_interior_tiles: Array[HexTileData] = []
var farmstead_perimeter_tiles: Array[HexTileData] = []
var house_tile: HexTileData = null

# Components
var renderer: HexGridRenderer
var tile_system: TileSystem
var physics: ArenaPhysics
var tile_interaction: ArenaTileInteractionComponent

signal tile_counts_changed(counts: Dictionary)
var tile_counts: Dictionary = {}

@onready var _target_label: Label = get_node_or_null("UI/HBoxContainer/TargetLabel")
@onready var _prev_button: Button = get_node_or_null("UI/HBoxContainer/PrevButton")
@onready var _next_button: Button = get_node_or_null("UI/HBoxContainer/NextButton")
@onready var _camera_follower: CameraFollower = get_node_or_null("Camera3D")
@onready var _minimap_viewport: SubViewport = get_node_or_null("UI/MinimapFrame/MinimapContainer/SubViewport")
@onready var _options_menu: OptionsMenu = get_node_or_null("UI/OptionsMenu")
@onready var _options_button: Button = get_node_or_null("UI/OptionsButton")

var current_target_index: int = 0
var current_controlled_actor: Actor:
	set(value):
		if is_instance_valid(current_controlled_actor):
			current_controlled_actor.is_controlled = false
			if current_controlled_actor.health_component:
				if current_controlled_actor.health_component.health_changed.is_connected(_on_actor_hp_changed):
					current_controlled_actor.health_component.health_changed.disconnect(_on_actor_hp_changed)
			if current_controlled_actor.mana_changed.is_connected(_on_actor_mana_changed):
				current_controlled_actor.mana_changed.disconnect(_on_actor_mana_changed)
		
		current_controlled_actor = value
		
		if current_controlled_actor:
			current_controlled_actor.is_controlled = true
			if current_controlled_actor.health_component:
				current_controlled_actor.health_component.health_changed.connect(_on_actor_hp_changed)
			current_controlled_actor.mana_changed.connect(_on_actor_mana_changed)
			if reticle:
				reticle.color = current_controlled_actor.get_actor_color()
			_update_ui()

var reticle: Control

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
	_setup_reticle()
	_initialize_grid()
	_setup_physics()
	_spawn_actors()
	_setup_farmstead()
	_setup_ui_connections()
	_setup_minimap()
	add_to_group("arena")
	
	_select_initial_actor()
	
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
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
	tile_interaction.name = "TileInteractionComponent"
	tile_interaction.setup(self)
	add_child(tile_interaction)

# Handles cleanup and logic when an actor dies, including game over checks.
# Should not be moved (Maintains high-level game session state).
func _on_actor_died(e: Node3D) -> void:
	if actors.has(e):
		actors.erase(e)
	
	if e == current_controlled_actor:
		next_actor()
	
	# Only check for extinction if a friendly unit just died
	if e is Actor and e.is_friendly:
		var friendlies_left = false
		for actor in actors:
			if actor is Actor and actor.is_friendly:
				friendlies_left = true
				break
		
		if not friendlies_left:
			_handle_game_over()

# Determines the layout of the farmstead, including interior and perimeter tiles.
# Could be moved to a FarmsteadGenerator component to separate world generation logic.
func _plan_farmstead() -> void:
	var x = grid_width / 2
	var y = grid_height / 2
	var center_tile = get_tile_at_grid_coords(x, y)
	if not center_tile: return
	
	farmstead_interior_tiles = []
	var queue: Array[HexTileData] = [center_tile]
	farmstead_interior_tiles.append(center_tile)
	
	var i = 0
	while farmstead_interior_tiles.size() < 10 and i < farmstead_interior_tiles.size():
		var current = farmstead_interior_tiles[i]
		i += 1
		var neighbors = _get_neighbors(current)
		neighbors.shuffle() # Randomize the blob shape slightly
		for n in neighbors:
			if n not in farmstead_interior_tiles and n.current_state != TileConstants.State.STONE:
				farmstead_interior_tiles.append(n)
				if farmstead_interior_tiles.size() >= 10:
					break
	
	farmstead_perimeter_tiles = []
	for tile in farmstead_interior_tiles:
		for n in _get_neighbors(tile):
			if n not in farmstead_interior_tiles and n not in farmstead_perimeter_tiles:
				if n.current_state != TileConstants.State.STONE:
					farmstead_perimeter_tiles.append(n)
	
	if not farmstead_perimeter_tiles.is_empty():
		# Randomly pick a perimeter tile for the house
		var house_idx = randi() % farmstead_perimeter_tiles.size()
		house_tile = farmstead_perimeter_tiles[house_idx]

# Spawns trees across the grid, avoiding the farmstead area.
# Could be moved to a WorldPopulator or FarmsteadGenerator component.
func _spawn_initial_trees() -> void:
	for tile in tile_data_grid:
		if tile.current_state == TileConstants.State.GRASS:
			if tile in farmstead_interior_tiles or tile in farmstead_perimeter_tiles:
				continue
			if randf() < 0.05:
				_spawn_tree(tile)

# Instantiates a tree at the given tile's position.
# Could be moved to a WorldPopulator component.
func _spawn_tree(tile: HexTileData) -> void:
	var tree = tree_feature_scene.instantiate()
	tree.transform.origin = tile.position + Vector3(0, _get_tile_surface_y(tile), 0)
	add_child(tree)
	tile.feature = tree
	if tree.has_method("set_tile"):
		tree.set_tile(tile)

# Generates the hex grid, assigns initial states, and applies noise-based height.
# Could be moved to a GridGenerator or MapGenerator component.
func _initialize_grid() -> void:
	var h = _grid_height_clamped()
	var w = _grid_width_clamped()
	var total_h = h + 2
	var total_w = w + 2
	var total_tiles = total_h * total_w
	
	renderer.setup(total_tiles)
	
	tile_data_grid.clear()
	tile_counts.clear()
	for state in TileConstants.State.values():
		tile_counts[state] = 0
	
	if not noise:
		noise = FastNoiseLite.new()
		var gs = get_node_or_null("/root/GameSettings")
		if gs:
			noise.seed = gs.noise_seed
			noise.frequency = gs.noise_frequency
			height_step = gs.height_step
		else:
			noise.seed = randi()
			noise.frequency = 0.05
		noise.noise_type = FastNoiseLite.TYPE_PERLIN
	
	for y in total_h:
		for x in total_w:
			var pos_2d = _calculate_hex_position(x, y)
			var pos = Vector3(pos_2d.x, 0.0, pos_2d.y)
			var axial = _offset_to_axial(x, y)
			
			var state: int
			if x == 0 or x == total_w - 1 or y == 0 or y == total_h - 1:
				state = TileConstants.State.STONE
			elif x > total_w / 2 and y > total_h / 2:
				state = TileConstants.State.DIRT
			else:
				state = TileConstants.State.GRASS
			
			var h_val = 0
			if noise:
				var nv = noise.get_noise_2d(float(x), float(y))
				h_val = int(clamp(floor((nv + 1.0) * 2.0), 0, 3))
			
			var tile = HexTileData.new(state, pos, axial, Vector2i(x, y), h_val)
			tile_data_grid.append(tile)
			tile_counts[state] += 1
			
			renderer.add_tile(tile)
			if state == TileConstants.State.FIRE:
				renderer.update_fire_effect(tile, true)
	
	_plan_farmstead()
	_spawn_initial_trees()
	
	for tile in tile_data_grid:
		if tile.current_state == TileConstants.State.STONE:
			var max_neighbor_h: float = -10.0
			for n in _get_neighbors(tile):
				if n.current_state != TileConstants.State.STONE:
					max_neighbor_h = max(max_neighbor_h, float(n.height_level) * height_step)
			
			if max_neighbor_h > -10.0:
				tile.set_meta("stone_height", max_neighbor_h + 2.0)
			else:
				tile.set_meta("stone_height", (float(tile.height_level) * height_step) + 2.0)
			
			renderer.remove_tile(tile)
			renderer.add_tile(tile)
	
	for tile in tile_data_grid:
		tile_system.check_activeness(tile)
		
	tile_counts_changed.emit(tile_counts)

# Calculates the vertical position of a tile's surface, accounting for height levels and special states like stone.
# Could be moved to HexTileData or a HexUtility class.
func _get_tile_surface_y(tile: HexTileData) -> float:
	if tile.current_state == TileConstants.State.STONE:
		if tile.has_meta("stone_height"):
			return tile.get_meta("stone_height")
		return (float(tile.height_level) * height_step) + 2.0
	return float(tile.height_level) * height_step

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

# Updates reticle information and processes tile logic every frame.
# Should not be moved (Main process loop).
func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	if current_controlled_actor and reticle:
		reticle.mana_value = current_controlled_actor.get_main_action_progress()
		if current_controlled_actor.projectile_component:
			reticle.attack_pattern = current_controlled_actor.projectile_component.current_attack_pattern
	
	tile_system.process_tiles(delta)

# Proxies elemental application to the TileInteractionComponent.
# Should not be moved (Maintains backward compatibility for actors and projectiles).
func apply_element_to_tile(tile: HexTileData, element: String, direction: Vector3 = Vector3.ZERO) -> bool:
	if tile_interaction:
		return tile_interaction.apply_element_to_tile(tile, element, direction)
	return false

# Returns an array of neighboring tiles for the given tile.
# Could be moved to a HexUtility or GridManager component.
func _get_neighbors(tile: HexTileData) -> Array[HexTileData]:
	var result: Array[HexTileData] = []
	var offsets = TileConstants.get_neighbor_offsets(tile.grid_coords.x)
	for offset in offsets:
		var nx = tile.grid_coords.x + offset.x
		var ny = tile.grid_coords.y + offset.y
		var n = get_tile_at_grid_coords(nx, ny)
		if n: result.append(n)
	return result

# Checks if any neighboring tiles are grass.
# Could be moved to a HexUtility or GridManager component.
func _has_adjacent_grass(tile: HexTileData) -> bool:
	for n in _get_neighbors(tile):
		if n.tile_type == TileConstants.Type.GRASS: return true
	return false

# Returns a neighboring dirt tile, if any.
# Could be moved to a HexUtility or GridManager component.
func _get_adjacent_dirt(tile: HexTileData) -> HexTileData:
	for n in _get_neighbors(tile):
		if n.tile_type == TileConstants.Type.DIRT: return n
	return null

# Retrieves tile data at the specified grid coordinates.
# Should not be moved (Direct grid access).
func get_tile_at_grid_coords(x: int, y: int) -> HexTileData:
	var h = _grid_height_clamped() + 2
	var w = _grid_width_clamped() + 2
	if x < 0 or x >= w or y < 0 or y >= h:
		return null
	return tile_data_grid[y * w + x]

# Converts a world position to tile data using hexagonal math.
# Could be moved to a HexUtility or GridManager component.
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
# Could be moved to a HexUtility or GridManager component.
func get_tile_at_world_position(world_position: Vector3) -> HexTileData:
	return get_tile_data_at_world_position(world_position)

# Converts offset grid coordinates to axial coordinates.
# Could be moved to a HexUtility class.
func _offset_to_axial(col: int, row: int) -> Vector2i:
	var q = col
	var r = row - (col - (col & 1)) / 2
	return Vector2i(q, r)

# Initializes physics collision for the grid.
# Should not be moved (Orchestration).
func _setup_physics() -> void:
	if physics:
		physics.setup_physics(tile_data_grid, hex_size, tile_scale, height_step, grid_width, grid_height)

# Creates and adds the player reticle UI element.
# Could be moved to a UIOrchestrator component.
func _setup_reticle() -> void:
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "ReticleLayer"
	add_child(canvas_layer)
	
	reticle = Control.new()
	reticle.set_script(preload("res://Player/Reticle.gd"))
	reticle.size = Vector2(64, 64)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(reticle)

# Connects UI signals to arena functions.
# Could be moved to a UIOrchestrator component.
func _setup_ui_connections() -> void:
	if _prev_button:
		_prev_button.focus_mode = Control.FOCUS_NONE
		_prev_button.pressed.connect(previous_actor)
	if _next_button:
		_next_button.focus_mode = Control.FOCUS_NONE
		_next_button.pressed.connect(next_actor)
	if _options_button and _options_menu:
		_options_button.focus_mode = Control.FOCUS_NONE
		_options_button.pressed.connect(_options_menu.toggle)
	
	var finish_button = Button.new()
	finish_button.text = "Finish Day"
	finish_button.focus_mode = Control.FOCUS_NONE
	finish_button.position = Vector2(20, 100)
	finish_button.pressed.connect(_on_finish_day_pressed)
	if has_node("UI"):
		$UI.add_child(finish_button)

# Transitions the game back to the ranch scene.
# Should not be moved (Flow control).
func _on_finish_day_pressed() -> void:
	GameEvents.day_finished.emit()
	if has_node("/root/GoatManager"):
		get_node("/root/GoatManager").next_day()
	get_tree().change_scene_to_file("res://Ranch/Ranch.tscn")

# Handles visual and logic changes when the player loses.
# Should not be moved (Flow control).
func _handle_game_over() -> void:
	if _target_label:
		_target_label.text = "ALL FRIENDLIES HAVE DIED!"
		_target_label.modulate = Color.RED
	
	current_controlled_actor = null
	var timer = get_tree().create_timer(3.0)
	timer.timeout.connect(_on_finish_day_pressed)

# Spawns initial actors, including goats from persistent data.
# Could be moved to an ActorSpawner or SessionManager component.
func _spawn_actors() -> void:
	actors.clear()
	
	# Spawn a test goblin minion
	if goblin_actor_scene:
		_spawn_type("goblin", grid_width / 2 + 3, grid_height / 2 + 3)
	
	if has_node("/root/GoatManager"):
		var gm = get_node("/root/GoatManager")
		for goat_data in gm.get_selected_goats():
			_spawn_goat_from_data(goat_data)

# Instantiates farmstead features like the house and fences.
# Could be moved to a FarmsteadGenerator component.
func _setup_farmstead() -> void:
	if not house_tile:
		return
	
	var house = house_feature_scene.instantiate()
	house.transform.origin = house_tile.position + Vector3(0, _get_tile_surface_y(house_tile), 0)
	add_child(house)
	house_tile.feature = house
	if house.has_method("set_tile"):
		house.set_tile(house_tile)
	
	# Spawn Selected Player Actor in the center of the yard
	var interior_center = farmstead_interior_tiles[0] if not farmstead_interior_tiles.is_empty() else house_tile
	var actor_scene = _get_selected_actor_scene()
	var player = actor_scene.instantiate()
	player.transform.origin = interior_center.position + Vector3(0, _get_tile_surface_y(interior_center) + 1.0, 0)
	add_child(player)
	
	if player is GoatActor:
		player.goat_data = GoatData.new()
		player.goat_data.goat_name = "Player Goat"
	
	player.is_playable = true # Ensure the selected character is playable
	actors.append(player)
	
	if player.has_node("DecisionComponent"):
		var decision = player.get_node("DecisionComponent")
		if "farm_center" in decision:
			decision.farm_center = interior_center.position
	
	# Spawn Fences on the rest of the perimeter
	var fences: Array[Node3D] = []
	for n in farmstead_perimeter_tiles:
		if n != house_tile and not n.feature:
			var fence = fence_feature_scene.instantiate()
			fence.transform.origin = n.position + Vector3(0, _get_tile_surface_y(n), 0)
			add_child(fence)
			n.feature = fence
			if fence.has_method("set_tile"):
				fence.set_tile(n)
			fences.append(fence)
	
	# Update fence connections visually
	for f in fences:
		if f.has_method("update_connections"):
			f.update_connections(self)
	
	# Spawn a scarecrow dummy just outside the yard
	_spawn_scarecrow()

# Spawns a scarecrow actor near the farmstead.
# Could be moved to a WorldPopulator or FarmsteadGenerator component.
func _spawn_scarecrow() -> void:
	if not scarecrow_dummy_scene:
		return
		
	# Pick a perimeter tile and find a neighbor that is outside the farmstead
	var outer_tile: HexTileData = null
	for p_tile in farmstead_perimeter_tiles:
		for n in _get_neighbors(p_tile):
			if n not in farmstead_interior_tiles and n not in farmstead_perimeter_tiles and n.current_state != TileConstants.State.STONE:
				outer_tile = n
				break
		if outer_tile:
			break
	
	if outer_tile:
		var scarecrow = scarecrow_dummy_scene.instantiate()
		scarecrow.transform.origin = outer_tile.position + Vector3(0, _get_tile_surface_y(outer_tile) + 1.0, 0)
		add_child(scarecrow)
		scarecrow.name = "ScarecrowDummy"
		actors.append(scarecrow)

# Spawns a goat actor and assigns it data.
# Could be moved to an ActorSpawner component.
func _spawn_goat_from_data(data: GoatData) -> void:
	var goat = goat_actor_scene.instantiate() as GoatActor
	var x = randi_range(1, grid_width)
	var y = randi_range(1, grid_height)
	var pos_2d = _calculate_hex_position(x, y)
	var tile = get_tile_at_grid_coords(x, y)
	var h_offset = 0.0
	if tile:
		h_offset = _get_tile_surface_y(tile)
	
	if not goat:
		push_error("Failed to instantiate goat actor!")
		return
	
	goat.position = Vector3(pos_2d.x, 2.0 + h_offset, pos_2d.y)
	add_child(goat)
	actors.append(goat)
	goat.goat_data = data

# Public wrapper for spawning actors by type.
# Could be moved to an ActorSpawner component.
func spawn_actor(type: String) -> void:
	_spawn_type(type)

# Helper to spawn a goblin.
# Could be moved to an ActorSpawner component.
func spawn_goblin() -> void:
	_spawn_type("goblin")

# Internal logic for spawning different actor types at specific or random positions.
# Could be moved to an ActorSpawner component.
func _spawn_type(type: String, x: int = -1, y: int = -1) -> void:
	var scene = fire_actor_scene
	if type == "water": scene = water_actor_scene
	elif type == "goat": scene = goat_actor_scene
	elif type == "goblin": scene = goblin_actor_scene
	
	var actor = scene.instantiate()
	if x == -1:
		x = randi_range(1, grid_width)
		y = randi_range(1, grid_height)
	
	var pos_2d = _calculate_hex_position(x, y)
	var tile = get_tile_at_grid_coords(x, y)
	var h_offset = 0.0
	if tile:
		h_offset = _get_tile_surface_y(tile)
	
	actor.position = Vector3(pos_2d.x, 2.0 + h_offset, pos_2d.y)
	add_child(actor)
	actors.append(actor)

# Returns the PackedScene for the selected player actor based on GameSettings.
# Could be moved to an ActorSpawner or GameSettings utility.
func _get_selected_actor_scene() -> PackedScene:
	var gs = get_node_or_null("/root/GameSettings")
	if not gs: return farmer_actor_scene
	
	match gs.selected_actor_type:
		"fire": return fire_actor_scene
		"water": return water_actor_scene
		"goat": return goat_actor_scene
		"goblin": return goblin_actor_scene
		"scarecrow": return scarecrow_dummy_scene
		"farmer": return farmer_actor_scene
	return farmer_actor_scene

# Selects the first available playable actor to be controlled.
# Should not be moved (Actor control management).
func _select_initial_actor() -> void:
	var idx = _find_playable_actor(0, 1)
	if idx != -1:
		current_target_index = idx
		_update_camera_target()

# Updates the camera to follow the currently selected actor and updates UI.
# Should not be moved (Actor control management).
func _update_camera_target() -> void:
	if actors.is_empty(): return
	var target = actors[current_target_index % actors.size()]
	
	if _camera_follower:
		_camera_follower.set_target(target)
		if target is GoatActor:
			_camera_follower.max_zoom = 10.0
		else:
			_camera_follower.max_zoom = 80.0
	current_controlled_actor = target as Actor
	if _target_label: _target_label.text = "Following: " + target.name

# Switches control to the next playable actor.
# Should not be moved (Actor control management).
func next_actor() -> void:
	var next_idx = _find_playable_actor(current_target_index + 1, 1)
	if next_idx != -1:
		current_target_index = next_idx
		_update_camera_target()

# Switches control to the previous playable actor.
# Should not be moved (Actor control management).
func previous_actor() -> void:
	var prev_idx = _find_playable_actor(current_target_index - 1, -1)
	if prev_idx != -1:
		current_target_index = prev_idx
		_update_camera_target()

# Searches for a playable actor in the actors array.
# Could be moved to an ActorManager component.
func _find_playable_actor(start_index: int, step: int) -> int:
	if actors.is_empty(): return -1
	var n = actors.size()
	for i in range(n):
		# Correct wrapping for negative step
		var idx = (start_index + i * step) % n
		if idx < 0: idx += n
		
		var a = actors[idx]
		if a is Actor and a.is_playable:
			return idx
	return -1

# Calculates the world position of a hex cell based on its grid coordinates.
# Could be moved to a HexUtility class.
func _calculate_hex_position(column: int, row: int) -> Vector2:
	var offset = float(column % 2) * 0.5
	var x_position = (1.5 * float(column)) * hex_size
	var z_position = (SQRT3 * (float(row) + offset)) * hex_size
	return Vector2(x_position, z_position)

# Helper to ensure grid width is at least 1.
# Should not be moved (Internal data validation).
func _grid_width_clamped() -> int: return max(1, grid_width)

# Helper to ensure grid height is at least 1.
# Should not be moved (Internal data validation).
func _grid_height_clamped() -> int: return max(1, grid_height)

# Signal handler for actor HP changes.
# Could be moved to a UIOrchestrator component.
func _on_actor_hp_changed(_hp: float, _m_hp: float) -> void: _update_ui()

# Signal handler for actor mana changes.
# Could be moved to a UIOrchestrator component.
func _on_actor_mana_changed(_m: float, _mm: float) -> void: _update_ui()

# Updates the on-screen UI with the current actor's stats.
# Could be moved to a UIOrchestrator component.
func _update_ui() -> void:
	if not current_controlled_actor or not _target_label: return
	var hp = 0.0
	var m_hp = 0.0
	if current_controlled_actor.health_component:
		hp = current_controlled_actor.health_component.current_health
		m_hp = current_controlled_actor.health_component.max_health
	_target_label.text = "Following: " + current_controlled_actor.name + \
		" HP: %d / %d | Mana: %d / %d" % [int(hp), int(m_hp), int(current_controlled_actor.current_mana), int(current_controlled_actor.max_mana)]

# Sets up the orthographic minimap camera.
# Could be moved to a MinimapManager component.
func _setup_minimap() -> void:
	if not _minimap_viewport: return
	var camera = _minimap_viewport.get_node_or_null("MinimapCamera")
	if camera:
		var w_total = _grid_width_clamped() + 2
		var h_total = _grid_height_clamped() + 2
		var center_x = (1.5 * (float(w_total - 1) * 0.5)) * hex_size
		var center_z = (SQRT3 * (float(h_total - 1) * 0.5 + 0.25)) * hex_size
		camera.position = Vector3(center_x, 100.0, center_z)
		camera.rotation_degrees = Vector3(-90, 0, 0)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = max(w_total * 1.5 * hex_size, h_total * SQRT3 * hex_size) * 1.1

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

# Processes mouse and keyboard input for actor actions.
# Should not be moved (Main input management).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if current_controlled_actor:
				current_controlled_actor.launch_projectile_at(_get_mouse_3d_position())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if current_controlled_actor:
				current_controlled_actor.secondary_attack_at(_get_mouse_3d_position())
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_E: current_controlled_actor.cycle_attack_pattern()
		elif event.keycode == KEY_Q: current_controlled_actor.prev_attack_pattern()
		elif event.keycode == KEY_T:
			if current_controlled_actor:
				current_controlled_actor.throw_weapon_at(_get_mouse_3d_position())

# Uses a raycast from the mouse position to find the world-space coordinate.
# Could be moved to a CameraUtility or InputHelper.
func _get_mouse_3d_position() -> Vector3:
	var camera = get_viewport().get_camera_3d()
	if not camera: return Vector3.ZERO
	var mouse_pos = get_viewport().get_mouse_position()
	
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 1000.0)
	var result = space_state.intersect_ray(query)
	
	if not result.is_empty():
		return result.position
	
	if abs(ray_direction.y) < 1e-6: return Vector3.ZERO
	var t = -ray_origin.y / ray_direction.y
	return ray_origin + ray_direction * t
