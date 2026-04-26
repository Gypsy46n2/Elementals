class_name DisplayCardBase
extends PanelContainer

signal selected(data: Resource)

@export var highlight_color: Color = Color(0.8, 1.0, 0.8)
@export var base_color: Color = Color.WHITE
@export var hover_color: Color = Color(0.9, 0.9, 0.9)

var data_resource: Resource:
	set(v):
		data_resource = v
		if is_node_ready():
			_update_ui()

func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	gui_input.connect(_on_gui_input)

func setup(p_data: Resource) -> void:
	data_resource = p_data
	_update_ui()

func _update_ui() -> void:
	# Virtual method to be overridden by subclasses
	pass

func _on_mouse_entered() -> void:
	if not _is_selected():
		modulate = hover_color

func _on_mouse_exited() -> void:
	if not _is_selected():
		modulate = base_color

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_handle_selection()
		accept_event()

func _handle_selection() -> void:
	selected.emit(data_resource)
	_update_ui()

func _is_selected() -> bool:
	# Subclasses should define what 'selected' means for their specific data
	return false

func update_visual_state() -> void:
	if _is_selected():
		modulate = highlight_color
	else:
		modulate = base_color
