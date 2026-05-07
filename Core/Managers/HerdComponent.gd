class_name HerdComponent
extends Node

## Manages the herd of actors. Actor-type-agnostic — works with any ActorData subclass.

signal herd_state_changed

var herd: Array[ActorData] = []
const MAX_TEAM_SIZE = 4

func initialize(initial_herd: Array[ActorData]) -> void:
	herd = initial_herd
	for actor in herd:
		actor.is_selected = false
		_connect_actor_signals(actor)

func add_goat(actor: ActorData) -> void:
	herd.append(actor)
	_connect_actor_signals(actor)
	GameEvents.herd_updated.emit()
	herd_state_changed.emit()

func remove_goat(actor: ActorData) -> void:
	herd.erase(actor)
	GameEvents.herd_updated.emit()
	herd_state_changed.emit()

func toggle_selection(actor: ActorData) -> bool:
	if actor.is_selected:
		actor.is_selected = false
		GameEvents.actor_selection_toggled.emit(actor, false)
		GameEvents.herd_updated.emit()
		herd_state_changed.emit()
		return true
	
	if actor.is_exhausted:
		return false
		
	var selected = get_selected_goats()
	if selected.size() < MAX_TEAM_SIZE:
		actor.is_selected = true
		GameEvents.actor_selection_toggled.emit(actor, true)
		GameEvents.herd_updated.emit()
		herd_state_changed.emit()
		return true
		
	return false

func get_selected_goats() -> Array[ActorData]:
	var selected: Array[ActorData] = []
	for a in herd:
		if a.is_selected:
			selected.append(a)
	return selected

func _connect_actor_signals(actor: ActorData) -> void:
	if not actor.stats_changed.is_connected(_on_actor_stats_changed):
		actor.stats_changed.connect(_on_actor_stats_changed)

func _on_actor_stats_changed() -> void:
	herd_state_changed.emit()

func generate_starter_herd() -> void:
	var names = ["Bessie", "Billy", "Daisy", "Gurt"]
	for i in range(4):
		var goat = GoatData.new()
		goat.goat_name = names[i]
		goat.gender = ActorData.Gender.FEMALE if i % 2 == 0 else ActorData.Gender.MALE
		goat.base_color = Color(randf(), randf(), randf())
		add_goat(goat)
