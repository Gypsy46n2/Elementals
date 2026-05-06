## Minimap handler that uses the existing Arena 3D view.
## Captures the HexGridRenderer output once at game start.
## Actors are overlaid as simple colored dots.
class_name ArenaMinimapHandler
extends Node

const QuestMarkerClass = preload("res://Components/Arena/MinimapQuestMarker.gd")
const ActorMarkerClass = preload("res://Components/Arena/MinimapActorMarker.gd")

var arena: Node
var minimap_viewport: SubViewport
var minimap_camera: Camera3D
var minimap_container: SubViewportContainer
var _actor_container: Control
var _active_markers: Array = []
var _actor_markers: Dictionary = {}
var _spawn_manager: Node
var _actors_array: Array
var _debug_mode: bool = false
var _debug_toggle: CheckBox

var _actor_update_counter: int = 0
var _actor_update_interval: int = 10
var _initial_render_done: bool = false

func setup(p_arena: Node) -> void:
	arena = p_arena
	minimap_viewport = arena.get_node_or_null("UI/MinimapFrame/MinimapContainer/SubViewport")
	minimap_container = arena.get_node_or_null("UI/MinimapFrame/MinimapContainer")
	
	_setup_debug_toggle()
	_setup_minimap_camera()
	_setup_actor_overlay()
	_setup_actor_markers()
	_connect_quest_signals()
	_connect_tile_signals()
	
	_spawn_manager = arena.get_node_or_null("QuestSpawnManager")
	_actors_array = arena.get("actors") as Array
	
	# Delay initial render to ensure HexGridRenderer is ready
	call_deferred("_capture_initial_view")

func _setup_debug_toggle() -> void:
	_debug_toggle = arena.get_node_or_null("UI/MinimapFrame/DebugToggle")
	if _debug_toggle != null:
		_debug_toggle.toggled.connect(_on_debug_toggled)

func _setup_minimap_camera() -> void:
	if not minimap_viewport: return
	
	# Create a camera specifically for minimap capture
	minimap_camera = Camera3D.new()
	minimap_camera.name = "MinimapCaptureCamera"
	minimap_camera.current = false  # Not the main camera, just for capturing
	
	# Position camera above the arena looking straight down
	var w_total: int = int(arena.call("_grid_width_clamped"))
	var h_total: int = int(arena.call("_grid_height_clamped"))
	var hex_size: float = float(arena.get("hex_size"))
	
	# Center of the grid
	var center_x = (1.5 * (float(w_total - 1) * 0.5)) * hex_size
	var center_z = (sqrt(3.0) * (float(h_total - 1) * 0.5 + 0.25)) * hex_size
	
	minimap_camera.position = Vector3(center_x, 150.0, center_z)
	minimap_camera.rotation_degrees = Vector3(-90, 0, 0)  # Look straight down
	
	# Orthographic projection to match hex grid scale
	minimap_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	minimap_camera.size = max(w_total * 1.5 * hex_size, h_total * sqrt(3.0) * hex_size) * 0.9
	
	minimap_viewport.add_child(minimap_camera)
	
	# Set update mode to DISABLED - we control when it renders
	minimap_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	minimap_viewport.disable_3d = false  # Enable 3D so we can capture the HexGridRenderer

func _capture_initial_view() -> void:
	if not minimap_viewport or not minimap_camera: return
	if _initial_render_done: return
	
	# Make this camera current temporarily to capture
	var previous_camera = minimap_viewport.get_viewport().get_camera_3d()
	minimap_camera.current = true
	
	# Render once
	minimap_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await minimap_viewport.get_tree().process_frame
	
	minimap_camera.current = false
	if previous_camera:
		previous_camera.current = true
	
	_initial_render_done = true

func _setup_actor_overlay() -> void:
	if not minimap_container: return
	
	_actor_container = Control.new()
	_actor_container.name = "ActorContainer"
	_actor_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_actor_container.set_anchors_preset(Control.PRESET_FULL_RECT)
	_actor_container.visible = true
	minimap_container.add_child(_actor_container)

func _setup_actor_markers() -> void:
	pass

func _connect_quest_signals() -> void:
	if not QuestEvents.quest_accepted.is_connected(_on_quest_accepted):
		QuestEvents.quest_accepted.connect(_on_quest_accepted)
	if not QuestEvents.quest_completed.is_connected(_on_quest_completed):
		QuestEvents.quest_completed.connect(_on_quest_completed)
	if not QuestEvents.quest_failed.is_connected(_on_quest_failed):
		QuestEvents.quest_failed.connect(_on_quest_failed)
	if not QuestEvents.camps_designated.is_connected(_on_camps_designated):
		QuestEvents.camps_designated.connect(_on_camps_designated)

func _connect_tile_signals() -> void:
	if arena and arena.has_signal("tile_counts_changed"):
		if not arena.tile_counts_changed.is_connected(_on_tile_state_changed):
			arena.tile_counts_changed.connect(_on_tile_state_changed)

func _on_tile_state_changed(_counts: Dictionary) -> void:
	# Re-capture the view when tiles change state
	_capture_initial_view()

func _on_quest_accepted(_quest_id: String) -> void:
	_spawn_manager = arena.get_node_or_null("QuestSpawnManager")
	call_deferred("_refresh_markers")

func _on_camps_designated() -> void:
	_spawn_manager = arena.get_node_or_null("QuestSpawnManager")
	_refresh_markers()

func _on_debug_toggled(pressed: bool) -> void:
	_debug_mode = pressed
	_refresh_markers()

func _on_quest_completed(_quest_id: String, _reward_gold: int) -> void:
	call_deferred("_refresh_markers")

func _on_quest_failed(_quest_id: String) -> void:
	call_deferred("_refresh_markers")

func _refresh_markers() -> void:
	_clear_markers()
	if _spawn_manager == null: return
	
	var camp_records: Dictionary = _get_camp_records(_spawn_manager)
	for camp_id in camp_records.keys():
		var record_value: Variant = camp_records.get(camp_id, {})
		if typeof(record_value) != TYPE_DICTIONARY: continue
		
		var record: Dictionary = record_value as Dictionary
		if record.get("cleared", false): continue
		
		var center_value: Variant = record.get("center", null)
		if center_value == null or not (center_value is Vector3): continue
		
		var marker: Control = QuestMarkerClass.new()
		marker.name = "Marker_%s" % String(camp_id)
		marker.set_meta("camp_id", String(camp_id))
		_actor_container.add_child(marker)
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

func _process(_delta: float) -> void:
	if minimap_camera == null or minimap_viewport == null or minimap_container == null: return
	
	var viewport_size: Vector2 = Vector2(minimap_viewport.size)
	var container_size: Vector2 = minimap_container.size
	if viewport_size.x <= 0 or viewport_size.y <= 0 or container_size.x <= 0 or container_size.y <= 0: return
	
	# Throttle actor marker updates
	_actor_update_counter += 1
	if _actor_update_counter < _actor_update_interval: return
	_actor_update_counter = 0
	
	var spawn_manager: Node = arena.get_node_or_null("QuestSpawnManager")
	if spawn_manager != null and not _active_markers.is_empty():
		var camp_records: Dictionary = _get_camp_records(spawn_manager)
		_update_marker_positions(camp_records)

func _update_marker_positions(camp_records: Dictionary) -> void:
	var viewport_size: Vector2 = Vector2(minimap_viewport.size)
	var container_size: Vector2 = minimap_container.size
	var scale_x: float = container_size.x / viewport_size.x
	var scale_y: float = container_size.y / viewport_size.y
	
	var w_total: int = int(arena.call("_grid_width_clamped"))
	var h_total: int = int(arena.call("_grid_height_clamped"))
	var hex_size: float = float(arena.get("hex_size"))
	
	# Calculate the offset used in camera positioning
	var center_x = (1.5 * (float(w_total - 1) * 0.5)) * hex_size
	var center_z = (sqrt(3.0) * (float(h_total - 1) * 0.5 + 0.25)) * hex_size
	
	for marker in _active_markers:
		if not is_instance_valid(marker): continue
		
		var camp_id: String = marker.get_meta("camp_id", "")
		if not camp_records.has(camp_id): continue
		
		var record: Dictionary = camp_records.get(camp_id, {})
		var center: Vector3 = record.get("center", Vector3.ZERO)
		
		# Convert world position to viewport position
		var relative_x = (center.x - center_x) / (w_total * 1.5 * hex_size)
		var relative_z = (center.z - center_z) / (h_total * sqrt(3.0) * hex_size)
		
		var viewport_x = (relative_x + 0.5) * container_size.x
		var viewport_z = (relative_z + 0.5) * container_size.y
		
		marker.position = Vector2(viewport_x, viewport_z)
