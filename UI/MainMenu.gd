extends Control

@onready var character_tab_container: VBoxContainer = $CenterContainer/VBoxContainer/CharacterTabContainer
@onready var weapon_tab_container: VBoxContainer = $CenterContainer/VBoxContainer/WeaponTabContainer
@onready var character_cards_container: HBoxContainer = $CenterContainer/VBoxContainer/CharacterTabContainer/ActorSelection/CharacterCards
@onready var map_settings_container: VBoxContainer = $CenterContainer/VBoxContainer/MapSettingsContainer
@onready var size_input: SpinBox = $CenterContainer/VBoxContainer/MapSettingsContainer/ArenaSize/SizeInput
@onready var seed_input: SpinBox = $CenterContainer/VBoxContainer/MapSettingsContainer/WorldGen/NoiseSeed/SeedInput
@onready var random_seed_check: CheckBox = $CenterContainer/VBoxContainer/MapSettingsContainer/WorldGen/NoiseSeed/RandomSeedCheck
@onready var scale_slider: HSlider = $CenterContainer/VBoxContainer/MapSettingsContainer/WorldGen/NoiseScale/ScaleSlider
@onready var scale_value_label: Label = $CenterContainer/VBoxContainer/MapSettingsContainer/WorldGen/NoiseScale/ValueLabel
@onready var height_slider: HSlider = $CenterContainer/VBoxContainer/MapSettingsContainer/WorldGen/HeightStep/HeightSlider
@onready var height_value_label: Label = $CenterContainer/VBoxContainer/MapSettingsContainer/WorldGen/HeightStep/ValueLabel
@onready var dirt_slider: HSlider = $CenterContainer/VBoxContainer/MapSettingsContainer/WorldGen/DirtThreshold/DirtSlider
@onready var dirt_value_label: Label = $CenterContainer/VBoxContainer/MapSettingsContainer/WorldGen/DirtThreshold/ValueLabel

var selected_actor_path: String = ""

const ACTOR_SCENES: Dictionary = {
	"farmer": "res://Actor/FarmerActor.tscn",
	"fire": "res://Actor/FireActor.tscn",
	"water": "res://Actor/WaterActor.tscn",
	"goat": "res://Actor/GoatActor.tscn",
	"goblin": "res://Actor/GoblinMinion.tscn",
	"scarecrow": "res://Actor/ScarecrowDummy.tscn"
}

var CHARACTER_EQUIPMENT: Dictionary = {}

func _init() -> void:
	# Initialize CHARACTER_EQUIPMENT at runtime so we can call functions
	CHARACTER_EQUIPMENT = {
		"goblin": {
			"weapons": ["Dagger", "Scimitar", "Shortbow"],
			"abilities": _get_goblin_abilities(),
			"armor": ["None", "Leather", "Chain Shirt"]
		},
		"farmer": {
			"weapons": ["Pitchfork", "Shovel", "None"],
			"abilities": ["Repair", "Calm Animal"],
			"armor": ["Clothes", "Leather Apron"]
		},
		"goat": {
			"weapons": ["Headbutt"],
			"abilities": _get_goat_abilities(),
			"armor": ["Fur"]
		},
		"scarecrow": {
			"weapons": ["Scythe", "Pitchfork"],
			"abilities": ["Intimidate", "Scare"],
			"armor": ["Straw"]
		},
		"fire": {
			"weapons": ["Flame Burst"],
			"abilities": ["Fireball", "Flame Wall"],
			"armor": ["Magma Shell"]
		},
		"water": {
			"weapons": ["Water Jet"],
			"abilities": ["Tidal Wave", "Healing Waters"],
			"armor": ["Water Shield"]
		}
	}

## Dynamically get ability names from actual ability component scripts
func _get_goblin_abilities() -> Array:
	var abilities: Array = []
	# Read ability names from actual NimbleEscape script
	var nimble_script = load("res://Components/ActorComponents/AbilityComponents/NimbleEscape.gd")
	if nimble_script:
		# Create a temporary instance to read ability_name
		var temp_actor = Actor.new()
		var temp_component = Node.new()
		var nimble_instance = nimble_script.new(temp_actor, temp_component)
		if nimble_instance and "ability_name" in nimble_instance:
			abilities.append(nimble_instance.ability_name)
		# Cleanup
		temp_actor.free()
		temp_component.free()
	# RedirectAttack is also available but randomly selected at runtime
	# For display purposes, show both possible abilities
	var redirect_script = load("res://Components/ActorComponents/AbilityComponents/RedirectAttack.gd")
	if redirect_script:
		var temp_actor = Actor.new()
		var temp_component = Node.new()
		var redirect_instance = redirect_script.new(temp_actor, temp_component)
		if redirect_instance and "ability_name" in redirect_instance and redirect_instance.ability_name not in abilities:
			abilities.append(redirect_instance.ability_name)
		temp_actor.free()
		temp_component.free()
	return abilities

func _get_goat_abilities() -> Array:
	var abilities: Array = []
	var goat_script = load("res://Components/ActorComponents/AbilityComponents/GoatCharge.gd")
	if goat_script:
		var temp_actor = Actor.new()
		var temp_component = Node.new()
		var goat_instance = goat_script.new(temp_actor, temp_component)
		if goat_instance and "ability_name" in goat_instance:
			abilities.append(goat_instance.ability_name)
		temp_actor.free()
		temp_component.free()
	return abilities

# Goblin base stats (for reference in info display)
const GOBLIN_STATS: Dictionary = {
	"hp": 7.0, "max_hp": 7.0,
	"ac": 12,
	"stealth": 6,
	"perception": 9,
	"str": -1, "dex": 2, "con": 0,
	"int": -1, "wis": 0, "cha": -1
}

var character_cards: Dictionary = {}
var selected_character: String = "goblin"

func _ready() -> void:
	# Add weapons inventory to the weapon tab
	var inventory = load("res://UI/EquipmentInventory.tscn").instantiate()
	weapon_tab_container.add_child(inventory)
	
	_populate_character_cards()
	
	random_seed_check.toggled.connect(_on_random_seed_toggled)
	_on_random_seed_toggled(random_seed_check.button_pressed)
	
	scale_slider.value_changed.connect(_on_scale_changed)
	height_slider.value_changed.connect(_on_height_changed)
	dirt_slider.value_changed.connect(_on_dirt_changed)
	
	# Initialize values from GameSettings
	var gs = get_node_or_null("/root/GameSettings")
	if gs:
		size_input.value = gs.grid_width
		seed_input.value = gs.noise_seed
		scale_slider.value = gs.noise_frequency
		height_slider.value = gs.height_step
		dirt_slider.value = gs.dirt_threshold
		
		# Set initial actor path from settings if it exists
		if gs.get("selected_actor_type") in ACTOR_SCENES:
			selected_actor_path = ACTOR_SCENES[gs.selected_actor_type]
		else:
			selected_actor_path = ACTOR_SCENES["fire"] # Default
		
		_on_scale_changed(scale_slider.value)
		_on_height_changed(height_slider.value)
		_on_dirt_changed(dirt_slider.value)
	
	# Ensure mouse is visible for the menu
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	
	_style_all_buttons()

func _style_all_buttons() -> void:
	var container: VBoxContainer = $CenterContainer/VBoxContainer
	for child in container.find_children("*", "Button", true):
		if child is Button:
			UIStyle.apply_button_theme(child as Button)

func _populate_character_cards() -> void:
	# Clear existing cards
	for child in character_cards_container.get_children():
		child.queue_free()
	character_cards.clear()
	
	var gs = get_node_or_null("/root/GameSettings")
	var current_type = gs.selected_actor_type if gs else "goblin"
	
	var card_scene = load("res://UI/CharacterSelectCard.tscn")
	
	for actor_name in ACTOR_SCENES:
		var card = card_scene.instantiate()
		var equipment = CHARACTER_EQUIPMENT.get(actor_name, {"weapons": [], "abilities": [], "armor": []})
		
		# Set stats (using goblin stats for all for now, could be expanded per character)
		var stats_dict = null
		if actor_name == "goblin":
			stats_dict = GOBLIN_STATS
		
		card.character_selected.connect(_on_character_selected.bind(actor_name))
		card.equipment_changed.connect(_on_equipment_changed)
		
		character_cards_container.add_child(card)
		character_cards[actor_name] = card
		
		# Call setup deferred so @onready variables are initialized
		var selected = actor_name == current_type
		# Determine saved equipment indices for this actor
		var saved_weapon = 0
		var saved_ability = 0
		var saved_armor = 0
		if gs and actor_name == gs.selected_actor_type:
			saved_weapon = gs.selected_weapon_index
			saved_ability = gs.selected_ability_index
			saved_armor = gs.selected_armor_index
		
		card.call_deferred("setup",
			actor_name.capitalize(),
			Array(equipment.get("weapons", [])),
			Array(equipment.get("abilities", [])),
			Array(equipment.get("armor", [])),
			selected,
			saved_weapon,
			saved_ability,
			saved_armor
		)
		
		# Set stats after setup (call_deferred for non-signal methods)
		if actor_name == "goblin":
			card.call_deferred("set_stats", GOBLIN_STATS)
	
	# Select the initial character
	selected_character = current_type
	_update_card_selections()

func _on_character_selected(actor_name: String) -> void:
	selected_character = actor_name
	_update_card_selections()
	
	# Update selected actor path
	if actor_name in ACTOR_SCENES:
		selected_actor_path = ACTOR_SCENES[actor_name]

func _on_equipment_changed(actor_name: String, weapon_index: int, ability_index: int, armor_index: int) -> void:
	var gs = get_node_or_null("/root/GameSettings")
	if gs and actor_name == selected_character:
		gs.selected_weapon_index = weapon_index
		gs.selected_ability_index = ability_index
		gs.selected_armor_index = armor_index

func _update_card_selections() -> void:
	for actor_name in character_cards:
		var card = character_cards[actor_name]
		if card and card is CharacterSelectCard:
			card.is_selected_card = (actor_name == selected_character)

func _on_scale_changed(value: float) -> void:
	if scale_value_label: scale_value_label.text = "%.2f" % value

func _on_height_changed(value: float) -> void:
	if height_value_label: height_value_label.text = "%.1f" % value

func _on_dirt_changed(value: float) -> void:
	if dirt_value_label:
		var normalized = clamp((value + 0.3) / 0.6, 0.0, 1.0)
		dirt_value_label.text = "%.2f" % normalized

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
	get_tree().change_scene_to_file("res://Components/BreedingComponents/Ranch/Ranch.tscn")

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
		gs.dirt_threshold = dirt_slider.value
		
		# Find the actor name from the path
		for actor_name in ACTOR_SCENES:
			if ACTOR_SCENES[actor_name] == selected_actor_path:
				gs.selected_actor_type = actor_name.to_lower()
				break
		
		# Get equipment selection from card
		if selected_character in character_cards:
			var card = character_cards[selected_character]
			var equipment = card.get_selected_equipment()
			gs.selected_weapon_index = equipment.weapon_index
			gs.selected_ability_index = equipment.ability_index
			gs.selected_armor_index = equipment.armor_index
		
		# Persist settings to disk
		gs.save_settings()
		
	get_tree().change_scene_to_file("res://Play Space/Arena.tscn")
