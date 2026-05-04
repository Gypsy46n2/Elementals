class_name DetectionComponent
extends Node

## Component responsible for detecting and tracking nearby enemies.
## Handles perception checks (d20 + Wisdom vs DC), cooldown timing, and perceived enemy tracking.
## Can be used by both the player and NPCs to detect hostile actors.

signal enemy_perceived(actor: Node3D)
signal enemy_lost(actor: Node3D)

## Reference to the owning actor.
var actor: Node3D

## Perceived enemies that have been successfully detected.
## Maps actor reference -> remaining duration (float seconds).
var perceived_enemies: Dictionary = {}

## The perception trigger registered with the TileSignalComponent.
var _perception_trigger: Dictionary = {}

## Cooldown timer to prevent perception roll spam.
var _perception_cooldown: float = 0.0

## Detection range computed from Wisdom: base 10 + (Wisdom × 2).
var detection_range: float:
	get:
		var asc = actor.get("ability_scores_component") if actor else null
		if asc:
			return 10.0 + (asc.wisdom * 2.0)
		return 10.0

## Perception check DC expiry time.
const PERCEPTION_EXPIRY: float = 3.0
## Cooldown between perception checks.
const PERCEPTION_COOLDOWN: float = 1.0

func setup(p_actor: Node3D) -> void:
	actor = p_actor
	
	# Connect to movement signal to update trigger center
	if actor.has_signal("tile_changed"):
		actor.tile_changed.connect(_on_tile_changed)
	
	# Register the perception trigger with TileSignalComponent
	call_deferred("_register_perception_trigger")

func _register_perception_trigger() -> void:
	if not actor: return
	
	var arena = actor.get_tree().get_first_node_in_group("arena")
	if arena and arena.get("tile_signals"):
		var signals = arena.tile_signals
		var tic = actor.get("tile_interaction_component")
		var current_tile = tic.get_ground_tile() if tic else null
		
		# If we don't have a tile yet, wait for one
		if not current_tile:
			return
			
		var hex_size: float = arena.hex_size if arena.get("hex_size") else 1.5
		var hex_radius: int = int(ceil(detection_range / (sqrt(3.0) * hex_size))) + 1
		
		_perception_trigger = signals.register_trigger(
			current_tile,
			hex_radius,
			_on_perception_trigger_activated,
			{"continuous": true}
		)

func _on_tile_changed(new_tile: Object) -> void:
	if _perception_trigger.is_empty():
		# Try to register if we failed initially
		_register_perception_trigger()
	else:
		var arena = actor.get_tree().get_first_node_in_group("arena")
		if arena and arena.get("tile_signals"):
			arena.tile_signals.update_trigger_center(_perception_trigger, new_tile)

func _on_perception_trigger_activated(other: Node3D, _meta: Dictionary) -> void:
	if not is_instance_valid(other) or other == actor:
		return
		
	# Check if target is an enemy and currently hidden
	if _perception_cooldown <= 0:
		if actor.has_method("is_enemy") and actor.is_enemy(other):
			if not is_actor_perceived(other):
				var vc = other.get("visual_component")
				if vc and not vc.get("is_spotted"):
					perform_perception_check(other)

## Called each frame to update perception state.
func process_update(delta: float) -> void:
	# Update cooldown
	if _perception_cooldown > 0:
		_perception_cooldown -= delta
	
	# Decrement perceived enemy timers and remove expired
	var expired: Array[Node3D] = []
	for enemy in perceived_enemies.keys():
		if not is_instance_valid(enemy):
			expired.append(enemy)
			continue
		perceived_enemies[enemy] -= delta
		if perceived_enemies[enemy] <= 0:
			expired.append(enemy)
	
	for enemy in expired:
		perceived_enemies.erase(enemy)
		enemy_lost.emit(enemy)

## Attempts to detect enemies in range using a Wisdom-based perception check.
## Returns the nearest successfully perceived enemy, or null if none found.
func detect_nearest_enemy() -> Node3D:
	if not actor:
		return null
	
	var nearest: Node3D = null
	var nearest_dist: float = INF
	
	var possible_targets: Array = []
	if not _perception_trigger.is_empty():
		possible_targets = _perception_trigger.get("active_actors", [])
	
	for other in possible_targets:
		if not is_instance_valid(other) or other == actor:
			continue
		
		if actor.has_method("is_ally") and actor.is_ally(other):
			continue
		
		var dist: float = actor.global_position.distance_to(other.global_position)
		
		# Already perceived?
		if is_actor_perceived(other):
			if dist < nearest_dist:
				nearest = other
				nearest_dist = dist
			continue
		
		# For non-player actors, we still do periodic checks via this method
		if _perception_cooldown <= 0:
			if perform_perception_check(other):
				if dist < nearest_dist:
					nearest = other
					nearest_dist = dist
	
	return nearest

## Performs an active perception check against a specific target.
## Returns true if the check succeeds and the target is perceived.
func perform_perception_check(other: Node3D) -> bool:
	if not actor or not is_instance_valid(other):
		return false
	
	# Determine observer's Perception modifier (Wisdom)
	var wis_val: float = 0.0
	var observer_asc = actor.get("ability_scores_component")
	if observer_asc:
		wis_val = observer_asc.wisdom
	
	# Determine target's Stealth DC (10 + Dexterity)
	var stealth_dc: float = 12.0 # Default base DC
	var target_asc = other.get("ability_scores_component")
	if target_asc:
		stealth_dc = 10.0 + target_asc.dexterity
	
	# Set cooldown to prevent spamming checks
	_perception_cooldown = PERCEPTION_COOLDOWN
	
	# Perform the check via SkillCheckComponent
	var success: bool = false
	var scc = actor.get("skill_check_component")
	if scc:
		var result: Dictionary = scc.perform_check(wis_val, stealth_dc, "Perception Check", other)
		success = result.success
	else:
		# Fallback if no skill check component
		var d20: int = randi() % 20 + 1
		success = (d20 + wis_val) >= stealth_dc
	
	if success:
		perceived_enemies[other] = PERCEPTION_EXPIRY
		enemy_perceived.emit(other)
		
	return success

## Stub for legacy support. Performs a perception check immediately.
func add_actor_in_range(other: Node3D) -> void:
	if not other in perceived_enemies:
		perform_perception_check(other)

## Stub for legacy support.
func remove_actor_in_range(other: Node3D) -> void:
	if perceived_enemies.has(other):
		perceived_enemies.erase(other)
		enemy_lost.emit(other)

## Returns true if the given actor is currently perceived (successfully detected).
func is_actor_perceived(other: Node3D) -> bool:
	return perceived_enemies.has(other) and perceived_enemies[other] > 0

## Returns all currently perceived enemies.
func get_perceived_enemies() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for enemy in perceived_enemies.keys():
		if perceived_enemies[enemy] > 0:
			result.append(enemy)
	return result

## Clears all perceived enemies.
func clear_all() -> void:
	for enemy in perceived_enemies.keys():
		enemy_lost.emit(enemy)
	perceived_enemies.clear()
