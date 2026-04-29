extends Node3D

# Visible in-world quest board for Elementals/Goatlandia test arenas.
# The B key is range-checked at the exact moment it is pressed so the board
# cannot be opened from across the map by stale proximity state.
# © 2026 Micheal Chapin

var arena: Node = null
var prompt_label: Label3D = null
var area: Area3D = null
var _player_near: bool = false
var _board_tile: HexTileData = null
var _built: bool = false

const OPEN_DISTANCE: float = 5.5

func setup(p_arena: Node) -> void:
	arena = p_arena
	_build_once()
	call_deferred("_place_near_spawn")

func _ready() -> void:
	if arena == null:
		arena = get_parent()
	_build_once()
	call_deferred("_place_near_spawn")
	
	var timer = Timer.new()
	timer.name = "PlayerConnectionTimer"
	timer.wait_time = 1.0
	timer.autostart = true
	timer.timeout.connect(_check_player_connection)
	add_child(timer)

func _check_player_connection() -> void:
	var player_node: Node3D = _get_player_node()
	if player_node != null and player_node.has_signal("tile_changed"):
		if not player_node.tile_changed.is_connected(_on_player_tile_changed):
			player_node.tile_changed.connect(_on_player_tile_changed)
	
	# Fallback proximity check every second in case signals are missed 
	# or player is moving within a single tile.
	_on_player_tile_changed(null)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_B:
			if _can_player_open_board():
				_open_board()
				get_viewport().set_input_as_handled()

func _build_once() -> void:
	if _built:
		return
	_built = true
	add_to_group("quest_board_world")
	set_process_unhandled_input(true)

	var post_material: StandardMaterial3D = StandardMaterial3D.new()
	post_material.albedo_color = Color(0.30, 0.16, 0.07)

	var board_material: StandardMaterial3D = StandardMaterial3D.new()
	board_material.albedo_color = Color(0.16, 0.09, 0.035)

	var trim_material: StandardMaterial3D = StandardMaterial3D.new()
	trim_material.albedo_color = Color(0.95, 0.70, 0.22)

	var left_post: MeshInstance3D = _make_box("LeftPost", Vector3(0.18, 2.2, 0.18), post_material)
	left_post.position = Vector3(-1.25, 1.05, 0.0)
	add_child(left_post)

	var right_post: MeshInstance3D = _make_box("RightPost", Vector3(0.18, 2.2, 0.18), post_material)
	right_post.position = Vector3(1.25, 1.05, 0.0)
	add_child(right_post)

	var board_face: MeshInstance3D = _make_box("BoardFace", Vector3(3.15, 1.35, 0.18), board_material)
	board_face.position = Vector3(0.0, 2.0, 0.0)
	add_child(board_face)

	var top_trim: MeshInstance3D = _make_box("TopTrim", Vector3(3.35, 0.12, 0.24), trim_material)
	top_trim.position = Vector3(0.0, 2.72, -0.01)
	add_child(top_trim)

	var bottom_trim: MeshInstance3D = _make_box("BottomTrim", Vector3(3.35, 0.12, 0.24), trim_material)
	bottom_trim.position = Vector3(0.0, 1.28, -0.01)
	add_child(bottom_trim)

	var title: Label3D = Label3D.new()
	title.name = "QuestBoardTitle"
	title.text = "QUEST BOARD\nBounties + Gold"
	title.position = Vector3(0.0, 2.16, -0.16)
	title.font_size = 52
	title.modulate = Color(1.0, 0.82, 0.28)
	title.outline_size = 8
	title.outline_modulate = Color(0.05, 0.025, 0.0)
	title.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	add_child(title)

	prompt_label = Label3D.new()
	prompt_label.name = "QuestBoardPrompt"
	prompt_label.text = "Quest Board"
	prompt_label.position = Vector3(0.0, 3.05, 0.0)
	prompt_label.font_size = 34
	prompt_label.modulate = Color(0.72, 0.92, 1.0)
	prompt_label.outline_size = 6
	prompt_label.outline_modulate = Color.BLACK
	prompt_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	prompt_label.visible = false
	add_child(prompt_label)

	area = Area3D.new()
	area.name = "QuestBoardClickArea"
	area.input_ray_pickable = true
	area.position = Vector3(0.0, 1.8, 0.0)
	area.input_event.connect(_on_area_input_event)
	add_child(area)

	var shape: CollisionShape3D = CollisionShape3D.new()
	var box_shape: BoxShape3D = BoxShape3D.new()
	box_shape.size = Vector3(4.0, 3.2, 1.8)
	shape.shape = box_shape
	area.add_child(shape)

func _make_box(node_name: String, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = node_name
	var mesh: BoxMesh = BoxMesh.new()
	mesh.size = size
	mesh_instance.mesh = mesh
	mesh_instance.material_override = material
	return mesh_instance

func _place_near_spawn() -> void:
	if arena == null or not is_instance_valid(arena):
		return
	var player_node: Node3D = _get_player_node()
	var base_position: Vector3 = Vector3.ZERO
	if player_node != null and is_instance_valid(player_node):
		base_position = player_node.global_position
	else:
		base_position = _get_farm_position()
	var desired_position: Vector3 = base_position + Vector3(4.0, 0.0, 1.5)
	global_position = _snap_to_ground(desired_position)
	
	if arena.has_method("get_tile_data_at_world_position"):
		_board_tile = arena.call("get_tile_data_at_world_position", global_position)

	if player_node != null and player_node.has_signal("tile_changed"):
		if not player_node.tile_changed.is_connected(_on_player_tile_changed):
			player_node.tile_changed.connect(_on_player_tile_changed)
		
		var player_tile = null
		if player_node.get("tile_interaction_component"):
			player_tile = player_node.tile_interaction_component.get_ground_tile()
		if player_tile:
			_on_player_tile_changed(player_tile)
	
	if base_position != Vector3.ZERO:
		look_at(Vector3(base_position.x, global_position.y, base_position.z), Vector3.UP)
		rotate_y(PI)

func _get_player_node() -> Node3D:
	if arena == null or not is_instance_valid(arena):
		return null
	var actor_value: Variant = arena.get("current_controlled_actor")
	if actor_value != null and is_instance_valid(actor_value) and actor_value is Node3D:
		return actor_value as Node3D
	var actor_list_value: Variant = arena.get("actors")
	if typeof(actor_list_value) == TYPE_ARRAY:
		var actor_list: Array = actor_list_value as Array
		for raw_actor in actor_list:
			if raw_actor != null and is_instance_valid(raw_actor) and raw_actor is Actor:
				var actor_object: Actor = raw_actor as Actor
				if actor_object.is_playable:
					return raw_actor as Node3D
	return null

func _get_player_position() -> Vector3:
	var player_node: Node3D = _get_player_node()
	if player_node != null and is_instance_valid(player_node):
		return player_node.global_position
	return Vector3.ZERO

func _get_farm_position() -> Vector3:
	if arena == null:
		return Vector3.ZERO
	var house_tile_value: Variant = arena.get("house_tile")
	if house_tile_value != null:
		return house_tile_value.position
	var interior_value: Variant = arena.get("farmstead_interior_tiles")
	if typeof(interior_value) == TYPE_ARRAY:
		var interior: Array = interior_value as Array
		if not interior.is_empty():
			return interior[0].position
	return Vector3.ZERO

func _snap_to_ground(world_position: Vector3) -> Vector3:
	if arena != null and arena.has_method("get_tile_data_at_world_position") and arena.has_method("_get_tile_surface_y"):
		var tile_value: Variant = arena.call("get_tile_data_at_world_position", world_position)
		if tile_value != null:
			var surface_y: float = float(arena.call("_get_tile_surface_y", tile_value))
			return tile_value.position + Vector3(0.0, surface_y + 0.08, 0.0)
	return Vector3(world_position.x, maxf(world_position.y - 1.0, 0.0), world_position.z)

func _update_player_near() -> void:
	if prompt_label != null:
		if _player_near:
			prompt_label.visible = true
			prompt_label.text = "Press B / Click to open Quest Board"
		else:
			prompt_label.visible = false
			prompt_label.text = "Quest Board"

func _on_player_tile_changed(_new_tile: HexTileData) -> void:
	_player_near = _can_player_open_board()
	_update_player_near()

func _can_player_open_board() -> bool:
	var player_node: Node3D = _get_player_node()
	if player_node == null or not is_instance_valid(player_node):
		return false
	var player_position: Vector3 = player_node.global_position
	var flat_distance: float = Vector2(player_position.x - global_position.x, player_position.z - global_position.z).length()
	return flat_distance <= OPEN_DISTANCE

func _on_area_input_event(_camera: Node, event: InputEvent, _position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		if mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
			if _can_player_open_board():
				_open_board()
			else:
				QuestEvents.message("Move closer to the Quest Board.")

func _open_board() -> void:
	if not _can_player_open_board():
		QuestEvents.message("Move closer to the Quest Board.")
		return
	var board_nodes: Array = get_tree().get_nodes_in_group("quest_board_ui")
	if not board_nodes.is_empty():
		var ui_node: Node = board_nodes[0]
		if ui_node.has_method("open_board"):
			ui_node.call("open_board")
			return
	QuestEvents.message("Quest Board UI is not ready yet.")
