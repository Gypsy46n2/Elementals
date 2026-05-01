class_name DebugOptionsController
extends PopupPanel

signal show_ai_state_labels_changed(enabled: bool)
signal show_arena_metrics_changed(enabled: bool)
signal show_tile_hover_info_changed(enabled: bool)
signal show_weapon_list_changed(enabled: bool)

static var show_ai_state_labels: bool = false:
	set(value):
		if show_ai_state_labels != value:
			show_ai_state_labels = value
			DebugComponent.debug_enabled = value

static var show_arena_metrics: bool = false:
	set(value):
		if show_arena_metrics != value:
			show_arena_metrics = value

static var show_tile_hover_info: bool = false:
	set(value):
		if show_tile_hover_info != value:
			show_tile_hover_info = value

static var show_weapon_list: bool = false:
	set(value):
		if show_weapon_list != value:
			show_weapon_list = value

@onready var ai_state_checkbox: CheckBox = %AIStateCheckBox
@onready var arena_metrics_checkbox: CheckBox = %ArenaMetricsCheckBox
@onready var tile_hover_checkbox: CheckBox = %TileHoverCheckBox
@onready var weapon_list_checkbox: CheckBox = %WeaponListCheckBox

func _ready() -> void:
	ai_state_checkbox.toggled.connect(_on_ai_state_toggled)
	arena_metrics_checkbox.toggled.connect(_on_arena_metrics_toggled)
	tile_hover_checkbox.toggled.connect(_on_tile_hover_toggled)
	weapon_list_checkbox.toggled.connect(_on_weapon_list_toggled)

	ai_state_checkbox.button_pressed = show_ai_state_labels
	arena_metrics_checkbox.button_pressed = show_arena_metrics
	tile_hover_checkbox.button_pressed = show_tile_hover_info
	weapon_list_checkbox.button_pressed = show_weapon_list

func _on_ai_state_toggled(pressed: bool) -> void:
	show_ai_state_labels = pressed
	show_ai_state_labels_changed.emit(pressed)

func _on_arena_metrics_toggled(pressed: bool) -> void:
	show_arena_metrics = pressed
	show_arena_metrics_changed.emit(pressed)

func _on_tile_hover_toggled(pressed: bool) -> void:
	show_tile_hover_info = pressed
	show_tile_hover_info_changed.emit(pressed)

func _on_weapon_list_toggled(pressed: bool) -> void:
	show_weapon_list = pressed
	show_weapon_list_changed.emit(pressed)
