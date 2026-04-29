## Component that manages the Arena's minimap camera setup.
class_name ArenaMinimapHandler
extends Node

var arena: Node3D # ArenaGrid
var minimap_viewport: SubViewport
var minimap_camera: Camera3D
var minimap_container: SubViewportContainer
var _marker_container: Control
var _active_markers: Array[MinimapQuestMarker] = []
var _actor_markers: Dictionary = {} # Node -> MinimapActorMarker

func setup(p_arena: Node3D) -> void:
	arena = p_arena
	minimap_viewport = arena.get_node_or_null("UI/MinimapFrame/MinimapContainer/SubViewport")
	minimap_container = arena.get_node_or_null("UI/MinimapFrame/MinimapContainer")
	if minimap_viewport:
		minimap_camera = minimap_viewport.get_node_or_null("MinimapCamera")
	_setup_minimap()
	_setup_marker_overlay()
	_setup_actor_markers()
	_connect_quest_signals()
	call_deferred("_refresh_markers")

func _setup_minimap() -> void:
	if not minimap_viewport: return
	var camera = minimap_viewport.get_node_or_null("MinimapCamera")
	if camera:
		var w_total = arena._grid_width_clamped() + 2
		var h_total = arena._grid_height_clamped() + 2
		var center_x = (1.5 * (float(w_total - 1) * 0.5)) * arena.hex_size
		var center_z = (SQRT3() * (float(h_total - 1) * 0.5 + 0.25)) * arena.hex_size
		camera.position = Vector3(center_x, 100.0, center_z)
		camera.rotation_degrees = Vector3(-90, 0, 0)
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = max(w_total * 1.5 * arena.hex_size, h_total * SQRT3() * arena.hex_size) * 1.1

func SQRT3() -> float:
	return sqrt(3.0)

func _setup_marker_overlay() -> void:
	if not minimap_container:
		return
	_marker_container = Control.new()
	_marker_container.name = "QuestMarkerOverlay"
	_marker_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	minimap_container.add_child(_marker_container)

func _connect_quest_signals() -> void:
	if not QuestEvents.quest_accepted.is_connected(_on_quest_accepted):
		QuestEvents.quest_accepted.connect(_on_quest_accepted)
	if not QuestEvents.quest_completed.is_connected(_on_quest_completed):
		QuestEvents.quest_completed.connect(_on_quest_completed)
	if not QuestEvents.quest_failed.is_connected(_on_quest_failed):
		QuestEvents.quest_failed.connect(_on_quest_failed)

func _on_quest_accepted(_quest_id: String) -> void:
	# Give the spawn manager one frame to create camps before refreshing markers
	call_deferred("_refresh_markers")

func _on_quest_completed(_quest_id: String, _reward_gold: int) -> void:
	_clear_markers()

func _on_quest_failed(_quest_id: String) -> void:
	_clear_markers()

func _refresh_markers() -> void:
	_clear_markers()
	var spawn_manager: Node = arena.get_node_or_null("QuestSpawnManager")
	if spawn_manager == null:
		return
	var camp_records: Dictionary = _get_camp_records(spawn_manager)
	for camp_id in camp_records.keys():
		var record_value: Variant = camp_records.get(camp_id, {})
		if typeof(record_value) != TYPE_DICTIONARY:
			continue
		var record: Dictionary = record_value as Dictionary
		if not _camp_has_live_actors(record):
			continue
		var center_value: Variant = record.get("center", null)
		if center_value == null or not (center_value is Vector3):
			continue
		var marker: MinimapQuestMarker = MinimapQuestMarker.new()
		marker.name = "Marker_%s" % String(camp_id)
		marker.set_meta("camp_id", String(camp_id))
		_marker_container.add_child(marker)
		_active_markers.append(marker)

func _clear_markers() -> void:
	for marker in _active_markers:
		if is_instance_valid(marker):
			marker.queue_free()
	_active_markers.clear()

func _get_camp_records(spawn_manager: Node) -> Dictionary:
	if spawn_manager.has_method("get_camp_records"):
		var result: Variant = spawn_manager.call("get_camp_records")
		if result is Dictionary:
			return result as Dictionary
	elif "camp_records_by_id" in spawn_manager:
		var result: Variant = spawn_manager.get("camp_records_by_id")
		if result is Dictionary:
			return result as Dictionary
	return {}

func _camp_has_live_actors(record: Dictionary) -> bool:
	var actors_value: Variant = record.get("actors", [])
	if typeof(actors_value) != TYPE_ARRAY:
		return false
	var actors: Array = actors_value as Array
	for actor in actors:
		if actor != null and is_instance_valid(actor):
			return true
	return false

func _process(_delta: float) -> void:
	if minimap_camera == null or minimap_viewport == null or minimap_container == null:
		return
	var viewport_size: Vector2 = Vector2(minimap_viewport.size)
	var container_size: Vector2 = minimap_container.size
	if viewport_size.x <= 0 or viewport_size.y <= 0 or container_size.x <= 0 or container_size.y <= 0:
		return
	var scale_x: float = container_size.x / viewport_size.x
	var scale_y: float = container_size.y / viewport_size.y

	# Update quest camp markers
	var spawn_manager: Node = arena.get_node_or_null("QuestSpawnManager")
	if spawn_manager != null and not _active_markers.is_empty():
		var camp_records: Dictionary = _get_camp_records(spawn_manager)
		for marker in _active_markers:
			if not is_instance_valid(marker):
				continue
			var camp_id: String = String(marker.get_meta("camp_id", ""))
			if camp_id.is_empty():
				marker.visible = false
				continue
			var record_value: Variant = camp_records.get(camp_id, {})
			if typeof(record_value) != TYPE_DICTIONARY:
				marker.visible = false
				continue
			var record: Dictionary = record_value as Dictionary
			if not _camp_has_live_actors(record):
				marker.visible = false
				continue
			var center_value: Variant = record.get("center", null)
			if center_value == null or not (center_value is Vector3):
				marker.visible = false
				continue
			var world_pos: Vector3 = center_value as Vector3
			var viewport_pos: Vector2 = minimap_camera.unproject_position(world_pos)
			var local_pos: Vector2 = Vector2(viewport_pos.x * scale_x, viewport_pos.y * scale_y)
			# Clamp to container bounds
			local_pos.x = clampf(local_pos.x, 0.0, container_size.x - marker.size.x)
			local_pos.y = clampf(local_pos.y, 0.0, container_size.y - marker.size.y)
			marker.position = local_pos
			marker.visible = true

	# Update actor markers
	_update_actor_markers(scale_x, scale_y, container_size)

func _setup_actor_markers() -> void:
	_clear_actor_markers()

func _clear_actor_markers() -> void:
	for marker in _actor_markers.values():
		if is_instance_valid(marker):
			marker.queue_free()
	_actor_markers.clear()

func _update_actor_markers(scale_x: float, scale_y: float, container_size: Vector2) -> void:
	if arena == null:
		return
	var current_actors: Array[Node] = []
	for actor in arena.actors:
		if not is_instance_valid(actor):
			continue
		if "is_dead" in actor and actor.is_dead:
			continue
		current_actors.append(actor)
		var marker: MinimapActorMarker = _actor_markers.get(actor, null) as MinimapActorMarker
		if marker == null:
			marker = MinimapActorMarker.new()
			marker.name = "ActorMarker_%s" % actor.name
			_marker_container.add_child(marker)
			_actor_markers[actor] = marker
		marker.marker_color = _get_actor_marker_color(actor)
		var world_pos: Vector3 = actor.global_position
		var viewport_pos: Vector2 = minimap_camera.unproject_position(world_pos)
		var local_pos: Vector2 = Vector2(viewport_pos.x * scale_x, viewport_pos.y * scale_y)
		local_pos.x = clampf(local_pos.x, 0.0, container_size.x - marker.size.x)
		local_pos.y = clampf(local_pos.y, 0.0, container_size.y - marker.size.y)
		marker.position = local_pos
		marker.visible = true
	# Remove markers for actors that no longer exist
	for actor in _actor_markers.keys():
		if not is_instance_valid(actor) or not current_actors.has(actor):
			var marker: MinimapActorMarker = _actor_markers[actor] as MinimapActorMarker
			if is_instance_valid(marker):
				marker.queue_free()
			_actor_markers.erase(actor)

func _get_actor_marker_color(actor: Node) -> Color:
	var faction: FactionComponent.Faction = FactionComponent.Faction.NEUTRAL
	if "faction_component" in actor and actor.faction_component is FactionComponent:
		faction = actor.faction_component.faction
	match faction:
		FactionComponent.Faction.PLAYER, FactionComponent.Faction.FARMSTEAD:
			return Color(0.2, 0.9, 0.2, 0.95)
		FactionComponent.Faction.GOBLINS, FactionComponent.Faction.WILDLIFE, FactionComponent.Faction.MONSTERS:
			return Color(0.9, 0.2, 0.2, 0.95)
		_:
			return Color(0.6, 0.6, 0.6, 0.95)
