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
const NET_CAPTURE_CHANCE: float = 0.5
const NET_DISABLE_DURATION: float = 1.6
const NET_CLOSE_RANGE: float = 2.6
const NET_THROW_RANGE: float = 12.0
const NET_THROW_IMPACT_RADIUS: float = 2.4

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

# --- Capture ---

func attempt_capture_with_net(capturer: Actor, target_position: Vector3, reach: float = NET_THROW_RANGE) -> Dictionary:
	return throw_net_at(capturer, target_position, reach, NET_THROW_IMPACT_RADIUS)

func use_net_close(capturer: Actor, target_position: Vector3 = Vector3.ZERO, use_target_position: bool = false, max_distance: float = NET_CLOSE_RANGE) -> Dictionary:
	if capturer == null or not is_instance_valid(capturer):
		return _capture_result(false, false, "Invalid capturer.", 0, 0.0, false)
	
	var search_center: Vector3 = capturer.global_position
	var point_radius: float = max_distance
	if use_target_position:
		search_center = target_position
		point_radius = 1.8
	
	var target: Actor = _find_capture_target(capturer, search_center, max_distance, point_radius)
	if target == null:
		_emit_capture_message("No capture target in range.")
		return _capture_result(false, false, "No valid target nearby.", 0, NET_CAPTURE_CHANCE, false)
	
	return _resolve_capture_attempt(capturer, target)

func throw_net_at(capturer: Actor, target_position: Vector3, max_distance: float = NET_THROW_RANGE, impact_radius: float = NET_THROW_IMPACT_RADIUS) -> Dictionary:
	if capturer == null or not is_instance_valid(capturer):
		return _capture_result(false, false, "Invalid capturer.", 0, 0.0, false)
	
	var target: Actor = _find_capture_target(capturer, target_position, max_distance, impact_radius)
	if target == null:
		_emit_capture_message("Net missed. No capture target hit.")
		return _capture_result(false, false, "No valid target at net impact.", 0, NET_CAPTURE_CHANCE, false)
	
	return _resolve_capture_attempt(capturer, target)

func _resolve_capture_attempt(capturer: Actor, target: Actor) -> Dictionary:
	if not _is_capture_candidate(capturer, target):
		_emit_capture_message("That target cannot be captured.")
		return _capture_result(false, false, "Target is not capturable.", 0, NET_CAPTURE_CHANCE, false)
	
	var roll: int = randi() % 20 + 1
	var success: bool = false
	
	if roll == 20:
		success = true
	elif roll == 1:
		success = false
	else:
		success = randf() <= NET_CAPTURE_CHANCE
	
	var species_id: String = _resolve_species_id(target)
	var target_name: String = target.name if target.name != "" else species_id
	
	if success:
		var captured_data: GoatData = _build_captured_data(target, species_id)
		add_goat(captured_data)
		
		print("[Capture] [%s] net capture roll=%d chance=%.2f -> SUCCESS (%s)" % [capturer.name, roll, NET_CAPTURE_CHANCE, target_name])
		_emit_capture_message("Captured %s!" % target_name)
		
		if target.has_method("die"):
			target.die()
		target.call_deferred("queue_free")
		return _capture_result(true, true, "Capture succeeded.", roll, NET_CAPTURE_CHANCE, true, captured_data)
	
	if target.has_method("stun"):
		target.stun(NET_DISABLE_DURATION)
	
	print("[Capture] [%s] net capture roll=%d chance=%.2f -> FAILURE (%s)" % [capturer.name, roll, NET_CAPTURE_CHANCE, target_name])
	_emit_capture_message("Capture failed on %s." % target_name)
	return _capture_result(true, false, "Capture failed.", roll, NET_CAPTURE_CHANCE, false)

func _find_capture_target(capturer: Actor, center: Vector3, max_distance_from_capturer: float, within_center_radius: float) -> Actor:
	var arena_value: Variant = capturer.get("_arena_grid")
	if not (arena_value is ArenaGrid):
		return null
	
	var arena: ArenaGrid = arena_value as ArenaGrid
	var nearest: Actor = null
	var nearest_dist: float = INF
	
	for node in arena.actors:
		if not is_instance_valid(node) or not (node is Actor):
			continue
		var actor: Actor = node as Actor
		if actor == capturer:
			continue
		
		var distance_to_capturer: float = _flat_distance(actor.global_position, capturer.global_position)
		if distance_to_capturer > max_distance_from_capturer:
			continue
		
		var distance_to_center: float = _flat_distance(actor.global_position, center)
		if distance_to_center > within_center_radius:
			continue
		
		if not _is_capture_candidate(capturer, actor):
			continue
		
		if distance_to_center < nearest_dist:
			nearest_dist = distance_to_center
			nearest = actor
	
	return nearest

func _is_capture_candidate(capturer: Actor, target: Actor) -> bool:
	if target == null or not is_instance_valid(target):
		return false
	if target.is_dead:
		return false
	if target.is_playable:
		return false
	if target.has_meta("capture_candidate"):
		return bool(target.get_meta("capture_candidate"))
	
	if target.faction_component:
		var faction: int = int(target.faction_component.faction)
		if faction == FactionComponent.Faction.PLAYER or faction == FactionComponent.Faction.FARMSTEAD:
			return false
	
	# Fallback for legacy/non-tagged targets: anything non-playable and not allied can be captured.
	if capturer and capturer.has_method("is_ally") and capturer.is_ally(target):
		return false
	return true

func _resolve_species_id(target: Actor) -> String:
	if target and target.has_meta("capture_species"):
		var tagged: String = String(target.get_meta("capture_species", "")).to_lower().strip_edges()
		if not tagged.is_empty():
			return tagged
	
	if target and target.element_type:
		var element_species := target.element_type.to_lower().strip_edges()
		if not element_species.is_empty():
			return element_species
	
	if target is GoatActor:
		return "goat"
	if target is GoblinMinion:
		return "goblin"
	return "creature"

func _build_captured_data(target: Actor, species_id: String) -> GoatData:
	# Important: duplicate GoatData so GoatActor.die() removing its own data will not remove the captured copy.
	if target is GoatActor:
		var goat_target: GoatActor = target as GoatActor
		if goat_target.goat_data:
			var dup_data: GoatData = goat_target.goat_data.duplicate(true) as GoatData
			if dup_data:
				dup_data.is_selected = false
				dup_data.is_exhausted = false
				return dup_data
	
	var data := GoatData.new()
	data.gender = ActorData.Gender.FEMALE if randf() < 0.5 else ActorData.Gender.MALE
	data.goat_name = _generate_capture_name(species_id)
	data.is_selected = false
	data.is_exhausted = false
	data.horn_type = GoatData.HornType.NONE
	data.body_type = GoatData.BodyType.MEDIUM
	data.pattern_type = GoatData.PatternType.SOLID
	
	match species_id:
		"goblin":
			data.base_color = Color(0.42, 0.66, 0.28)
			data.pattern_color = Color(0.20, 0.36, 0.14)
			data.gold_value = 65
		"mimic":
			data.base_color = Color(0.46, 0.31, 0.17)
			data.pattern_color = Color(0.24, 0.16, 0.08)
			data.gold_value = 80
		_:
			data.base_color = Color(0.68, 0.58, 0.43)
			data.pattern_color = Color(0.30, 0.23, 0.16)
			data.gold_value = 55
	
	if target and target.ability_scores_component:
		var asc = target.ability_scores_component
		data.strength = asc.strength
		data.dexterity = asc.dexterity
		data.constitution = asc.constitution
		data.intelligence = asc.intelligence
		data.wisdom = asc.wisdom
		data.charisma = asc.charisma
	
	return data

func _generate_capture_name(species_id: String) -> String:
	var clean_species: String = species_id.capitalize()
	var suffix: int = randi() % 900 + 100
	return "%s %d" % [clean_species, suffix]

func _emit_capture_message(text: String) -> void:
	print("[Capture] ", text)
	if has_node("/root/QuestEvents"):
		QuestEvents.message(text)

func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()

func _capture_result(attempted: bool, success: bool, reason: String, roll: int, chance: float, captured: bool, creature: ActorData = null) -> Dictionary:
	return {
		"attempted": attempted,
		"success": success,
		"reason": reason,
		"roll": roll,
		"chance": chance,
		"captured": captured,
		"creature": creature
	}
