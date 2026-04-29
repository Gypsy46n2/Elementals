class_name ArenaSpawnerComponent
extends Node

var arena: Node3D # ArenaGrid

@export var farmer_scene: PackedScene = preload("res://Actor/FarmerActor.tscn")
@export var fire_actor_scene: PackedScene = preload("res://Actor/FireActor.tscn")
@export var water_actor_scene: PackedScene = preload("res://Actor/WaterActor.tscn")
@export var goat_actor_scene: PackedScene = preload("res://Actor/GoatActor.tscn")
@export var goblin_scene: PackedScene = preload("res://Actor/GoblinMinion.tscn")
@export var scarecrow_scene: PackedScene = preload("res://Actor/ScarecrowDummy.tscn")
@export_range(0, 20, 1) var random_wild_goat_count: int = 4

func setup(p_arena: Node3D) -> void:
	arena = p_arena

func spawn_initial_actors() -> void:
	# Spawn 1 starting goblins at random locations away from the farmstead.
	for i in range(1):
		var spawn_tile: HexTileData = _get_random_spawn_tile()
		if spawn_tile:
			spawn_actor_at_tile("goblin", spawn_tile)

	# Spawn ambient wildlife through the arena spawner, not through the quest board.
	spawn_random_wild_goats(random_wild_goat_count)

	# Spawn persistent/selected goats from GoatManager if applicable.
	if has_node("/root/GoatManager"):
		var gm: Node = get_node("/root/GoatManager")
		if gm.has_method("get_selected_goats"):
			var selected_value: Variant = gm.call("get_selected_goats")
			var selected_goats: Array = (selected_value as Array) if typeof(selected_value) == TYPE_ARRAY else []
			for goat_data in selected_goats:
				var g_tile: HexTileData = _get_random_spawn_tile()
				if g_tile:
					var goat: Node3D = spawn_actor_at_tile("goat", g_tile)
					if goat and goat is Actor:
						var goat_actor: Actor = goat as Actor
						goat_actor.faction_component.setup(FactionComponent.Faction.PLAYER)
						goat_actor.is_playable = true
						if goat is GoatActor:
							(goat as GoatActor).goat_data = goat_data

func get_selected_actor_scene() -> PackedScene:
	var gs: Node = get_node_or_null("/root/GameSettings")
	var type: String = "farmer"
	if gs:
		type = String(gs.get("selected_actor_type"))

	match type:
		"farmer": return farmer_scene
		"goblin": return goblin_scene
		"fire": return fire_actor_scene
		"water": return water_actor_scene
		"goat": return goat_actor_scene
	return farmer_scene

func spawn_actor(type: String) -> Node3D:
	var tile: HexTileData = _get_random_spawn_tile()
	if tile:
		return spawn_actor_at_tile(type, tile)
	return null

func spawn_goblin() -> void:
	spawn_actor("goblin")

func spawn_random_wild_goats(count: int = 4) -> void:
	var clean_count: int = maxi(0, count)
	for i in range(clean_count):
		spawn_random_goat()

func spawn_random_goat() -> Node3D:
	var tile: HexTileData = _get_random_spawn_tile()
	if tile == null:
		return null
	var goat: Node3D = spawn_actor_at_tile("goat", tile)
	_configure_wild_goat(goat)
	return goat

# Quest-safe spawn path used by QuestSpawnManager.
# It uses this ArenaSpawner directly so quest bounties do not accidentally use the selected player/goat actor type.
# © 2026 Micheal Chapin
func spawn_quest_actor(type: String, quest_id: String, target_id: String, radius_min: float = 8.0, radius_max: float = 30.0, origin_position: Vector3 = Vector3.ZERO) -> Node3D:
	var clean_type: String = type.to_lower().strip_edges()
	if clean_type.is_empty():
		clean_type = "goblin"
	var spawn_tile: HexTileData = _get_random_spawn_tile_near(origin_position, radius_min, radius_max)
	if spawn_tile == null:
		spawn_tile = _get_random_spawn_tile()
	if spawn_tile == null:
		return null
	var actor: Node3D = spawn_actor_at_tile(clean_type, spawn_tile)
	if actor == null:
		return null
	actor.set_meta("quest_id", quest_id)
	actor.set_meta("quest_target_id", target_id)
	actor.set_meta("quest_enemy_type", clean_type)
	_configure_quest_actor_faction(actor, clean_type)
	return actor

func _configure_quest_actor_faction(actor: Node3D, type: String) -> void:
	if actor is Actor:
		var actor_object: Actor = actor as Actor
		actor_object.is_playable = false
		if actor_object.faction_component:
			match type:
				"goblin":
					actor_object.faction_component.setup(FactionComponent.Faction.GOBLINS)
				"goat":
					actor_object.faction_component.setup(FactionComponent.Faction.WILDLIFE)
				_:
					actor_object.faction_component.setup(FactionComponent.Faction.MONSTERS)

func _get_random_spawn_tile_near(origin_position: Vector3, radius_min: float, radius_max: float) -> HexTileData:
	if not arena or arena.tile_data_grid.is_empty():
		return null
	var origin: Vector3 = origin_position
	if origin == Vector3.ZERO:
		origin = _get_default_spawn_origin()
	var attempts: int = 0
	while attempts < 180:
		attempts += 1
		var tile: HexTileData = arena.tile_data_grid.pick_random()
		if not _is_valid_actor_spawn_tile(tile):
			continue
		var distance: float = Vector2(tile.position.x - origin.x, tile.position.z - origin.z).length()
		if distance >= radius_min and distance <= radius_max:
			return tile
	return null

func _get_default_spawn_origin() -> Vector3:
	if arena and "current_controlled_actor" in arena and arena.current_controlled_actor:
		return arena.current_controlled_actor.global_position
	if arena and "actors" in arena:
		for actor in arena.actors:
			if is_instance_valid(actor) and actor is Actor and actor.is_playable:
				return actor.global_position
	if arena and "house_tile" in arena and arena.house_tile:
		return arena.house_tile.position
	return Vector3.ZERO

func _is_valid_actor_spawn_tile(tile: HexTileData) -> bool:
	if tile == null:
		return false
	if tile.current_state == TileConstants.State.STONE:
		return false
	if arena:
		if tile in arena.farmstead_interior_tiles:
			return false
		if tile in arena.farmstead_perimeter_tiles:
			return false
	return true

func spawn_scarecrow() -> void:
	if not arena or not "house_tile" in arena or not arena.house_tile:
		return
	var house_tile_data: HexTileData = arena.house_tile
	var neighbors: Array[HexTileData] = arena._get_neighbors(house_tile_data)
	for n in neighbors:
		if n not in arena.farmstead_interior_tiles and n not in arena.farmstead_perimeter_tiles:
			var dummy: Node3D = scarecrow_scene.instantiate()
			dummy.transform.origin = n.position + Vector3(0, arena._get_tile_surface_y(n), 0)
			arena.add_child(dummy)
			arena.actors.append(dummy)
			_log_spawn(dummy, "scarecrow")
			break

func spawn_selected_actor_at_tile(tile: HexTileData) -> Node3D:
	var gs: Node = get_node_or_null("/root/GameSettings")
	var type: String = "farmer"
	if gs:
		type = String(gs.get("selected_actor_type"))

	var scene: PackedScene = get_selected_actor_scene()
	if scene:
		var actor: Node3D = scene.instantiate()
		actor.transform.origin = tile.position + Vector3(0, arena._get_tile_surface_y(tile) + 1.0, 0)

		if actor is Actor:
			(actor as Actor).is_playable = true

		arena.add_child(actor)
		arena.actors.append(actor)

		if actor is Actor:
			(actor as Actor).faction_component.setup(FactionComponent.Faction.PLAYER)

		if actor is GoatActor:
			var player_goat: GoatActor = actor as GoatActor
			player_goat.goat_data = GoatData.new()
			player_goat.goat_data.goat_name = "Player Goat"

		var wl: Node = get_node_or_null("/root/ItemsAutoload")
		if gs and wl:
			var default_weapon_name: String = "Quarterstaff"
			if type == "goblin":
				default_weapon_name = "Dagger"

			var weapons_value: Variant = wl.get("weapons")
			if typeof(weapons_value) == TYPE_ARRAY:
				for w in (weapons_value as Array):
					if w.name == default_weapon_name:
						wl.call("set_selected_weapon", w)
						break

		_log_spawn(actor, type)
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
		var actor: Node3D = scene.instantiate()
		actor.transform.origin = tile.position + Vector3(0, arena._get_tile_surface_y(tile) + 1.0, 0)
		arena.add_child(actor)
		arena.actors.append(actor)
		if type == "goat":
			_configure_wild_goat(actor)
		_log_spawn(actor, type)
		return actor
	return null

func _configure_wild_goat(goat: Node3D) -> void:
	if goat == null or not goat is GoatActor:
		return
	var wild_goat: GoatActor = goat as GoatActor
	wild_goat.is_playable = false
	if wild_goat.faction_component:
		wild_goat.faction_component.setup(FactionComponent.Faction.WILDLIFE)
	if wild_goat.goat_data == null:
		wild_goat.goat_data = _make_random_goat_data()

func _make_random_goat_data() -> GoatData:
	var data: GoatData = GoatData.new()
	data.goat_name = _random_goat_name()
	data.gender = randi_range(0, 1)
	data.horn_type = randi_range(0, 3)
	data.body_type = randi_range(0, 2)
	data.pattern_type = randi_range(0, 2)
	data.base_color = Color(randf_range(0.55, 0.95), randf_range(0.48, 0.90), randf_range(0.36, 0.82))
	data.pattern_color = Color(randf_range(0.12, 0.42), randf_range(0.10, 0.38), randf_range(0.09, 0.34))
	data.strength = randf_range(0.8, 1.4)
	data.dexterity = randf_range(0.8, 1.3)
	data.constitution = randf_range(0.0, 0.8)
	data.wisdom = randf_range(-0.2, 0.7)
	data.gold_value = randi_range(25, 85)
	return data

func _random_goat_name() -> String:
	var names: Array[String] = [
		"Bramble", "Tumble", "Nibbles", "Mossbeard", "Pebble", "Juniper", "Thistle", "Biscuit", "Wobble", "Fern"
	]
	return "%s the Wild" % names.pick_random()

func _log_spawn(actor: Node, type_name: String) -> void:
	if not actor or not actor is Actor:
		return
	var faction_name: String = "Unknown"
	var actor_object: Actor = actor as Actor
	if actor_object.faction_component:
		faction_name = FactionComponent.Faction.keys()[actor_object.faction_component.faction]
	print("[%s] of [%s] spawned in" % [type_name.capitalize(), faction_name.capitalize()])

func _get_random_spawn_tile() -> HexTileData:
	if not arena or arena.tile_data_grid.is_empty():
		return null
	var attempts: int = 0
	while attempts < 100:
		var tile: HexTileData = arena.tile_data_grid.pick_random()
		if _is_valid_actor_spawn_tile(tile):
			return tile
		attempts += 1
	return null
