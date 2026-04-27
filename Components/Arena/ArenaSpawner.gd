class_name ArenaSpawner
extends Node

var arena: Node3D # ArenaGrid

@export var farmer_scene: PackedScene = preload("res://Actor/FarmerActor.tscn")
@export var fire_actor_scene: PackedScene = preload("res://Actor/FireActor.tscn")
@export var water_actor_scene: PackedScene = preload("res://Actor/WaterActor.tscn")
@export var goat_actor_scene: PackedScene = preload("res://Actor/GoatActor.tscn")
@export var goblin_scene: PackedScene = preload("res://Actor/GoblinMinion.tscn")
@export var scarecrow_scene: PackedScene = preload("res://Actor/ScarecrowDummy.tscn")

func setup(p_arena: Node3D) -> void:
	arena = p_arena

func spawn_initial_actors() -> void:
	# Spawn 6 starting goblins at random locations away from center
	for i in range(6):
		var spawn_tile = _get_random_spawn_tile()
		if spawn_tile:
			spawn_actor_at_tile("goblin", spawn_tile)
	
	# Spawn persistent goats from GoatManager if applicable
	if has_node("/root/GoatManager"):
		var gm = get_node("/root/GoatManager")
		for goat_data in gm.get_selected_goats():
			var g_tile = _get_random_spawn_tile()
			if g_tile:
				var goat = spawn_actor_at_tile("goat", g_tile)
				if goat and goat is GoatActor:
					goat.goat_data = goat_data

func get_selected_actor_scene() -> PackedScene:
	var gs = get_node_or_null("/root/GameSettings")
	var type = "farmer"
	if gs:
		type = gs.selected_actor_type
	
	match type:
		"farmer": return farmer_scene
		"goblin": return goblin_scene
		"fire": return fire_actor_scene
		"water": return water_actor_scene
		"goat": return goat_actor_scene
	return farmer_scene

func spawn_actor(type: String) -> Node3D:
	var tile = _get_random_spawn_tile()
	if tile:
		return spawn_actor_at_tile(type, tile)
	return null

func spawn_goblin() -> void:
	spawn_actor("goblin")

func spawn_scarecrow() -> void:
	if not arena or not "house_tile" in arena or not arena.house_tile: return
	var house_tile_data = arena.house_tile
	# Spawn a scarecrow dummy just outside the yard
	var neighbors = arena._get_neighbors(house_tile_data)
	for n in neighbors:
		if n not in arena.farmstead_interior_tiles and n not in arena.farmstead_perimeter_tiles:
			var dummy = scarecrow_scene.instantiate()
			dummy.transform.origin = n.position + Vector3(0, arena._get_tile_surface_y(n), 0)
			arena.add_child(dummy)
			arena.actors.append(dummy)
			break

func spawn_selected_actor_at_tile(tile: HexTileData) -> Node3D:
	var scene = get_selected_actor_scene()
	if scene:
		var actor = scene.instantiate()
		actor.transform.origin = tile.position + Vector3(0, arena._get_tile_surface_y(tile) + 1.0, 0)
		arena.add_child(actor)
		arena.actors.append(actor)
		
		if actor is Actor:
			actor.faction_component.setup(FactionComponent.Faction.PLAYER)
		
		if actor is GoatActor:
			actor.goat_data = GoatData.new()
			actor.goat_data.goat_name = "Player Goat"
		
		# Set default weapon for player
		var gs = get_node_or_null("/root/GameSettings")
		var wl = get_node_or_null("/root/ItemsAutoload")
		if gs and wl:
			var type = gs.selected_actor_type
			var default_weapon_name = "Quarterstaff"
			if type == "goblin": default_weapon_name = "Dagger"
			
			for w in wl.weapons:
				if w.name == default_weapon_name:
					wl.set_selected_weapon(w)
					break
			
		return actor
	return null

func spawn_actor_at_tile(type: String, tile: HexTileData) -> Node3D:
	var scene: PackedScene = null
	match type:
		"farmer": scene = farmer_scene
		"fire": scene = fire_actor_scene
		"water": scene = water_actor_scene
		"goat": scene = goat_actor_scene
		"goblin": scene = goblin_scene
	
	if scene:
		var actor = scene.instantiate()
		actor.transform.origin = tile.position + Vector3(0, arena._get_tile_surface_y(tile) + 1.0, 0)
		arena.add_child(actor)
		arena.actors.append(actor)
		return actor
	return null

func _get_random_spawn_tile() -> HexTileData:
	if not arena or arena.tile_data_grid.is_empty(): return null
	# Pick a random tile that is not part of the farmstead and not stone
	var attempts = 0
	while attempts < 100:
		var tile = arena.tile_data_grid.pick_random()
		if tile.current_state != TileConstants.State.STONE:
			if tile not in arena.farmstead_interior_tiles and tile not in arena.farmstead_perimeter_tiles:
				return tile
		attempts += 1
	return null
