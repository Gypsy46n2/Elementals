class_name WeaponConsole
extends CanvasLayer

@onready var list_panel: PanelContainer = %ListPanel
@onready var debug_list_toggle: CheckBox = %DebugListToggle
var debug_options_dialog: DebugOptionsController

func _ready() -> void:
	debug_options_dialog = load("res://UI/DebugOptionsDialog.tscn").instantiate()
	add_child(debug_options_dialog)

	debug_list_toggle.toggled.connect(_on_debug_list_toggle_toggled)
	debug_options_dialog.show_weapon_list_changed.connect(_on_show_weapon_list_changed)
	debug_options_dialog.popup_hide.connect(_on_debug_options_closed)

	list_panel.visible = DebugOptionsController.show_weapon_list

func _on_debug_list_toggle_toggled(pressed: bool) -> void:
	if pressed:
		debug_options_dialog.popup_centered()
	else:
		debug_options_dialog.hide()

func _on_show_weapon_list_changed(visible: bool) -> void:
	list_panel.visible = visible

func _on_debug_options_closed() -> void:
	debug_list_toggle.button_pressed = false
