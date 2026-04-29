extends Node

const CAMP_FIRE_SMOKE_SCENE_PATH: String = "res://QuestSystem/CampMarkerFire/QuestCampFireSmoke.tscn"

# Quest spawns are routed through the arena's ArenaSpawnerComponent.
# Camp bounties now spawn clustered goblins around visible goblin camps instead of loose random enemies.
# Kill credit remains objective-based: camp goblins count, quest-spawned goblins count, and normal map goblins still count.

var arena: Node = null
var spawned_by_quest: Dictionary = {}
var spawned_records_by_instance_id: Dictionary = {}
var camp_records_by_id: Dictionary = {}
var camp_index_counter: int = 0

func setup(p_arena: Node) -> void:
	arena = p_arena
	_connect_signals()

func _ready() -> void:
	if arena == null:
		arena = get_parent()
	_connect_signals()

func _connect_signals() -> void:
	if not QuestEvents.quest_spawn_requested.is_connected(_on_quest_spawn_requested):
		QuestEvents.quest_spawn_requested.connect(_on_quest_spawn_requested)
	if not QuestEvents.quest_failed.is_connected(_on_quest_failed):
		QuestEvents.quest_failed.connect(_on_quest_failed)
	if not QuestEvents.quest_completed.is_connected(_on_quest_completed):
		QuestEvents.quest_completed.connect(_on_quest_completed)
	var events: Node = get_node_or_null("/root/GameEvents")
	if events != null and not GameEvents.actor_died.is_connected(_on_actor_died):
		GameEvents.actor_died.connect(_on_actor_died)

func _on_quest_spawn_requested(quest_id: String) -> void:
	spawn_quest_enemies(quest_id)

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
				if actor == null:
					continue
				_configure_spawned_actor(actor, quest_id, target_id, actor_type, total_spawned + 1, camp_id)
				_add_actor_to_camp(camp_id, actor)
				total_spawned += 1

			_update_camp_marker(camp_id, null)

	if total_spawned > 0:
		QuestEvents.message("Spawned %d goblins at %d quest camp(s). Follow the camp marker." % [total_spawned, total_camps])
	else:
		QuestEvents.message("Quest accepted, but no camp found valid spawn tiles.")

func _spawn_camp_actor(spawner: Node, actor_type: String, quest_id: String, target_id: String, camp_id: String, camp_center: Vector3, camp_radius: float) -> Node:
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

func _add_actor_to_camp(camp_id: String, actor: Node) -> void:
	if camp_id.is_empty() or not camp_records_by_id.has(camp_id):
		return
	var record: Dictionary = camp_records_by_id[camp_id] as Dictionary
	var actors: Array = _safe_array(record.get("actors", []))
	actors.append(actor)
	record["actors"] = actors
	camp_records_by_id[camp_id] = record

func _build_goblin_camp_visual(camp_id: String, camp_center: Vector3, camp_size: String, expected_count: int) -> Node3D:
	if arena == null or not is_instance_valid(arena):
		return null

	var root: Node3D = Node3D.new()
	root.name = "GoblinCamp_%s" % camp_id
	root.position = camp_center
	root.add_to_group("quest_goblin_camp")
	arena.add_child(root)

	var wood_material: StandardMaterial3D = StandardMaterial3D.new()
	wood_material.albedo_color = Color(0.24, 0.12, 0.05)
	var hide_material: StandardMaterial3D = StandardMaterial3D.new()
	hide_material.albedo_color = Color(0.32, 0.21, 0.12)
	var cloth_material: StandardMaterial3D = StandardMaterial3D.new()
	cloth_material.albedo_color = Color(0.16, 0.30, 0.12)
	var camp_radius: float = _camp_spawn_radius_for_size(camp_size)
	_spawn_camp_fire_smoke(root)

	var ring_count: int = maxi(5, mini(10, expected_count + 3))
	for i in range(ring_count):
		var angle: float = TAU * float(i) / float(ring_count)
		var stone: MeshInstance3D = _make_box_mesh("CampfireStone_%02d" % i, Vector3(0.28, 0.16, 0.20), hide_material)
		stone.position = Vector3(cos(angle) * 0.58, 0.08, sin(angle) * 0.58)
		stone.rotation.y = -angle
		root.add_child(stone)

	var tent_count: int = 1
	if camp_size == "medium":
		tent_count = 2
	elif camp_size == "large":
		tent_count = 3

	for i in range(tent_count):
		var angle: float = TAU * float(i) / float(tent_count) + 0.45
		var tent: MeshInstance3D = _make_box_mesh("HideTent_%02d" % i, Vector3(1.6, 0.85, 1.15), cloth_material)
		tent.position = Vector3(cos(angle) * camp_radius * 0.55, 0.42, sin(angle) * camp_radius * 0.55)
		tent.rotation.y = -angle
		root.add_child(tent)

		var tent_pole: MeshInstance3D = _make_box_mesh("TentPole_%02d" % i, Vector3(0.12, 1.25, 0.12), wood_material)
		tent_pole.position = tent.position + Vector3(0.0, 0.38, 0.0)
		root.add_child(tent_pole)

	var crate_count: int = 2 if camp_size == "small" else 4
	if camp_size == "large":
		crate_count = 6
	for i in range(crate_count):
		var angle: float = TAU * float(i) / float(crate_count) + 0.2
		var crate: MeshInstance3D = _make_box_mesh("LootCrate_%02d" % i, Vector3(0.55, 0.45, 0.55), wood_material)
		crate.position = Vector3(cos(angle) * camp_radius * 0.78, 0.22, sin(angle) * camp_radius * 0.78)
		crate.rotation.y = randf_range(0.0, TAU)
		root.add_child(crate)

	if camp_size == "large":
		for i in range(2):
			var banner: MeshInstance3D = _make_box_mesh("GoblinBanner_%02d" % i, Vector3(0.14, 2.2, 0.14), wood_material)
			banner.position = Vector3(-1.0 + (2.0 * float(i)), 1.0, -camp_radius * 0.75)
			root.add_child(banner)
			var rag: MeshInstance3D = _make_box_mesh("GoblinBannerRag_%02d" % i, Vector3(0.75, 0.52, 0.08), cloth_material)
			rag.position = banner.position + Vector3(0.32, 0.65, 0.0)
			root.add_child(rag)

	var marker: Node3D = _make_camp_marker(expected_count)
	root.add_child(marker)

	return root

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
	var marker: Node3D = Node3D.new()
	marker.name = "QuestCampMarker"
	marker.position = Vector3(0.0, 4.0, 0.0)

	var marker_material: StandardMaterial3D = StandardMaterial3D.new()
	marker_material.albedo_color = Color(1.0, 0.82, 0.16)
	marker_material.emission_enabled = true
	marker_material.emission = Color(1.0, 0.62, 0.10)

	var beacon: MeshInstance3D = _make_cylinder_mesh("MarkerBeacon", 0.12, 2.8, marker_material)
	beacon.position = Vector3(0.0, -1.05, 0.0)
	marker.add_child(beacon)

	var arrow: MeshInstance3D = _make_box_mesh("MarkerArrow", Vector3(1.2, 0.22, 1.2), marker_material)
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

func _on_quest_failed(quest_id: String) -> void:
	_despawn_live_quest_actors(quest_id)
	_remove_quest_camps(quest_id, true)

func _on_quest_completed(quest_id: String, _reward_gold: int) -> void:
	_despawn_live_quest_actors(quest_id)
	_remove_quest_camps(quest_id, true)

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
	camp_records_by_id[camp_id] = record

	var marker_value: Variant = record.get("marker", null)
	if marker_value == null or not is_instance_valid(marker_value):
		return
	var marker: Node3D = marker_value as Node3D
	if cleaned.is_empty():
		marker.queue_free()
		record["marker"] = null
		camp_records_by_id[camp_id] = record
		return

	var label_node: Node = marker.get_node_or_null("MarkerLabel")
	if label_node != null and label_node is Label3D:
		var label: Label3D = label_node as Label3D
		label.text = "QUEST CAMP\n%d goblins left" % cleaned.size()

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
