class_name CharacterSelectCard
extends Control

signal character_selected(actor_name: String)
signal equipment_changed(actor_name: String, weapon_index: int, ability_index: int, armor_index: int)

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var model_container: Control = $VBoxContainer/ModelContainer
@onready var weapon_button: Button = $VBoxContainer/WeaponButton
@onready var ability_button: Button = $VBoxContainer/AbilityButton
@onready var armor_button: Button = $VBoxContainer/ArmorButton
@onready var info_button: Button = $VBoxContainer/InfoButton
@onready var stats_container: Control = $VBoxContainer/StatsContainer
@onready var selection_indicator: Control = $SelectionIndicator

var actor_name: String = ""

# Cycling state using stationary cyclers (from CyclingComponent autoload)
var _weapon_cycler: CyclingComponent.StationaryCycler = CyclingComponent.StationaryCycler.new()
var _ability_cycler: CyclingComponent.StationaryCycler = CyclingComponent.StationaryCycler.new()
var _armor_cycler: CyclingComponent.StationaryCycler = CyclingComponent.StationaryCycler.new()

# Expose current indices for external access (read-only via getters)
var current_weapon_index: int:
	get: return _weapon_cycler.current_index
var current_ability_index: int:
	get: return _ability_cycler.current_index
var current_armor_index: int:
	get: return _armor_cycler.current_index

var is_selected_card: bool = false:
	set(v):
		is_selected_card = v
		_update_selection_style()

var show_stats: bool = false:
	set(v):
		show_stats = v
		_update_stats_visibility()

# Stats for display when info is shown
var hp: float = 0.0
var max_hp: float = 0.0
var mana: float = 0.0
var max_mana: float = 0.0
var armor_class: int = 10
var stealth: int = 0
var passive_perception: int = 10
var strength: int = 0
var dexterity: int = 0
var constitution: int = 0
var intelligence: int = 0
var wisdom: int = 0
var charisma: int = 0

func _ready() -> void:
	weapon_button.pressed.connect(_on_weapon_pressed)
	ability_button.pressed.connect(_on_ability_pressed)
	armor_button.pressed.connect(_on_armor_pressed)
	info_button.pressed.connect(_on_info_pressed)
	
	# Connect click to select (handles left/right click for cycling)
	gui_input.connect(_on_card_input)
	
	# Make ModelContainer also handle selection clicks
	model_container.gui_input.connect(_on_model_container_input)
	
	_update_display()
	_update_selection_style()

func setup(p_actor_name: String, p_weapons, p_abilities, p_armor, p_selected: bool = false, p_weapon_index: int = 0, p_ability_index: int = 0, p_armor_index: int = 0) -> void:
	actor_name = p_actor_name
	name_label.text = actor_name.capitalize()
	
	# Initialize cyclers with items and saved indices
	_weapon_cycler.set_items(p_weapons)
	_weapon_cycler.set_index(clampi(p_weapon_index, 0, max(0, _weapon_cycler.items.size() - 1)))
	
	_ability_cycler.set_items(p_abilities)
	_ability_cycler.set_index(clampi(p_ability_index, 0, max(0, _ability_cycler.items.size() - 1)))
	
	_armor_cycler.set_items(p_armor)
	_armor_cycler.set_index(clampi(p_armor_index, 0, max(0, _armor_cycler.items.size() - 1)))
	
	_set_character_sprite()
	_update_display()

func _set_character_sprite() -> void:
	var sprite = model_container.get_node_or_null("Sprite2D") as Sprite2D
	if not sprite:
		return
	
	# Map actor names to their image resources
	var clean_name = actor_name.strip_edges().to_lower()
	match clean_name:
		"farmer":
			sprite.texture = preload("res://assets/BigImages/Farmer.png")
		"goat":
			sprite.texture = preload("res://assets/BigImages/Screaming Goat.png")
		"goblin":
			sprite.texture = preload("res://assets/BigImages/NastyGobbo.png")
		"fire":
			sprite.texture = preload("res://assets/generated/Fire Elemental_frame_0.png")
		"water":
			sprite.texture = preload("res://assets/generated/Water Elemental_frame_0.png")
		"mimic":
			sprite.texture = preload("res://assets/BigImages/MimicChest.png")
		"scarecrow":
			sprite.texture = preload("res://assets/generated/Scarecrow Character_frame_0.png")
		_:
			print("CharacterSelectCard: No specific image mapping for: '", clean_name, "'")
			# Try to load a generic one or keep default
			pass 
	
	if sprite.texture:
		# Center the sprite in the ModelContainer (100x100)
		sprite.centered = true
		sprite.position = Vector2(50, 50)
		
		# Scale to fit (target ~90px)
		var tex_size = sprite.texture.get_size()
		var max_dim = max(tex_size.x, tex_size.y)
		if max_dim > 0:
			var target_size = 90.0
			sprite.scale = Vector2(target_size / max_dim, target_size / max_dim)

func _update_display() -> void:
	_update_weapon_button()
	_update_ability_button()
	_update_armor_button()
	_update_stats_visibility()

func _update_weapon_button() -> void:
	var items = _weapon_cycler.items
	var idx = _weapon_cycler.current_index
	if items.size() > 0:
		weapon_button.text = "<< %s >>" % items[idx]
		weapon_button.disabled = items.size() <= 1
	else:
		weapon_button.text = "<< No Weapons >>"
		weapon_button.disabled = true

func _update_ability_button() -> void:
	var items = _ability_cycler.items
	var idx = _ability_cycler.current_index
	if items.size() > 0:
		ability_button.text = "<< %s >>" % items[idx]
		ability_button.disabled = items.size() <= 1
	else:
		ability_button.text = "<< No Abilities >>"
		ability_button.disabled = true

func _update_armor_button() -> void:
	var items = _armor_cycler.items
	var idx = _armor_cycler.current_index
	if items.size() > 0:
		armor_button.text = "<< %s >>" % items[idx]
		armor_button.disabled = items.size() <= 1
	else:
		armor_button.text = "<< No Armor >>"
		armor_button.disabled = true

func _update_stats_visibility() -> void:
	stats_container.visible = show_stats

func _update_selection_style() -> void:
	if selection_indicator:
		selection_indicator.visible = is_selected_card
	
	if is_selected_card:
		modulate = Color(1.2, 1.2, 1.0)  # Slightly brighter when selected
	else:
		modulate = Color(1.0, 1.0, 1.0)

func _update_stats_display() -> void:
	if not is_node_ready(): return
	
	var hp_label = $VBoxContainer/StatsContainer/HPLabel as Label
	var ac_label = $VBoxContainer/StatsContainer/ACLabel as Label
	
	if hp_label:
		hp_label.text = "HP: %.0f/%.0f" % [hp, max_hp]
	if ac_label:
		ac_label.text = "AC: %d" % armor_class
	
	# Update special stats
	var stealth_label = $VBoxContainer/StatsContainer/StealthLabel as Label
	var perception_label = $VBoxContainer/StatsContainer/PerceptionLabel as Label
	if stealth_label:
		stealth_label.text = "Stealth: +%d" % stealth if stealth >= 0 else "Stealth: %d" % stealth
	if perception_label:
		perception_label.text = "Perception: %d" % passive_perception
	
	var stats_grid = $VBoxContainer/StatsContainer/StatsGrid
	if stats_grid:
		var str_label = stats_grid.get_node_or_null("StrLabel") as Label
		var dex_label = stats_grid.get_node_or_null("DexLabel") as Label
		var con_label = stats_grid.get_node_or_null("ConLabel") as Label
		var int_label = stats_grid.get_node_or_null("IntLabel") as Label
		var wis_label = stats_grid.get_node_or_null("WisLabel") as Label
		var cha_label = stats_grid.get_node_or_null("ChaLabel") as Label
		
		if str_label: str_label.text = "STR: %+d" % strength
		if dex_label: dex_label.text = "DEX: %+d" % dexterity
		if con_label: con_label.text = "CON: %+d" % constitution
		if int_label: int_label.text = "INT: %+d" % intelligence
		if wis_label: wis_label.text = "WIS: %+d" % wisdom
		if cha_label: cha_label.text = "CHA: %+d" % charisma

func set_stats(p_stats: Dictionary) -> void:
	hp = p_stats.get("hp", 0.0)
	max_hp = p_stats.get("max_hp", 0.0)
	armor_class = p_stats.get("ac", 10)
	stealth = p_stats.get("stealth", 0)
	passive_perception = p_stats.get("perception", 10)
	strength = p_stats.get("strength", 10)
	dexterity = p_stats.get("dexterity", 10)
	constitution = p_stats.get("constitution", 10)
	intelligence = p_stats.get("intelligence", 10)
	wisdom = p_stats.get("wisdom", 10)
	charisma = p_stats.get("charisma", 10)
	_update_stats_display()

func _on_weapon_pressed() -> void:
	cycle_weapon()

func _on_ability_pressed() -> void:
	cycle_ability()

func _on_armor_pressed() -> void:
	cycle_armor()

func _on_info_pressed() -> void:
	show_stats = !show_stats

func _on_weapon_meta_pressed() -> void:
	# Meta button (right click) cycles backward
	_weapon_cycler.cycle_backward()
	_update_weapon_button()
	_emit_equipment_changed()

func _on_ability_meta_pressed() -> void:
	_ability_cycler.cycle_backward()
	_update_ability_button()
	_emit_equipment_changed()

func _on_armor_meta_pressed() -> void:
	_armor_cycler.cycle_backward()
	_update_armor_button()
	_emit_equipment_changed()

func _on_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			character_selected.emit(actor_name)

func _on_model_container_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			character_selected.emit(actor_name)

func cycle_weapon() -> void:
	if _weapon_cycler.cycle_forward():
		_update_weapon_button()
		_emit_equipment_changed()

func cycle_ability() -> void:
	if _ability_cycler.cycle_forward():
		_update_ability_button()
		_emit_equipment_changed()

func cycle_armor() -> void:
	if _armor_cycler.cycle_forward():
		_update_armor_button()
		_emit_equipment_changed()

func _emit_equipment_changed() -> void:
	equipment_changed.emit(
		actor_name.to_lower(),
		_weapon_cycler.current_index,
		_ability_cycler.current_index,
		_armor_cycler.current_index
	)

func get_selected_equipment() -> Dictionary:
	return {
		"weapon_index": current_weapon_index,
		"ability_index": current_ability_index,
		"armor_index": current_armor_index
	}
