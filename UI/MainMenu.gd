extends Control

@onready var character_tab_container: VBoxContainer = $CenterContainer/VBoxContainer/CharacterTabContainer
@onready var weapon_tab_container: VBoxContainer = $CenterContainer/VBoxContainer/WeaponTabContainer
@onready var actor_buttons_container: HBoxContainer = %ActorButtons
@onready var map_settings_container: VBoxContainer = $CenterContainer/VBoxContainer/MapSettingsContainer
@onready var size_input: SpinBox = $CenterContainer/VBoxContainer/MapSettingsContainer/ArenaSize/SizeInput
@onready var seed_input: SpinBox = $CenterContainer/VBoxContainer/MapSettingsContainer/WorldGen/NoiseSeed/SeedInput
@onready var random_seed_check: CheckBox = $CenterContainer/VBoxContainer/MapSettingsContainer/WorldGen/NoiseSeed/RandomSeedCheck
@onready var scale_slider: HSlider = $CenterContainer/VBoxContainer/MapSettingsContainer/WorldGen/NoiseScale/ScaleSlider
@onready var scale_value_label: Label = $CenterContainer/VBoxContainer/MapSettingsContainer/WorldGen/NoiseScale/ValueLabel
@onready var height_slider: HSlider = $CenterContainer/VBoxContainer/MapSettingsContainer/WorldGen/HeightStep/HeightSlider
@onready var height_value_label: Label = $CenterContainer/VBoxContainer/MapSettingsContainer/WorldGen/HeightStep/ValueLabel

var selected_actor_path: String = ""

const ACTOR_SCENES: Dictionary = {
	"farmer": "res://Actor/FarmerActor.tscn",
	"fire": "res://Actor/FireActor.tscn",
	"water": "res://Actor/WaterActor.tscn",
	"goat": "res://Actor/GoatActor.tscn",
	"goblin": "res://Actor/GoblinMinion.tscn",
	"scarecrow": "res://Actor/ScarecrowDummy.tscn"
}

func _ready() -> void:
	# Add weapons inventory to the weapon tab
	var inventory = load("res://UI/EquipmentInventory.tscn").instantiate()
	weapon_tab_container.add_child(inventory)
	
	_populate_actor_selection()
	
	random_seed_check.toggled.connect(_on_random_seed_toggled)
	_on_random_seed_toggled(random_seed_check.button_pressed)
	
	scale_slider.value_changed.connect(_on_scale_changed)
	height_slider.value_changed.connect(_on_height_changed)
	
	# Initialize values from GameSettings
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		size_input.value = gs.grid_width
		seed_input.value = gs.noise_seed
		scale_slider.value = gs.noise_frequency
		height_slider.value = gs.height_step
		
		# Set initial actor path from settings if it exists
		if gs.get("selected_actor_type") in ACTOR_SCENES:
			selected_actor_path = ACTOR_SCENES[gs.selected_actor_type]
		else:
			selected_actor_path = ACTOR_SCENES["fire"] # Default
		
		_on_scale_changed(scale_slider.value)
		_on_height_changed(height_slider.value)
	
	# Ensure mouse is visible for the menu
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _populate_actor_selection() -> void:
	for child in actor_buttons_container.get_children():
		child.queue_free()
	
	var gs = get_node_or_null("/root/GameSettings")
	var current_type = gs.selected_actor_type if gs else "fire"
	
	for actor_name in ACTOR_SCENES:
		var btn = Button.new()
		btn.text = actor_name.capitalize()
		btn.custom_minimum_size = Vector2(120, 48)
		btn.toggle_mode = true
		btn.button_pressed = (actor_name == current_type)
		btn.pressed.connect(_on_actor_button_pressed.bind(actor_name))
		actor_buttons_container.add_child(btn)

func _on_actor_button_pressed(actor_name: String) -> void:
	selected_actor_path = ACTOR_SCENES[actor_name]
	
	# Unpress other buttons
	for child in actor_buttons_container.get_children():
		if child is Button and child.text != actor_name.capitalize():
			child.set_pressed_no_signal(false)
		elif child is Button:
			child.set_pressed_no_signal(true)

func _on_scale_changed(value: float) -> void:
	if scale_value_label: scale_value_label.text = "%.2f" % value

func _on_height_changed(value: float) -> void:
	if height_value_label: height_value_label.text = "%.1f" % value

func _on_character_tab_button_pressed() -> void:
	character_tab_container.visible = !character_tab_container.visible
	if character_tab_container.visible:
		weapon_tab_container.visible = false
		map_settings_container.visible = false

func _on_weapon_tab_button_pressed() -> void:
	weapon_tab_container.visible = !weapon_tab_container.visible
	if weapon_tab_container.visible:
		character_tab_container.visible = false
		map_settings_container.visible = false

func _on_map_settings_button_pressed() -> void:
	map_settings_container.visible = !map_settings_container.visible
	if map_settings_container.visible:
		character_tab_container.visible = false
		weapon_tab_container.visible = false

func _on_ranch_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Ranch/Ranch.tscn")

func _on_random_seed_toggled(button_pressed: bool) -> void:
	seed_input.editable = !button_pressed

func _on_play_button_pressed() -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		gs.grid_width = int(size_input.value)
		gs.grid_height = int(size_input.value)
		
		if random_seed_check.button_pressed:
			gs.noise_seed = randi() % 100000
		else:
			gs.noise_seed = int(seed_input.value)
		
		gs.noise_frequency = scale_slider.value
		gs.height_step = height_slider.value
		
		# Find the actor name from the path
		for actor_name in ACTOR_SCENES:
			if ACTOR_SCENES[actor_name] == selected_actor_path:
				gs.selected_actor_type = actor_name.to_lower()
				break
		
		# Persist settings to disk
		gs.save_settings()
		
	get_tree().change_scene_to_file("res://Play Space/Arena.tscn")
