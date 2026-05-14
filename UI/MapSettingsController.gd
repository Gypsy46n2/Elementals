class_name MapSettingsController
extends Control

signal settings_changed()
signal play_pressed()

@onready var size_input: SpinBox = $VBoxContainer/ArenaSize/SizeInput
@onready var seed_input: SpinBox = $VBoxContainer/WorldGen/NoiseSeed/SeedInput
@onready var random_seed_check: CheckBox = $VBoxContainer/WorldGen/NoiseSeed/RandomSeedCheck
@onready var scale_slider: HSlider = $VBoxContainer/WorldGen/NoiseScale/ScaleSlider
@onready var scale_value_label: Label = $VBoxContainer/WorldGen/NoiseScale/ValueLabel
@onready var height_slider: HSlider = $VBoxContainer/WorldGen/HeightStep/HeightSlider
@onready var height_value_label: Label = $VBoxContainer/WorldGen/HeightStep/ValueLabel
@onready var dirt_slider: HSlider = $VBoxContainer/WorldGen/DirtThreshold/DirtSlider
@onready var dirt_value_label: Label = $VBoxContainer/WorldGen/DirtThreshold/DirtLabel

func _ready() -> void:
	random_seed_check.toggled.connect(_on_random_seed_toggled)
	scale_slider.value_changed.connect(_on_scale_changed)
	height_slider.value_changed.connect(_on_height_changed)
	dirt_slider.value_changed.connect(_on_dirt_changed)
	
	# Initialize from GameSettings
	_load_from_game_settings()
	
	# Set initial label values
	_on_random_seed_toggled(random_seed_check.button_pressed)
	_on_scale_changed(scale_slider.value)
	_on_height_changed(height_slider.value)
	_on_dirt_changed(dirt_slider.value)

func _load_from_game_settings() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		size_input.value = gs.grid_width
		seed_input.value = gs.noise_seed
		scale_slider.value = gs.noise_frequency
		height_slider.value = gs.height_step
		dirt_slider.value = gs.dirt_threshold

func get_settings() -> Dictionary:
	var gs = get_node_or_null("/root/GameSettings")
	
	var settings := {
		"grid_width": int(size_input.value),
		"grid_height": int(size_input.value),
	}
	
	if random_seed_check.button_pressed:
		settings["noise_seed"] = randi() % 100000
	else:
		settings["noise_seed"] = int(seed_input.value)
	
	settings["noise_frequency"] = scale_slider.value
	settings["height_step"] = height_slider.value
	settings["dirt_threshold"] = dirt_slider.value
	
	return settings

func apply_to_game_settings() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		var settings = get_settings()
		gs.grid_width = settings.grid_width
		gs.grid_height = settings.grid_height
		gs.noise_seed = settings.noise_seed
		gs.noise_frequency = settings.noise_frequency
		gs.height_step = settings.height_step
		gs.dirt_threshold = settings.dirt_threshold

func _on_random_seed_toggled(button_pressed: bool) -> void:
	seed_input.editable = not button_pressed

func _on_scale_changed(value: float) -> void:
	if scale_value_label:
		scale_value_label.text = "%.2f" % value
	settings_changed.emit()

func _on_height_changed(value: float) -> void:
	if height_value_label:
		height_value_label.text = "%.1f" % value
	settings_changed.emit()

func _on_dirt_changed(value: float) -> void:
	if dirt_value_label:
		var normalized = clamp((value + 0.3) / 0.6, 0.0, 1.0)
		dirt_value_label.text = "%.2f" % normalized
	settings_changed.emit()