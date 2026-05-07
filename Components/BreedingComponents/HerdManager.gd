extends Node

## HerdManager orchestrates herd, economy, and progression systems.
## Delegating work to specialized components to avoid god-object patterns.
## This manager is actor-type-agnostic — it works with any ActorData subclass.

# Components
var herd_manager: HerdComponent
var economy_manager: EconomyComponent
var progression_manager: ProgressionComponent
var save_manager: SaveComponent
var breeding_manager: BreedingComponent

var herd: Array[ActorData]:
	get: return herd_manager.herd

var gold: int:
	get: return economy_manager.gold
	set(v): economy_manager.gold = v

var current_day: int:
	get: return progression_manager.current_day

const MAX_TEAM_SIZE = 4

func _ready() -> void:
	randomize()
	_setup_components()
	_load_initial_state()
	_connect_signals()

func _setup_components() -> void:
	herd_manager = preload("res://Core/Managers/HerdComponent.gd").new()
	herd_manager.name = "HerdComponent"
	add_child(herd_manager)
	
	economy_manager = preload("res://Core/Managers/EconomyComponent.gd").new()
	economy_manager.name = "EconomyComponent"
	add_child(economy_manager)
	
	progression_manager = preload("res://Core/Managers/ProgressionComponent.gd").new()
	progression_manager.name = "ProgressionComponent"
	add_child(progression_manager)
	
	save_manager = preload("res://Core/Managers/SaveComponent.gd").new()
	save_manager.name = "SaveComponent"
	add_child(save_manager)
	
	breeding_manager = preload("res://Core/Managers/BreedingComponent.gd").new()
	breeding_manager.name = "BreedingComponent"
	add_child(breeding_manager)

func _load_initial_state() -> void:
	var save_data: GoatSaveData = save_manager.load_game()
	if save_data:
		herd_manager.initialize(save_data.herd)
		economy_manager.initialize(save_data.gold)
		progression_manager.initialize(save_data.current_day)
	else:
		herd_manager.generate_starter_herd()
		save_game()

func _connect_signals() -> void:
	# Wire up auto-saving on relevant events
	GameEvents.herd_updated.connect(save_game)
	GameEvents.day_advanced.connect(func(_d): save_game())
	GameEvents.gold_changed.connect(func(_g): save_game())
	herd_manager.herd_state_changed.connect(save_game)

# --- Delegate Methods ---

func toggle_selection(actor: ActorData) -> bool:
	return herd_manager.toggle_selection(actor)

func get_selected_goats() -> Array[ActorData]:
	return herd_manager.get_selected_goats()

func add_goat(actor: ActorData) -> void:
	herd_manager.add_goat(actor)

func remove_goat(actor: ActorData) -> void:
	herd_manager.remove_goat(actor)

func sell_goat(actor: ActorData) -> void:
	# Cast to GoatData for goat-specific property, but design supports any ActorData
	var goat = actor as GoatData
	if goat:
		economy_manager.gold += goat.gold_value
	remove_goat(actor)

func breed(parent_a: ActorData, parent_b: ActorData) -> bool:
	return breeding_manager.breed(parent_a, parent_b)

func next_day() -> void:
	progression_manager.advance_day(herd_manager.herd)
	
	# Process pregnancies with generic handler
	var new_kids: Array[ActorData] = breeding_manager.process_pregnancy(herd_manager.herd)
	for kid in new_kids:
		# For now, add as GoatData if possible; future types may have their own handlers
		var goat_kid = kid as GoatData
		if goat_kid:
			add_goat(goat_kid)
		# TODO: Add handlers for other actor types (GoblinData, ElementalData, etc.)
	
	# Any other day-transition logic...
	GameEvents.herd_updated.emit()

func save_game() -> void:
	save_manager.save_game(herd_manager.herd, economy_manager.gold, progression_manager.current_day)
