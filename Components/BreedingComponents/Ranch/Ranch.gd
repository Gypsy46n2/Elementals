class_name Ranch
extends Control

@onready var does_container: GridContainer = %DoesContainer
@onready var bucks_container: GridContainer = %BucksContainer
@onready var selected_doe_card: Control = %SelectedDoeCard
@onready var selected_buck_card: Control = %SelectedBuckCard
@onready var breed_button: Button = %BreedButton
@onready var next_day_button: Button = %NextDayButton
@onready var back_button: Button = %BackButton
@onready var gold_label: Label = %GoldLabel
@onready var day_label: Label = %DayLabel
@onready var cheat_button: Button = %CheatButton
@onready var cheat_panel: Control = %CheatPanel
@onready var max_level_goat_button: Button = %MaxLevelGoatButton
@onready var close_cheat_button: Button = %CloseCheatButton

var selected_doe: GoatData
var selected_buck: GoatData

func _ready() -> void:
	GameEvents.herd_updated.connect(refresh_ui)
	GameEvents.day_advanced.connect(_on_day_advanced)
	GameEvents.gold_changed.connect(_on_gold_changed)
	
	breed_button.pressed.connect(_on_breed_pressed)
	next_day_button.text = "Enter Arena"
	next_day_button.pressed.connect(_on_enter_arena_pressed)
	back_button.pressed.connect(_on_back_pressed)
	
	cheat_button.pressed.connect(func(): cheat_panel.visible = true)
	close_cheat_button.pressed.connect(func(): cheat_panel.visible = false)
	max_level_goat_button.pressed.connect(_on_max_level_goat_pressed)
	
	refresh_ui()
	_on_gold_changed(HerdManager.gold)
	_on_day_advanced(HerdManager.current_day)
	
	# Ensure mouse is visible
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func refresh_ui() -> void:
	_clear_containers()
	
	# Sort herd by name for stability
	var sorted_herd = HerdManager.herd.duplicate()
	sorted_herd.sort_custom(func(a, b): 
		return a.goat_name < b.goat_name
	)
	
	for goat in sorted_herd:
		var card = preload("res://UI/DisplayCard/ActorCard.tscn").instantiate()
		card.goat_data = goat
		card.selected.connect(_on_goat_selected)
		
		if goat.gender == ActorData.Gender.FEMALE:
			does_container.add_child(card)
		else:
			bucks_container.add_child(card)
	
	_update_breeding_selection()

func _clear_containers() -> void:
	for child in does_container.get_children():
		child.queue_free()
	for child in bucks_container.get_children():
		child.queue_free()
	for child in selected_doe_card.get_children():
		child.queue_free()
	for child in selected_buck_card.get_children():
		child.queue_free()

func _on_goat_selected(goat: GoatData) -> void:
	if goat.gender == ActorData.Gender.FEMALE:
		if selected_doe == goat:
			selected_doe = null
		else:
			selected_doe = goat
	else:
		if selected_buck == goat:
			selected_buck = null
		else:
			selected_buck = goat
	refresh_ui()

func _update_breeding_selection() -> void:
	if selected_doe:
		var card = preload("res://UI/DisplayCard/ActorCard.tscn").instantiate()
		card.goat_data = selected_doe
		selected_doe_card.add_child(card)
		
	if selected_buck:
		var card = preload("res://UI/DisplayCard/ActorCard.tscn").instantiate()
		card.goat_data = selected_buck
		selected_buck_card.add_child(card)
	
	breed_button.disabled = not (selected_doe and selected_buck)
	
	var selected = HerdManager.get_selected_goats()
	# next_day_button.disabled = selected.is_empty() # Allow entering without goats
	# Accessing MAX_TEAM_SIZE from HerdManager autoload instance
	next_day_button.text = "Enter Arena (%d/%d)" % [selected.size(), HerdManager.MAX_TEAM_SIZE]

func _on_enter_arena_pressed() -> void:
	get_tree().change_scene_to_file("res://Play Space/Arena.tscn")

func _on_breed_pressed() -> void:
	if HerdManager.breed(selected_doe, selected_buck):
		selected_doe = null
		selected_buck = null
		refresh_ui()

func _on_next_day_pressed() -> void:
	HerdManager.next_day()

func _on_day_advanced(day: int) -> void:
	day_label.text = "Day: %d" % day

func _on_gold_changed(amount: int) -> void:
	gold_label.text = "Gold: %d" % amount

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file("res://UI/MainMenu.tscn")

func _on_max_level_goat_pressed() -> void:
	var max_goat = GoatData.new()
	max_goat.goat_name = "Mega Goat"
	max_goat.level = 20
	max_goat.gender = ActorData.Gender.MALE if randf() < 0.5 else ActorData.Gender.FEMALE
	max_goat.strength = 20.0
	max_goat.dexterity = 20.0
	max_goat.constitution = 20.0
	max_goat.intelligence = 20.0
	max_goat.wisdom = 20.0
	max_goat.charisma = 20.0
	
	HerdManager.add_goat(max_goat)
	cheat_panel.visible = false
	refresh_ui()
