extends Node

# Quest spawns are routed through the arena's ArenaSpawnerComponent.
# Kill credit is intentionally objective-based: quest-spawned goblins count,
# normal map goblins count, and old saved quest targets like quest_goblin still count.

var arena: Node = null
var spawned_by_quest: Dictionary = {}
var spawned_records_by_instance_id: Dictionary = {}

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
	var total_spawned: int = 0
	var origin_position: Vector3 = _get_player_position()
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
		var radius_min: float = float(spawn_data.get("radius_min", 8.0))
		var radius_max: float = float(spawn_data.get("radius_max", 30.0))
		for i in range(count):
			var actor: Node = _spawn_with_arena_spawner(spawner, actor_type, quest_id, target_id, radius_min, radius_max, origin_position)
			if actor == null:
				continue
			_configure_spawned_actor(actor, quest_id, target_id, actor_type, i + 1)
			total_spawned += 1
	if total_spawned > 0:
		QuestEvents.message("Spawned %d quest goblins through ArenaSpawner." % total_spawned)
	else:
		QuestEvents.message("Quest accepted, but no enemies found valid spawn tiles.")

func _spawn_with_arena_spawner(spawner: Node, actor_type: String, quest_id: String, target_id: String, radius_min: float, radius_max: float, origin_position: Vector3) -> Node:
	if spawner.has_method("spawn_quest_actor"):
		var quest_actor_value: Variant = spawner.call("spawn_quest_actor", actor_type, quest_id, target_id, radius_min, radius_max, origin_position)
		if quest_actor_value != null and quest_actor_value is Node:
			return quest_actor_value as Node
		return null

	var tile: Variant = _get_spawn_tile(radius_min, radius_max)
	if tile == null:
		return null
	if spawner.has_method("spawn_actor_at_tile"):
		var actor_value: Variant = spawner.call("spawn_actor_at_tile", actor_type, tile)
		if actor_value != null and actor_value is Node:
			return actor_value as Node
	return null

# The instance-id record protects kill tracking even if another script renames the actor
# or an imported scene drops custom metadata during setup.
# © 2026 Micheal Chapin
func _configure_spawned_actor(actor: Node, quest_id: String, target_id: String, actor_type: String, number: int) -> void:
	actor.set_meta("quest_id", quest_id)
	actor.set_meta("quest_target_id", target_id)
	actor.set_meta("quest_enemy_type", actor_type)
	actor.add_to_group("quest_spawned")
	actor.add_to_group("quest_%s" % quest_id)
	actor.name = "%s_%s_%02d" % [quest_id, actor_type.capitalize(), number]

	var record: Dictionary = {
		"quest_id": quest_id,
		"target_id": target_id,
		"actor_type": actor_type
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

	if credited or not record.is_empty():
		_cleanup_actor_record(actor)

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
			"actor_type": String(actor.get_meta("quest_enemy_type", ""))
		}
	if actor.is_in_group("quest_spawned"):
		return {
			"quest_id": "",
			"target_id": "",
			"actor_type": _actor_type_from_node(actor)
		}
	return {}

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

func _on_quest_completed(quest_id: String, _reward_gold: int) -> void:
	_clear_old_dead_refs(quest_id)

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
