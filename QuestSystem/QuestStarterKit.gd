extends Node

var arena: Node = null

func setup(p_arena: Node) -> void:
	arena = p_arena
	_install()

func _ready() -> void:
	if arena == null:
		arena = get_parent()
	_install()

func _install() -> void:
	if arena == null:
		return
	# Ensure clean slate for discovery-based system
	QuestState.active_quests.clear()
	
	_ensure_spawn_manager()
	_ensure_tile_signal_component()
	_ensure_board_ui()
	call_deferred("_ensure_world_board")

func _ensure_tile_signal_component() -> void:
	if arena.has_node("TileSignalComponent"):
		return
	var node: Node = Node.new()
	node.name = "TileSignalComponent"
	node.set_script(load("res://Components/Arena/TileSignalComponent.gd"))
	arena.add_child(node)
	if node.has_method("setup"):
		node.call("setup", arena)

func _ensure_spawn_manager() -> void:
	if arena.has_node("QuestSpawnManager"):
		return
	var node: Node = Node.new()
	node.name = "QuestSpawnManager"
	node.set_script(load("res://QuestSystem/QuestSpawnManager.gd"))
	arena.add_child(node)
	if node.has_method("setup"):
		node.call("setup", arena)

func _ensure_board_ui() -> void:
	if arena.has_node("QuestBoardUI"):
		return
	var board_ui: CanvasLayer = CanvasLayer.new()
	board_ui.name = "QuestBoardUI"
	board_ui.set_script(load("res://QuestSystem/QuestBoardUI.gd"))
	arena.add_child(board_ui)

func _ensure_world_board() -> void:
	if arena == null or not is_instance_valid(arena):
		return
	if arena.has_node("QuestBoard3D"):
		return
	var board: Node3D = Node3D.new()
	board.name = "QuestBoard3D"
	board.set_script(load("res://QuestSystem/QuestBoard3D.gd"))
	arena.add_child(board)
	if board.has_method("setup"):
		board.call("setup", arena)
