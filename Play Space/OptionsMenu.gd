class_name OptionsMenu
extends Control

@onready var return_to_menu_button: Button = $PanelContainer/MarginContainer/VBoxContainer/ReturnButton
@onready var close_button: Button = $PanelContainer/MarginContainer/VBoxContainer/CloseButton
@onready var red_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/GoatColorContainer/R/RedSlider
@onready var green_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/GoatColorContainer/G/GreenSlider
@onready var blue_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/GoatColorContainer/B/BlueSlider
@onready var volume_slider: HSlider = $PanelContainer/MarginContainer/VBoxContainer/VolumeContainer/VolumeSlider

func _ready() -> void:
	hide()
	process_mode = PROCESS_MODE_ALWAYS
	
	if return_to_menu_button:
		return_to_menu_button.focus_mode = Control.FOCUS_NONE
		return_to_menu_button.pressed.connect(_on_return_pressed)
	if close_button:
		close_button.focus_mode = Control.FOCUS_NONE
		close_button.pressed.connect(toggle)
	if red_slider:
		red_slider.focus_mode = Control.FOCUS_NONE
		red_slider.value_changed.connect(_on_color_slider_changed)
	if green_slider:
		green_slider.focus_mode = Control.FOCUS_NONE
		green_slider.value_changed.connect(_on_color_slider_changed)
	if blue_slider:
		blue_slider.focus_mode = Control.FOCUS_NONE
		blue_slider.value_changed.connect(_on_color_slider_changed)
	if volume_slider:
		volume_slider.focus_mode = Control.FOCUS_NONE
		volume_slider.value_changed.connect(_on_volume_changed)
		volume_slider.value = GameSettings.master_volume
		_apply_volume(GameSettings.master_volume)

func toggle() -> void:
	visible = !visible
	get_tree().paused = visible
	
	var reticle_layer = get_tree().root.find_child("ReticleLayer", true, false)
	if reticle_layer:
		reticle_layer.visible = !visible
	
	if visible:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		_update_goat_controls()
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

func _update_goat_controls() -> void:
	var arena = get_tree().get_first_node_in_group("arena")
	if arena and "current_controlled_actor" in arena:
		var target = arena.current_controlled_actor
		var is_goat = (target and target.name.to_lower().contains("goat"))
		$PanelContainer/MarginContainer/VBoxContainer/GoatColorContainer.visible = is_goat
		
		if is_goat:
			var gc = target.get_node_or_null("GeneticComponent")
			if gc and gc.goat_data:
				var color = gc.goat_data.base_color
				red_slider.value = color.r
				green_slider.value = color.g
				blue_slider.value = color.b

func _on_color_slider_changed(_value: float) -> void:
	var arena = get_tree().get_first_node_in_group("arena")
	if arena and "current_controlled_actor" in arena:
		var target = arena.current_controlled_actor
		if target:
			var gc = target.get_node_or_null("GeneticComponent")
			if gc and gc.goat_data:
				gc.goat_data.base_color = Color(red_slider.value, green_slider.value, blue_slider.value)

func _on_return_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://UI/MainMenu.tscn")

func _on_volume_changed(value: float) -> void:
	GameSettings.master_volume = value
	GameSettings.save_settings()
	_apply_volume(value)

func _apply_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value))

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var board_nodes: Array = get_tree().get_nodes_in_group("quest_board_ui")
		for node in board_nodes:
			if node.has_method("is_open") and node.call("is_open"):
				return
		toggle()
		get_viewport().set_input_as_handled()
