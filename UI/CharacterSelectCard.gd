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
var available_weapons: Array = []
var available_abilities: Array = []
var available_armor: Array = []

var current_weapon_index: int = 0
var current_ability_index: int = 0
var current_armor_index: int = 0

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
	
	_update_display()
	_update_selection_style()

func setup(p_actor_name: String, p_weapons, p_abilities, p_armor, p_selected: bool = false, p_weapon_index: int = 0, p_ability_index: int = 0, p_armor_index: int = 0) -> void:
	actor_name = p_actor_name
	available_weapons = p_weapons
	available_abilities = p_abilities
	available_armor = p_armor
	
	name_label.text = actor_name.capitalize()
	
	# Use saved indices if valid, otherwise default to 0
	current_weapon_index = clampi(p_weapon_index, 0, max(0, available_weapons.size() - 1))
	current_ability_index = clampi(p_ability_index, 0, max(0, available_abilities.size() - 1))
	current_armor_index = clampi(p_armor_index, 0, max(0, available_armor.size() - 1))
	
	_update_display()

func _update_display() -> void:
	_update_weapon_button()
	_update_ability_button()
	_update_armor_button()
	_update_stats_visibility()

func _update_weapon_button() -> void:
	if available_weapons.size() > 0:
		weapon_button.text = "<< %s >>" % available_weapons[current_weapon_index]
		weapon_button.disabled = available_weapons.size() <= 1
	else:
		weapon_button.text = "<< No Weapons >>"
		weapon_button.disabled = true

func _update_ability_button() -> void:
	if available_abilities.size() > 0:
		ability_button.text = "<< %s >>" % available_abilities[current_ability_index]
		ability_button.disabled = available_abilities.size() <= 1
	else:
		ability_button.text = "<< No Abilities >>"
		ability_button.disabled = true

func _update_armor_button() -> void:
	if available_armor.size() > 0:
		armor_button.text = "<< %s >>" % available_armor[current_armor_index]
		armor_button.disabled = available_armor.size() <= 1
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
	current_weapon_index = wrapi(current_weapon_index - 1, 0, available_weapons.size())
	_update_weapon_button()
	equipment_changed.emit(actor_name, current_weapon_index, current_ability_index, current_armor_index)

func _on_ability_meta_pressed() -> void:
	current_ability_index = wrapi(current_ability_index - 1, 0, available_abilities.size())
	_update_ability_button()
	equipment_changed.emit(actor_name, current_weapon_index, current_ability_index, current_armor_index)

func _on_armor_meta_pressed() -> void:
	current_armor_index = wrapi(current_armor_index - 1, 0, available_armor.size())
	_update_armor_button()
	equipment_changed.emit(actor_name, current_weapon_index, current_ability_index, current_armor_index)

func _on_card_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			# Select this card
			character_selected.emit(actor_name)

func cycle_weapon() -> void:
	if available_weapons.size() > 1:
		current_weapon_index = wrapi(current_weapon_index + 1, 0, available_weapons.size())
		_update_weapon_button()
		equipment_changed.emit(actor_name, current_weapon_index, current_ability_index, current_armor_index)

func cycle_ability() -> void:
	if available_abilities.size() > 1:
		current_ability_index = wrapi(current_ability_index + 1, 0, available_abilities.size())
		_update_ability_button()
		equipment_changed.emit(actor_name, current_weapon_index, current_ability_index, current_armor_index)

func cycle_armor() -> void:
	if available_armor.size() > 1:
		current_armor_index = wrapi(current_armor_index + 1, 0, available_armor.size())
		_update_armor_button()
		equipment_changed.emit(actor_name, current_weapon_index, current_ability_index, current_armor_index)

func get_selected_equipment() -> Dictionary:
	return {
		"weapon_index": current_weapon_index,
		"ability_index": current_ability_index,
		"armor_index": current_armor_index
	}
