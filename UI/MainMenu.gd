extends Control

@onready var fire_button: Button = $CenterContainer/VBoxContainer/CharacterSettingsContainer/ActorSelection/HBoxContainer/FireButton
@onready var water_button: Button = $CenterContainer/VBoxContainer/CharacterSettingsContainer/ActorSelection/HBoxContainer/WaterButton
@onready var goat_button: Button = $CenterContainer/VBoxContainer/CharacterSettingsContainer/ActorSelection/HBoxContainer/GoatButton
@onready var fire_count_input: SpinBox = $CenterContainer/VBoxContainer/CharacterSettingsContainer/NPCSelection/FireNPCs/FireCount
@onready var water_count_input: SpinBox = $CenterContainer/VBoxContainer/CharacterSettingsContainer/NPCSelection/WaterNPCs/WaterCount
@onready var goat_count_input: SpinBox = $CenterContainer/VBoxContainer/CharacterSettingsContainer/NPCSelection/GoatNPCs/GoatCount
@onready var ranch_button: Button = $CenterContainer/VBoxContainer/RanchButton

@onready var character_settings_container: VBoxContainer = $CenterContainer/VBoxContainer/CharacterSettingsContainer
@onready var map_settings_container: VBoxContainer = $CenterContainer/VBoxContainer/MapSettingsContainer
@onready var size_input: SpinBox = $CenterContainer/VBoxContainer/MapSettingsContainer/ArenaSize/SizeInput
@onready var seed_input: SpinBox = $CenterContainer/VBoxContainer/MapSettingsContainer/WorldGen/NoiseSeed/SeedInput
@onready var random_seed_check: CheckBox = $CenterContainer/VBoxContainer/MapSettingsContainer/WorldGen/NoiseSeed/RandomSeedCheck
@onready var scale_slider: HSlider = $CenterContainer/VBoxContainer/MapSettingsContainer/WorldGen/NoiseScale/ScaleSlider
@onready var scale_value_label: Label = $CenterContainer/VBoxContainer/MapSettingsContainer/WorldGen/NoiseScale/ValueLabel
@onready var height_slider: HSlider = $CenterContainer/VBoxContainer/MapSettingsContainer/WorldGen/HeightStep/HeightSlider
@onready var height_value_label: Label = $CenterContainer/VBoxContainer/MapSettingsContainer/WorldGen/HeightStep/ValueLabel

func _ready() -> void:
	# ... existing initialization ...
	random_seed_check.toggled.connect(_on_random_seed_toggled)
	_on_random_seed_toggled(random_seed_check.button_pressed)
	
	scale_slider.value_changed.connect(_on_scale_changed)
	height_slider.value_changed.connect(_on_height_changed)
	
	# Initialize values from GameSettings
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		size_input.value = gs.grid_width
		fire_count_input.value = gs.fire_count
		water_count_input.value = gs.water_count
		goat_count_input.value = gs.goat_count
		
		seed_input.value = gs.noise_seed
		scale_slider.value = gs.noise_frequency
		height_slider.value = gs.height_step
		
		_on_scale_changed(scale_slider.value)
		_on_height_changed(height_slider.value)
		
		if gs.selected_actor_type == "fire":
			_on_fire_button_pressed()
		elif gs.selected_actor_type == "water":
			_on_water_button_pressed()
		else:
			_on_goat_button_pressed()
	
	# Ensure mouse is visible for the menu
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _on_scale_changed(value: float) -> void:
	if scale_value_label: scale_value_label.text = "%.2f" % value

func _on_height_changed(value: float) -> void:
	if height_value_label: height_value_label.text = "%.1f" % value

func _on_fire_button_pressed() -> void:
	fire_button.button_pressed = true
	water_button.button_pressed = false
	goat_button.button_pressed = false
	var gs = get_node_or_null("/root/GameSettings")
	if gs: gs.selected_actor_type = "fire"

func _on_water_button_pressed() -> void:
	fire_button.button_pressed = false
	water_button.button_pressed = true
	goat_button.button_pressed = false
	var gs = get_node_or_null("/root/GameSettings")
	if gs: gs.selected_actor_type = "water"

func _on_goat_button_pressed() -> void:
	fire_button.button_pressed = false
	water_button.button_pressed = false
	goat_button.button_pressed = true
	var gs = get_node_or_null("/root/GameSettings")
	if gs: gs.selected_actor_type = "goat"

func _on_character_settings_button_pressed() -> void:
	character_settings_container.visible = !character_settings_container.visible

func _on_map_settings_button_pressed() -> void:
	map_settings_container.visible = !map_settings_container.visible

func _on_ranch_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Ranch/Ranch.tscn")

func _on_random_seed_toggled(button_pressed: bool) -> void:
	seed_input.editable = !button_pressed

func _on_play_button_pressed() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		gs.grid_width = int(size_input.value)
		gs.grid_height = int(size_input.value)
		gs.fire_count = int(fire_count_input.value)
		gs.water_count = int(water_count_input.value)
		gs.goat_count = int(goat_count_input.value)
		
		if random_seed_check.button_pressed:
			gs.noise_seed = randi() % 100000
		else:
			gs.noise_seed = int(seed_input.value)
		
		gs.noise_frequency = scale_slider.value
		gs.height_step = height_slider.value
		
		# Persist settings to disk
		gs.save_settings()
		
	get_tree().change_scene_to_file("res://Play Space/Arena.tscn")
