extends Node

const CAMP_FIRE_SMOKE_SCENE_PATH: String = "res://QuestSystem/CampMarkerFire/QuestCampFireSmoke.tscn"
const VISUAL_STEP_DELAY: float = 0.1

# Optimization: Shared resources to reduce memory and draw calls
var _wood_material: StandardMaterial3D = null
var _hide_material: StandardMaterial3D = null
var _cloth_material: StandardMaterial3D = null
var _marker_material: StandardMaterial3D = null

var _stone_mesh: BoxMesh = null
var _tent_mesh: BoxMesh = null
var _pole_mesh: BoxMesh = null
var _crate_mesh: BoxMesh = null
var _banner_mesh: BoxMesh = null
var _rag_mesh: BoxMesh = null
var _beacon_mesh: CylinderMesh = null
var _arrow_mesh: BoxMesh = null

# Quest spawns are routed through the arena's ArenaSpawnerComponent.
# Camp bounties now spawn clustered goblins around visible goblin camps instead of loose random enemies.
# Kill credit remains objective-based: camp goblins count, quest-spawned goblins count, and normal map goblins still count.

var arena: Node = null
var spawned_by_quest: Dictionary = {}
var spawned_records_by_instance_id: Dictionary = {}
var camp_records_by_id: Dictionary = {}
var camp_index_counter: int = 0
var _designated_camps: Dictionary = {} # quest_id -> Array[Dictionary]
var _active_quest_id: String = ""
var _quest_stone_walls: Dictionary = {} # quest_id -> HexTileData

func setup(p_arena: Node) -> void:
	arena = p_arena
	_init_connections()
	call_deferred("_designate_all_camp_tiles")

func _init_connections() -> void:
	if not QuestEvents.quest_spawn_requested.is_connected(_on_quest_spawn_requested):
		QuestEvents.quest_spawn_requested.connect(_on_quest_spawn_requested)
	if not QuestEvents.quest_failed.is_connected(_on_quest_failed):
		QuestEvents.quest_failed.connect(_on_quest_failed)
	if not QuestEvents.quest_completed.is_connected(_on_quest_completed):
		QuestEvents.quest_completed.connect(_on_quest_completed)
	if not GameEvents.actor_died.is_connected(_on_actor_died):
		GameEvents.actor_died.connect(_on_actor_died)

func _designate_all_camp_tiles() -> void:
	if arena == null:
		return
	var quests: Array = QuestDatabase.get_all_quests()
	var spawner: Node = _get_actor_spawner()
	if spawner == null:
		return
	
	var edge_index: int = randi() % 4
	
	for quest in quests:
		var quest_id: String = String(quest.get("id", ""))
		var spawns: Array = QuestDatabase.get_spawns(quest_id)
		var quest_camps: Array = []
		
		# Assign a stone wall tile for this quest's edge
		var stone_wall = _find_stone_tile_near_edge(edge_index % 4)
		if stone_wall:
			_quest_stone_walls[quest_id] = stone_wall
		
		for raw_spawn in spawns:
			var spawn_data: Dictionary = raw_spawn as Dictionary
			var count: int = maxi(1, int(spawn_data.get("count", 1)))
			var camp_count: int = maxi(1, int(spawn_data.get("camp_count", _suggest_camp_count(count))))
			var camp_size: String = String(spawn_data.get("camp_size", "small"))
			
			for i in range(camp_count):
				var camp_tile = _get_tile_near_edge(edge_index % 4)
				edge_index += 1
				if camp_tile != null:
					var camp_center: Vector3 = _tile_world_center(camp_tile)
					
					var camp_data: Dictionary = {
						"tile": camp_tile,
						"center": camp_center,
						"spawn_data": spawn_data,
						"spawned": false,
						"quest_id": quest_id
					}
					quest_camps.append(camp_data)
					
					camp_index_counter += 1
					var camp_id: String = "%s_camp_%02d" % [quest_id, camp_index_counter]
					
					# Register the trigger for enemy spawning
					var tile_signal_comp: Node = arena.get_node_or_null("TileSignalComponent")
					if tile_signal_comp != null:
						tile_signal_comp.call("register_trigger", camp_tile, 8, _on_camp_trigger_activated, {
							"quest_id": quest_id, 
							"camp_index": quest_camps.size() - 1,
							"camp_id": camp_id
						})
					
					# Register data only to allow minimap markers to show, but no visuals yet
					var member_count: int = maxi(1, int(ceil(float(count) / float(camp_count))))
					_register_camp_data(quest_id, camp_id, camp_center, camp_size, member_count)
		
		_designated_camps[quest_id] = quest_camps
	
	QuestEvents.message("All quest camps pre-placed. Discovery triggers active.")
	QuestEvents.camps_designated.emit()

func _get_tile_near_edge(edge_index: int) -> Variant:
	if arena == null: return null
	var grid_width: int = int(arena.get("grid_width"))
	var grid_height: int = int(arena.get("grid_height"))
	
	var attempts: int = 0
	while attempts < 300:
		attempts += 1
		var x: int
		var y: int
		match edge_index % 4:
			0: # North
				x = randi() % grid_width
				y = randi() % 4
			1: # South
				x = randi() % grid_width
				y = (grid_height - 1) - (randi() % 4)
			2: # East
				x = (grid_width - 1) - (randi() % 4)
				y = randi() % grid_height
			3: # West
				x = randi() % 4
				y = randi() % grid_height
		
		var tile = null
		if arena.has_method("get_tile_at_grid_coords"):
			tile = arena.get_tile_at_grid_coords(x, y)
		if tile != null and not _tile_is_blocked(tile):
			return tile
	return _get_spawn_tile(10, 40)

func _on_camp_trigger_activated(actor: Node3D, metadata: Dictionary) -> void:
	# Only trigger camp activation when the player enters the camp area.
	# This prevents spawned enemies from accidentally triggering their own camp.
	if not _is_player_actor(actor):
		return
	
	var quest_id: String = metadata.get("quest_id", "")
	var camp_index: int = metadata.get("camp_index", -1)
	var camp_id: String = metadata.get("camp_id", "")
	
	# Visuals and enemies spawn on discovery regardless of quest status
	_activate_camp_for_quest(quest_id, camp_index, camp_id)

func _activate_camp_for_quest(quest_id: String, camp_index: int, camp_id: String) -> void:
	if not _designated_camps.has(quest_id):
		return
	var camps: Array = _designated_camps[quest_id]
	if camp_index < 0 or camp_index >= camps.size():
		return
	
	var camp_data: Dictionary = camps[camp_index]
	if camp_data.get("visuals_spawned", false):
		return
	
	camp_data["visuals_spawned"] = true
	
	# Spawn visual structures
	var record: Dictionary = camp_records_by_id.get(camp_id, {})
	if not record.is_empty():
		var camp_center: Vector3 = record.get("center", Vector3.ZERO)
		var camp_size: String = record.get("size", "small")
		var expected: int = record.get("expected", 1)
		
		var camp_root: Node3D = _build_goblin_camp_visual(camp_id, camp_center, camp_size, expected)
		var marker: Node3D = null
		if camp_root != null and camp_root.has_node("QuestCampMarker"):
			marker = camp_root.get_node("QuestCampMarker") as Node3D
		
		record["root"] = camp_root
		record["marker"] = marker
		camp_records_by_id[camp_id] = record
		
		# Show world marker only if quest is active
		if is_instance_valid(marker):
			marker.visible = QuestState.active_quests.has(quest_id)
	
	# Spawn enemies
	_spawn_enemies_at_designated_camp(quest_id, camp_index, camp_id)

func _spawn_enemies_at_designated_camp(quest_id: String, camp_index: int, camp_id: String) -> void:
	if not _designated_camps.has(quest_id):
		return
	var camps: Array = _designated_camps[quest_id]
	if camp_index < 0 or camp_index >= camps.size():
		return
	
	var camp_data: Dictionary = camps[camp_index]
	if camp_data.spawned:
		# If enemies were already spawned for this quest instance, don't do it again
		# but if quest was failed/reset, camp_data.spawned should be false.
		return
	
	camp_data.spawned = true
	
	var spawner: Node = _get_actor_spawner()
	if spawner == null:
		return
	
	var spawn_data: Dictionary = camp_data.spawn_data
	var camp_center: Vector3 = camp_data.center
	
	var actor_type: String = String(spawn_data.get("actor_type", "goblin")).to_lower().strip_edges()
	var target_id: String = String(spawn_data.get("target_id", actor_type)).strip_edges()
	var count: int = maxi(1, int(spawn_data.get("count", 1)))
	var camp_count: int = maxi(1, int(spawn_data.get("camp_count", 1)))
	var camp_spawn_radius: float = float(spawn_data.get("camp_spawn_radius", 3.75))
	
	var member_count: int = maxi(1, int(ceil(float(count) / float(camp_count))))
	
	for i in range(member_count):
		var actor: Node = _spawn_camp_actor(spawner, actor_type, quest_id, target_id, camp_id, camp_center, camp_spawn_radius)
		if actor != null:
			_configure_spawned_actor(actor, quest_id, target_id, actor_type, i + 1, camp_id)
			_add_actor_to_camp(camp_id, actor)
		
		# Spawn one goblin per half second until all camp goblins have spawned
		if i < member_count - 1:
			if not is_inside_tree(): break
			await get_tree().create_timer(0.5).timeout
	
	_update_camp_marker(camp_id, null)
	QuestEvents.message("Quest camp discovered! Clear the area.")

func _spawn_designated_camp(quest_id: String, camp_index: int) -> void:
	# This is now handled by _spawn_enemies_at_designated_camp via the trigger
	pass

func get_camp_records() -> Dictionary:
	return camp_records_by_id

func _on_quest_spawn_requested(quest_id: String) -> void:
	_active_quest_id = quest_id
	QuestEvents.message("Quest accepted. Find the goblin camp in the arena.")
	_update_all_camp_marker_visibility()
	
	# Check for already cleared camps to credit progress immediately
	_check_for_pre_cleared_camps(quest_id)
	
	# Check if player is ALREADY near a camp when quest starts
	var tile_signal_comp: Node = arena.get_node_or_null("TileSignalComponent")
	if tile_signal_comp != null:
		var player_node = arena.get("current_controlled_actor")
		if player_node != null:
			var interaction = player_node.get("tile_interaction_component")
			if interaction != null:
				var tile = interaction.call("get_ground_tile")
				if tile != null:
					tile_signal_comp.call("_on_actor_tile_changed", tile, player_node)

func _check_for_pre_cleared_camps(quest_id: String) -> void:
	var total_to_credit: int = 0
	var target_id: String = ""
	
	for camp_id in camp_records_by_id.keys():
		var record: Dictionary = camp_records_by_id[camp_id]
		if record.get("quest_id", "") == quest_id:
			if record.get("cleared", false):
				var expected: int = int(record.get("expected", 0))
				total_to_credit += expected
				# Try to find target_id from spawn_data in designated_camps
				if target_id == "":
					target_id = _get_target_id_for_quest(quest_id)
	
	if total_to_credit > 0 and not target_id.is_empty():
		QuestEvents.message("Synchronizing pre-cleared camp progress...")
		QuestState.notify_kill(target_id, total_to_credit)

func _get_target_id_for_quest(quest_id: String) -> String:
	var spawns: Array = QuestDatabase.get_spawns(quest_id)
	for raw_spawn in spawns:
		var spawn_data: Dictionary = raw_spawn as Dictionary
		var actor_type: String = String(spawn_data.get("actor_type", "goblin")).to_lower().strip_edges()
		return String(spawn_data.get("target_id", actor_type)).strip_edges()
	return "goblin"

func _update_all_camp_marker_visibility() -> void:
	for camp_id in camp_records_by_id.keys():
		var record: Dictionary = camp_records_by_id[camp_id]
		var marker: Node3D = record.get("marker", null)
		if is_instance_valid(marker):
			marker.visible = QuestState.active_quests.has(record.get("quest_id", ""))

func spawn_quest_enemies(quest_id: String) -> void:
	if arena == null:
		arena = get_parent()
	var spawner: Node = _get_actor_spawner()
	if spawner == null:
		QuestEvents.message("Quest spawn failed: arena spawner is missing.")
		return

	var spawns: Array = QuestDatabase.get_spawns(quest_id)
	if spawns.is_empty():
		QuestEvents.message("Quest has no spawn data: %s" % quest_id)
		return

	_despawn_live_quest_actors(quest_id)
	_remove_quest_camps(quest_id, true)

	var total_spawned: int = 0
	var total_camps: int = 0
	var origin_position: Vector3 = _get_player_position()
	var existing_camp_positions: Array = []

	for raw_spawn in spawns:
		if typeof(raw_spawn) != TYPE_DICTIONARY:
			continue
		var spawn_data: Dictionary = raw_spawn as Dictionary
		var actor_type: String = String(spawn_data.get("actor_type", "goblin")).to_lower().strip_edges()
		if actor_type.is_empty():
			actor_type = "goblin"
		var target_id: String = String(spawn_data.get("target_id", actor_type)).strip_edges()
		if target_id.is_empty():
			target_id = actor_type

		var count: int = maxi(1, int(spawn_data.get("count", 1)))
		var radius_min: float = float(spawn_data.get("radius_min", 10.0))
		var radius_max: float = float(spawn_data.get("radius_max", 30.0))
		var camp_count: int = maxi(1, int(spawn_data.get("camp_count", _suggest_camp_count(count))))
		camp_count = mini(camp_count, count)
		var camp_size: String = String(spawn_data.get("camp_size", _camp_size_for_count(count))).to_lower().strip_edges()
		var camp_spawn_radius: float = float(spawn_data.get("camp_spawn_radius", _camp_spawn_radius_for_size(camp_size)))
		var camp_spacing: float = float(spawn_data.get("camp_spacing", 9.0))
		var remaining: int = count

		for camp_number in range(camp_count):
			var camps_left: int = camp_count - camp_number
			var camp_member_count: int = maxi(1, int(ceil(float(remaining) / float(camps_left))))
			remaining -= camp_member_count

			var camp_tile: Variant = _get_camp_tile(spawner, origin_position, radius_min, radius_max, existing_camp_positions, camp_spacing)
			if camp_tile == null:
				continue
			var camp_center: Vector3 = _tile_world_center(camp_tile)
			existing_camp_positions.append(camp_center)

			camp_index_counter += 1
			var camp_id: String = "%s_camp_%02d" % [quest_id, camp_index_counter]
			_create_camp_record(quest_id, camp_id, camp_center, camp_size, camp_member_count)
			total_camps += 1

			for i in range(camp_member_count):
				var actor: Node = _spawn_camp_actor(spawner, actor_type, quest_id, target_id, camp_id, camp_center, camp_spawn_radius)
				if actor != null:
					_configure_spawned_actor(actor, quest_id, target_id, actor_type, total_spawned + 1, camp_id)
					_add_actor_to_camp(camp_id, actor)
					total_spawned += 1
				
				if i < camp_member_count - 1:
					if not is_inside_tree(): break
					await get_tree().create_timer(0.5).timeout

			_update_camp_marker(camp_id, null)

	if total_spawned > 0:
		QuestEvents.message("Spawned %d goblins at %d quest camp(s). Follow the camp marker." % [total_spawned, total_camps])
	else:
		QuestEvents.message("Quest accepted, but no camp found valid spawn tiles.")

func _spawn_camp_actor(spawner: Node, actor_type: String, quest_id: String, target_id: String, camp_id: String, camp_center: Vector3, camp_radius: float) -> Node:
	if spawner == null:
		return null
		
	if spawner.has_method("spawn_quest_actor_near"):
		var camp_actor_value: Variant = spawner.call("spawn_quest_actor_near", actor_type, quest_id, target_id, camp_center, camp_radius)
		if camp_actor_value != null and camp_actor_value is Node:
			var camp_actor: Node = camp_actor_value as Node
			camp_actor.set_meta("quest_camp_id", camp_id)
			return camp_actor
		return null

	if spawner.has_method("spawn_quest_actor"):
		var fallback_value: Variant = spawner.call("spawn_quest_actor", actor_type, quest_id, target_id, 0.0, camp_radius, camp_center)
		if fallback_value != null and fallback_value is Node:
			var fallback_actor: Node = fallback_value as Node
			fallback_actor.set_meta("quest_camp_id", camp_id)
			return fallback_actor
		return null

	var tile: Variant = _get_spawn_tile(0.0, camp_radius)
	if tile == null:
		return null
	if spawner.has_method("spawn_actor_at_tile"):
		var actor_value: Variant = spawner.call("spawn_actor_at_tile", actor_type, tile)
		if actor_value != null and actor_value is Node:
			var actor: Node = actor_value as Node
			actor.set_meta("quest_id", quest_id)
			actor.set_meta("quest_target_id", target_id)
			actor.set_meta("quest_enemy_type", actor_type)
			actor.set_meta("quest_camp_id", camp_id)
			return actor
	return null

func _get_camp_tile(spawner: Node, origin_position: Vector3, radius_min: float, radius_max: float, existing_positions: Array, camp_spacing: float) -> Variant:
	if spawner.has_method("get_quest_camp_tile"):
		var camp_tile_value: Variant = spawner.call("get_quest_camp_tile", origin_position, radius_min, radius_max, existing_positions, camp_spacing)
		if camp_tile_value != null:
			return camp_tile_value
	return _get_spawn_tile(radius_min, radius_max)

func _suggest_camp_count(count: int) -> int:
	if count >= 9:
		return 3
	if count >= 5:
		return 2
	return 1

func _camp_size_for_count(count: int) -> String:
	if count >= 9:
		return "large"
	if count >= 5:
		return "medium"
	return "small"

func _camp_spawn_radius_for_size(camp_size: String) -> float:
	match camp_size:
		"large":
			return 6.5
		"medium":
			return 5.0
		_:
			return 3.75

func _tile_world_center(tile: Variant) -> Vector3:
	if tile == null:
		return Vector3.ZERO
	var center: Vector3 = tile.position
	if arena != null and arena.has_method("_get_tile_surface_y"):
		var surface_y: float = float(arena.call("_get_tile_surface_y", tile))
		center.y = surface_y + 0.05
	return center

# The instance-id record protects kill tracking even if another script renames the actor
# or an imported scene drops custom metadata during setup.
# © 2026 Micheal Chapin
func _configure_spawned_actor(actor: Node, quest_id: String, target_id: String, actor_type: String, number: int, camp_id: String = "") -> void:
	actor.set_meta("quest_id", quest_id)
	actor.set_meta("quest_target_id", target_id)
	actor.set_meta("quest_enemy_type", actor_type)
	if not camp_id.is_empty():
		actor.set_meta("quest_camp_id", camp_id)
		actor.add_to_group("quest_camp_%s" % camp_id)
	actor.add_to_group("quest_spawned")
	actor.add_to_group("quest_%s" % quest_id)
	actor.name = "%s_%s_%02d" % [quest_id, actor_type.capitalize(), number]

	var record: Dictionary = {
		"quest_id": quest_id,
		"target_id": target_id,
		"actor_type": actor_type,
		"camp_id": camp_id
	}
	spawned_records_by_instance_id[actor.get_instance_id()] = record
	if not spawned_by_quest.has(quest_id):
		spawned_by_quest[quest_id] = []
	var list: Array = spawned_by_quest[quest_id] as Array
	list.append(actor)
	spawned_by_quest[quest_id] = list

	if actor is Actor:
		var actor_object: Actor = actor as Actor
		actor_object.is_playable = false
		if actor_object.faction_component:
			match actor_type:
				"goblin":
					actor_object.faction_component.setup(FactionComponent.Faction.GOBLINS)
				"goat":
					actor_object.faction_component.setup(FactionComponent.Faction.WILDLIFE)
				_:
					actor_object.faction_component.setup(FactionComponent.Faction.MONSTERS)

func _register_camp_data(quest_id: String, camp_id: String, camp_center: Vector3, camp_size: String, expected_count: int) -> void:
	camp_records_by_id[camp_id] = {
		"quest_id": quest_id,
		"camp_id": camp_id,
		"center": camp_center,
		"size": camp_size,
		"expected": expected_count,
		"actors": [],
		"root": null,
		"marker": null
	}

func _create_camp_record(quest_id: String, camp_id: String, camp_center: Vector3, camp_size: String, expected_count: int) -> void:
	var camp_root: Node3D = _build_goblin_camp_visual(camp_id, camp_center, camp_size, expected_count)
	var marker: Node3D = null
	if camp_root != null and camp_root.has_node("QuestCampMarker"):
		marker = camp_root.get_node("QuestCampMarker") as Node3D
	
	camp_records_by_id[camp_id] = {
		"quest_id": quest_id,
		"camp_id": camp_id,
		"center": camp_center,
		"size": camp_size,
		"expected": expected_count,
		"actors": [],
		"root": camp_root,
		"marker": marker
	}
	
	if is_instance_valid(marker):
		marker.visible = QuestState.active_quests.has(quest_id)

func _add_actor_to_camp(camp_id: String, actor: Node) -> void:
	if camp_id.is_empty() or not camp_records_by_id.has(camp_id):
		return
	var record: Dictionary = camp_records_by_id[camp_id] as Dictionary
	var actors: Array = _safe_array(record.get("actors", []))
	actors.append(actor)
	record["actors"] = actors
	camp_records_by_id[camp_id] = record

func _init_resources() -> void:
	if _wood_material != null:
		return
	
	_wood_material = StandardMaterial3D.new()
	_wood_material.albedo_color = Color(0.24, 0.12, 0.05)
	
	_hide_material = StandardMaterial3D.new()
	_hide_material.albedo_color = Color(0.32, 0.21, 0.12)
	
	_cloth_material = StandardMaterial3D.new()
	_cloth_material.albedo_color = Color(0.16, 0.30, 0.12)
	
	_marker_material = StandardMaterial3D.new()
	_marker_material.albedo_color = Color(1.0, 0.82, 0.16)
	_marker_material.emission_enabled = true
	_marker_material.emission = Color(1.0, 0.62, 0.10)
	
	_stone_mesh = BoxMesh.new()
	_stone_mesh.size = Vector3(0.28, 0.16, 0.20)
	
	_tent_mesh = BoxMesh.new()
	_tent_mesh.size = Vector3(1.6, 0.85, 1.15)
	
	_pole_mesh = BoxMesh.new()
	_pole_mesh.size = Vector3(0.12, 1.25, 0.12)
	
	_crate_mesh = BoxMesh.new()
	_crate_mesh.size = Vector3(0.55, 0.45, 0.55)
	
	_banner_mesh = BoxMesh.new()
	_banner_mesh.size = Vector3(0.14, 2.2, 0.14)
	
	_rag_mesh = BoxMesh.new()
	_rag_mesh.size = Vector3(0.75, 0.52, 0.08)
	
	_beacon_mesh = CylinderMesh.new()
	_beacon_mesh.top_radius = 0.12
	_beacon_mesh.bottom_radius = 0.12
	_beacon_mesh.height = 2.8
	_beacon_mesh.radial_segments = 12
	
	_arrow_mesh = BoxMesh.new()
	_arrow_mesh.size = Vector3(1.2, 0.22, 1.2)

func _create_multimesh_instance(mesh: Mesh, material: Material, transforms: Array[Transform3D]) -> MultiMeshInstance3D:
	var mmi: MultiMeshInstance3D = MultiMeshInstance3D.new()
	var mm: MultiMesh = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i in range(transforms.size()):
		mm.set_instance_transform(i, transforms[i])
	mmi.multimesh = mm
	mmi.material_override = material
	return mmi

func _build_goblin_camp_visual(camp_id: String, camp_center: Vector3, camp_size: String, expected_count: int) -> Node3D:
	if arena == null or not is_instance_valid(arena):
		return null

	_init_resources()

	var root: Node3D = Node3D.new()
	root.name = "GoblinCamp_%s" % camp_id
	root.position = camp_center
	root.add_to_group("quest_goblin_camp")
	arena.add_child(root)

	# 1. Fire and Marker (most important visual cues, added immediately)
	_spawn_camp_fire_smoke(root)
	var marker: Node3D = _make_camp_marker(expected_count)
	root.add_child(marker)

	# 2. Populate the rest over multiple frames to avoid frame stutters
	_populate_camp_visuals_deferred(root, camp_size, expected_count)

	return root

func _populate_camp_visuals_deferred(root: Node3D, camp_size: String, expected_count: int) -> void:
	if not is_instance_valid(root) or not root.is_inside_tree():
		return

	var camp_radius: float = _camp_spawn_radius_for_size(camp_size)

	# Stones (MultiMesh)
	await get_tree().process_frame
	if not is_instance_valid(root): return
	var ring_count: int = maxi(5, mini(10, expected_count + 3))
	var stone_transforms: Array[Transform3D] = []
	for i in range(ring_count):
		var angle: float = TAU * float(i) / float(ring_count)
		stone_transforms.append(Transform3D(Basis().rotated(Vector3.UP, -angle), Vector3(cos(angle) * 0.58, 0.08, sin(angle) * 0.58)))
	root.add_child(_create_multimesh_instance(_stone_mesh, _hide_material, stone_transforms))

	# Tents and Poles (MultiMesh)
	await get_tree().process_frame
	if not is_instance_valid(root): return
	var tent_count: int = 1
	if camp_size == "medium": tent_count = 2
	elif camp_size == "large": tent_count = 3
	
	var tent_transforms: Array[Transform3D] = []
	var pole_transforms: Array[Transform3D] = []
	for i in range(tent_count):
		var angle: float = TAU * float(i) / float(tent_count) + 0.45
		var pos: Vector3 = Vector3(cos(angle) * camp_radius * 0.55, 0.42, sin(angle) * camp_radius * 0.55)
		tent_transforms.append(Transform3D(Basis().rotated(Vector3.UP, -angle), pos))
		pole_transforms.append(Transform3D(Basis(), pos + Vector3(0.0, 0.38, 0.0)))
	
	root.add_child(_create_multimesh_instance(_tent_mesh, _cloth_material, tent_transforms))
	root.add_child(_create_multimesh_instance(_pole_mesh, _wood_material, pole_transforms))

	# Crates (MultiMesh)
	await get_tree().process_frame
	if not is_instance_valid(root): return
	var crate_count: int = 2 if camp_size == "small" else 4
	if camp_size == "large": crate_count = 6
	var crate_transforms: Array[Transform3D] = []
	for i in range(crate_count):
		var angle: float = TAU * float(i) / float(crate_count) + 0.2
		var pos: Vector3 = Vector3(cos(angle) * camp_radius * 0.78, 0.22, sin(angle) * camp_radius * 0.78)
		crate_transforms.append(Transform3D(Basis().rotated(Vector3.UP, randf_range(0.0, TAU)), pos))
	root.add_child(_create_multimesh_instance(_crate_mesh, _wood_material, crate_transforms))

	# Banners (MultiMesh, large only)
	if camp_size == "large":
		await get_tree().process_frame
		if not is_instance_valid(root): return
		var banner_transforms: Array[Transform3D] = []
		var rag_transforms: Array[Transform3D] = []
		for i in range(2):
			var pos: Vector3 = Vector3(-1.0 + (2.0 * float(i)), 1.0, -camp_radius * 0.75)
			banner_transforms.append(Transform3D(Basis(), pos))
			rag_transforms.append(Transform3D(Basis(), pos + Vector3(0.32, 0.65, 0.0)))
		root.add_child(_create_multimesh_instance(_banner_mesh, _wood_material, banner_transforms))
		root.add_child(_create_multimesh_instance(_rag_mesh, _cloth_material, rag_transforms))

func _spawn_camp_fire_smoke(root: Node3D) -> void:
	var scene_resource: Resource = load(CAMP_FIRE_SMOKE_SCENE_PATH)
	if scene_resource == null or not (scene_resource is PackedScene):
		_spawn_fallback_campfire(root)
		return

	var fire_scene: PackedScene = scene_resource as PackedScene
	var fire_instance: Node = fire_scene.instantiate()
	if fire_instance == null or not (fire_instance is Node3D):
		_spawn_fallback_campfire(root)
		return

	var fire_node: Node3D = fire_instance as Node3D
	fire_node.name = "CampFireSmokeMarker"
	fire_node.position = Vector3(0.0, 0.0, 0.0)
	fire_node.scale = Vector3(0.85, 0.85, 0.85)
	fire_node.add_to_group("quest_camp_marker_fire")
	root.add_child(fire_node)

func _spawn_fallback_campfire(root: Node3D) -> void:
	var fallback_material: StandardMaterial3D = StandardMaterial3D.new()
	fallback_material.albedo_color = Color(1.0, 0.32, 0.04)
	fallback_material.emission_enabled = true
	fallback_material.emission = Color(1.0, 0.25, 0.04)
	var fallback_fire: MeshInstance3D = _make_cylinder_mesh("Campfire", 0.38, 0.16, fallback_material)
	fallback_fire.position = Vector3(0.0, 0.18, 0.0)
	root.add_child(fallback_fire)

func _make_box_mesh(node_name: String, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	return mesh_instance

func _make_cylinder_mesh(node_name: String, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh: CylinderMesh = CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	return mesh_instance

func _make_camp_marker(expected_count: int) -> Node3D:
	_init_resources()
	var marker: Node3D = Node3D.new()
	marker.name = "QuestCampMarker"
	marker.position = Vector3(0.0, 4.0, 0.0)

	var beacon: MeshInstance3D = MeshInstance3D.new()
	beacon.name = "MarkerBeacon"
	beacon.mesh = _beacon_mesh
	beacon.material_override = _marker_material
	beacon.position = Vector3(0.0, -1.05, 0.0)
	marker.add_child(beacon)

	var arrow: MeshInstance3D = MeshInstance3D.new()
	arrow.name = "MarkerArrow"
	arrow.mesh = _arrow_mesh
	arrow.material_override = _marker_material
	arrow.position = Vector3(0.0, 0.25, 0.0)
	arrow.rotation.y = PI * 0.25
	marker.add_child(arrow)

	var label: Label3D = Label3D.new()
	label.name = "MarkerLabel"
	label.text = "QUEST CAMP\n%d goblins left" % expected_count
	label.position = Vector3(0.0, 0.95, 0.0)
	label.font_size = 44
	label.modulate = Color(1.0, 0.88, 0.24)
	label.outline_size = 8
	label.outline_modulate = Color(0.08, 0.03, 0.0)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	marker.add_child(label)

	return marker

func _on_actor_died(actor: Node3D) -> void:
	if actor == null or not is_instance_valid(actor):
		return
	if _is_player_death(actor):
		QuestState.fail_active_quest("You died. Quest failed and reset for the next play.")
		return
	if QuestState.active_quests.is_empty():
		_cleanup_actor_record(actor)
		return

	var record: Dictionary = _record_for_actor(actor)
	var quest_id: String = String(record.get("quest_id", ""))
	if not quest_id.is_empty() and not QuestState.active_quests.has(quest_id):
		_cleanup_actor_record(actor)

	var candidates: Array[String] = _kill_target_candidates(actor, record)
	var credited: bool = false
	for candidate in candidates:
		if QuestState.notify_kill(candidate, 1):
			credited = true
			break

	var camp_id: String = _camp_id_for_actor(actor, record)
	if credited or not record.is_empty():
		_cleanup_actor_record(actor)
	if not camp_id.is_empty():
		_update_camp_marker(camp_id, actor)

func _kill_target_candidates(actor: Node, record: Dictionary) -> Array[String]:
	var candidates: Array[String] = []
	_append_unique_string(candidates, String(record.get("target_id", "")))
	_append_unique_string(candidates, String(record.get("actor_type", "")))

	var detected_type: String = _actor_type_from_node(actor)
	_append_unique_string(candidates, detected_type)

	if detected_type == "goblin" or _looks_like_goblin(actor):
		_append_unique_string(candidates, "goblin")
		_append_unique_string(candidates, "quest_goblin")
		_append_unique_string(candidates, "goblins")

	if detected_type == "goat" or _looks_like_goat(actor):
		_append_unique_string(candidates, "goat")
		_append_unique_string(candidates, "wild_goat")
		_append_unique_string(candidates, "quest_goat")

	if actor is Actor:
		var actor_object: Actor = actor as Actor
		if not actor_object.element_type.strip_edges().is_empty():
			_append_unique_string(candidates, actor_object.element_type.strip_edges())
		if actor_object.faction_component:
			var faction_index: int = int(actor_object.faction_component.faction)
			if faction_index >= 0 and faction_index < FactionComponent.Faction.keys().size():
				var faction_name: String = String(FactionComponent.Faction.keys()[faction_index]).to_lower().strip_edges()
				_append_unique_string(candidates, faction_name)
				if faction_name == "goblins":
					_append_unique_string(candidates, "goblin")
					_append_unique_string(candidates, "quest_goblin")

	return candidates

func _append_unique_string(list: Array[String], value: String) -> void:
	var clean_value: String = value.to_lower().strip_edges()
	if clean_value.is_empty():
		return
	if not list.has(clean_value):
		list.append(clean_value)

func _looks_like_goblin(actor: Node) -> bool:
	if actor is GoblinMinion:
		return true
	var lower_name: String = actor.name.to_lower()
	return lower_name.contains("goblin")

func _looks_like_goat(actor: Node) -> bool:
	if actor is GoatActor:
		return true
	var lower_name: String = actor.name.to_lower()
	return lower_name.contains("goat")

func _record_for_actor(actor: Node) -> Dictionary:
	var record_value: Variant = spawned_records_by_instance_id.get(actor.get_instance_id(), {})
	if typeof(record_value) == TYPE_DICTIONARY and not (record_value as Dictionary).is_empty():
		return (record_value as Dictionary).duplicate(true)
	if actor.has_meta("quest_target_id") or actor.has_meta("quest_enemy_type"):
		return {
			"quest_id": String(actor.get_meta("quest_id", "")),
			"target_id": String(actor.get_meta("quest_target_id", "")),
			"actor_type": String(actor.get_meta("quest_enemy_type", "")),
			"camp_id": String(actor.get_meta("quest_camp_id", ""))
		}
	if actor.is_in_group("quest_spawned"):
		return {
			"quest_id": "",
			"target_id": "",
			"actor_type": _actor_type_from_node(actor),
			"camp_id": String(actor.get_meta("quest_camp_id", ""))
		}
	return {}

func _camp_id_for_actor(actor: Node, record: Dictionary) -> String:
	var camp_id: String = String(record.get("camp_id", "")).strip_edges()
	if camp_id.is_empty() and actor.has_meta("quest_camp_id"):
		camp_id = String(actor.get_meta("quest_camp_id", "")).strip_edges()
	return camp_id

func _actor_type_from_node(actor: Node) -> String:
	if actor is GoblinMinion:
		return "goblin"
	if actor is GoatActor:
		return "goat"
	if actor is Actor:
		var actor_object: Actor = actor as Actor
		if not actor_object.element_type.strip_edges().is_empty():
			return actor_object.element_type.strip_edges().to_lower()
	var lower_name: String = actor.name.to_lower()
	if lower_name.contains("goblin"):
		return "goblin"
	if lower_name.contains("goat"):
		return "goat"
	return lower_name

func _is_player_death(actor: Node) -> bool:
	if not actor is Actor:
		return false
	var actor_object: Actor = actor as Actor
	if actor_object.is_playable:
		return true
	if arena != null:
		var current_value: Variant = arena.get("current_controlled_actor")
		if current_value == actor:
			return true
	if actor_object.faction_component and actor_object.faction_component.faction == FactionComponent.Faction.PLAYER:
		return true
	return false

func _is_player_actor(actor: Node3D) -> bool:
	if actor == null or not is_instance_valid(actor):
		return false
	if actor is Actor:
		var actor_object: Actor = actor as Actor
		if actor_object.is_playable:
			return true
	if arena != null:
		var current_value: Variant = arena.get("current_controlled_actor")
		if current_value == actor:
			return true
	return false

func _on_quest_failed(quest_id: String) -> void:
	_despawn_live_quest_actors(quest_id)
	_reset_designated_camps(quest_id)
	if _active_quest_id == quest_id:
		_active_quest_id = ""
	_update_all_camp_marker_visibility()

func _on_quest_completed(quest_id: String, _reward_gold: int) -> void:
	_lower_quest_stone_wall(quest_id)
	_despawn_live_quest_actors(quest_id)
	_reset_designated_camps(quest_id)
	if _active_quest_id == quest_id:
		_active_quest_id = ""
	_update_all_camp_marker_visibility()

func _lower_quest_stone_wall(quest_id: String) -> void:
	if not _quest_stone_walls.has(quest_id):
		return
	
	var tile = _quest_stone_walls[quest_id]
	if tile == null:
		return
	
	# Lowering logic
	var generator: Node = arena.get_node_or_null("GridGenerator")
	if generator == null: return
	
	var max_neighbor_h: float = -10.0
	var neighbors: Array = generator.call("get_neighbors", tile)
	var height_step: float = float(arena.get("height_step"))
	for n in neighbors:
		if n.current_state != TileConstants.State.STONE:
			max_neighbor_h = max(max_neighbor_h, float(n.height_level) * height_step)
	
	if max_neighbor_h > -10.0:
		tile.set_meta("stone_height", max_neighbor_h)
	else:
		tile.set_meta("stone_height", float(tile.height_level) * height_step)
	
	# Update visuals
	var renderer: Node = arena.get_node_or_null("HexGridRenderer")
	if renderer != null:
		renderer.call("remove_tile", tile)
		renderer.call("add_tile", tile)
	
	# Update physics if method exists
	var physics: Node = arena.get_node_or_null("ArenaPhysics")
	if physics != null and physics.has_method("update_tile_collision"):
		physics.call("update_tile_collision", tile)

	QuestEvents.message("A stone barrier on the edge has been lowered!")

func _find_stone_tile_near_edge(edge_index: int) -> Variant:
	if arena == null: return null
	var grid: Array = _get_tile_grid()
	var stone_tiles: Array = []
	for tile in grid:
		if tile.current_state == TileConstants.State.STONE:
			stone_tiles.append(tile)
	
	if stone_tiles.is_empty(): return null
	
	var grid_width: int = int(arena.get("grid_width"))
	var grid_height: int = int(arena.get("grid_height"))
	
	var candidates: Array = []
	for tile in stone_tiles:
		var x = tile.grid_coords.x
		var y = tile.grid_coords.y
		match edge_index % 4:
			0: # North: low y
				if y < 5: candidates.append(tile)
			1: # South: high y
				if y > grid_height - 6: candidates.append(tile)
			2: # East: high x
				if x > grid_width - 6: candidates.append(tile)
			3: # West: low x
				if x < 5: candidates.append(tile)
	
	if candidates.is_empty():
		return stone_tiles[randi() % stone_tiles.size()]
	
	# Try to pick one that isn't already assigned
	var unassigned: Array = []
	for c in candidates:
		if c not in _quest_stone_walls.values():
			unassigned.append(c)
	
	if not unassigned.is_empty():
		return unassigned[randi() % unassigned.size()]
	
	return candidates[randi() % candidates.size()]

func _reset_designated_camps(quest_id: String) -> void:
	if _designated_camps.has(quest_id):
		var camps: Array = _designated_camps[quest_id]
		for camp in camps:
			camp.spawned = false
			camp["visuals_spawned"] = false

func _despawn_live_quest_actors(quest_id: String) -> void:
	if quest_id.is_empty() or not spawned_by_quest.has(quest_id):
		return
	var existing: Array = spawned_by_quest[quest_id] as Array
	for actor in existing:
		if actor != null and is_instance_valid(actor):
			_cleanup_actor_record(actor)
			(actor as Node).queue_free()
	spawned_by_quest.erase(quest_id)

func _cleanup_actor_record(actor: Node) -> void:
	if actor == null:
		return
	spawned_records_by_instance_id.erase(actor.get_instance_id())
	if actor.has_meta("quest_id"):
		var quest_id: String = String(actor.get_meta("quest_id", ""))
		if spawned_by_quest.has(quest_id):
			var cleaned: Array = []
			var existing: Array = spawned_by_quest[quest_id] as Array
			for raw_actor in existing:
				if raw_actor != actor and raw_actor != null and is_instance_valid(raw_actor):
					cleaned.append(raw_actor)
			spawned_by_quest[quest_id] = cleaned

func _update_camp_marker(camp_id: String, dead_actor: Node) -> void:
	if camp_id.is_empty() or not camp_records_by_id.has(camp_id):
		return
	var record: Dictionary = camp_records_by_id[camp_id] as Dictionary
	var actors: Array = _safe_array(record.get("actors", []))
	var cleaned: Array = []
	for raw_actor in actors:
		if raw_actor == null:
			continue
		if dead_actor != null and raw_actor == dead_actor:
			continue
		if is_instance_valid(raw_actor):
			cleaned.append(raw_actor)
	record["actors"] = cleaned
	
	var marker_value: Variant = record.get("marker", null)
	if marker_value != null and is_instance_valid(marker_value):
		var marker: Node3D = marker_value as Node3D
		if cleaned.is_empty():
			marker.queue_free()
			record["marker"] = null
			record["cleared"] = true
			QuestEvents.message("Quest camp cleared!")
		else:
			var label_node: Node = marker.get_node_or_null("MarkerLabel")
			if label_node != null and label_node is Label3D:
				var label: Label3D = label_node as Label3D
				label.text = "QUEST CAMP\n%d goblins left" % cleaned.size()
	
	camp_records_by_id[camp_id] = record

func _remove_quest_camps(quest_id: String, remove_roots: bool) -> void:
	var ids_to_remove: Array[String] = []
	for raw_camp_id in camp_records_by_id.keys():
		var camp_id: String = String(raw_camp_id)
		var record_value: Variant = camp_records_by_id.get(camp_id, {})
		if typeof(record_value) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = record_value as Dictionary
		if String(record.get("quest_id", "")) != quest_id:
			continue
		var root_value: Variant = record.get("root", null)
		if remove_roots and root_value != null and is_instance_valid(root_value):
			(root_value as Node).queue_free()
		var marker_value: Variant = record.get("marker", null)
		if marker_value != null and is_instance_valid(marker_value):
			(marker_value as Node).queue_free()
		ids_to_remove.append(camp_id)
	for camp_id in ids_to_remove:
		camp_records_by_id.erase(camp_id)

func _get_spawn_tile(radius_min: float, radius_max: float) -> Variant:
	var grid: Array = _get_tile_grid()
	if grid.is_empty():
		return null
	var player_pos: Vector3 = _get_player_position()
	var attempts: int = 0
	while attempts < 160:
		attempts += 1
		var tile: Variant = grid.pick_random()
		if tile == null:
			continue
		if _tile_is_blocked(tile):
			continue
		var distance: float = Vector2(tile.position.x - player_pos.x, tile.position.z - player_pos.z).length()
		if distance >= radius_min and distance <= radius_max:
			return tile
	var spawner: Node = _get_actor_spawner()
	if spawner != null and spawner.has_method("_get_random_spawn_tile"):
		return spawner.call("_get_random_spawn_tile")
	return null

func _tile_is_blocked(tile: Variant) -> bool:
	if tile == null:
		return true
	if tile.get("current_state") == TileConstants.State.STONE:
		return true
	var interior: Array = _safe_array(arena.get("farmstead_interior_tiles"))
	if tile in interior:
		return true
	var perimeter: Array = _safe_array(arena.get("farmstead_perimeter_tiles"))
	if tile in perimeter:
		return true
	return false

func _get_player_position() -> Vector3:
	if arena != null:
		var current_value: Variant = arena.get("current_controlled_actor")
		if current_value != null and is_instance_valid(current_value) and current_value is Node3D:
			return (current_value as Node3D).global_position
		var actors: Array = _safe_array(arena.get("actors"))
		for actor in actors:
			if is_instance_valid(actor) and actor is Actor and actor.is_playable:
				return (actor as Node3D).global_position
	return Vector3.ZERO

func _get_actor_spawner() -> Node:
	if arena == null:
		return null
	var spawner_value: Variant = arena.get("actor_spawner")
	if spawner_value != null and spawner_value is Node:
		return spawner_value as Node
	return null

func _get_tile_grid() -> Array:
	if arena == null:
		return []
	return _safe_array(arena.get("tile_data_grid"))

func _safe_array(value: Variant) -> Array:
	if typeof(value) == TYPE_ARRAY:
		return value as Array
	return []

func _clear_old_dead_refs(quest_id: String) -> void:
	if not spawned_by_quest.has(quest_id):
		return
	var alive: Array = []
	var existing: Array = spawned_by_quest[quest_id] as Array
	for actor in existing:
		if actor != null and is_instance_valid(actor):
			alive.append(actor)
	spawned_by_quest[quest_id] = alive
