class_name DetectionComponent
extends Node

## Component responsible for perceiving nearby actors.
## Handles perception checks (d20 + Wisdom vs DC), cooldown timing, and perceived actor tracking.
## Can be used by both the player and NPCs to detect any actor (hostile or neutral).

signal actor_perceived(actor: Node3D)
## Signal fired when a perceived actor is no longer being tracked.
signal actor_lost(actor: Node3D)

## Reference to the owning actor.
var actor: Node3D

## Perceived enemies that have been successfully detected.
## Maps actor reference -> remaining duration (float seconds).
var perceived_enemies: Dictionary = {}

## The perception trigger registered with the TileSignalComponent.
var _perception_trigger: Dictionary = {}

## Cooldown timer to prevent perception roll spam.
var _perception_cooldown: float = 0.0

## Single timer for processing expired perceptions instead of per-frame iteration.
var _expiry_timer: Timer

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
	
	# Setup the expiry timer once
	_setup_expiry_timer()
	
	# Connect to movement signal to update trigger center
	if actor.has_signal("tile_changed"):
		actor.tile_changed.connect(_on_tile_changed)
	
	# Register the perception trigger with TileSignalComponent
	call_deferred("_register_perception_trigger")

func _register_perception_trigger() -> void:
	if not actor: return
	
	var arena = _get_arena()
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
		_register_perception_trigger()
	else:
		var arena = _get_arena()
		if arena and arena.get("tile_signals"):
			arena.tile_signals.update_trigger_center(_perception_trigger, new_tile)

func _setup_expiry_timer() -> void:
	_expiry_timer = Timer.new()
	_expiry_timer.name = "DetectionExpiryTimer"
	_expiry_timer.one_shot = true
	_expiry_timer.timeout.connect(_on_expiry_timer_timeout)
	add_child(_expiry_timer)

func _schedule_next_expiry() -> void:
	if perceived_enemies.is_empty():
		return
	
	# Find the minimum time remaining
	var min_time: float = INF
	for enemy in perceived_enemies.keys():
		var remaining: float = perceived_enemies[enemy]
		if remaining < min_time:
			min_time = remaining
	
	if min_time < INF and min_time > 0:
		_expiry_timer.start(min_time)

func _on_expiry_timer_timeout() -> void:
	# Remove all actors whose timers have expired
	var expired: Array[Node3D] = []
	for enemy in perceived_enemies.keys():
		perceived_enemies[enemy] -= _expiry_timer.wait_time
		if perceived_enemies[enemy] <= 0:
			expired.append(enemy)
	
	for enemy in expired:
		perceived_enemies.erase(enemy)
		actor_lost.emit(enemy)
	
	# Schedule next expiry if any remain
	_schedule_next_expiry()

func _on_perception_trigger_activated(other: Node3D, _meta: Dictionary) -> void:
	if not is_instance_valid(other) or other == actor:
		return
		
	# Check if target is non-ally and currently hidden
	if _perception_cooldown <= 0:
		if not (actor.has_method("is_ally") and actor.is_ally(other)):
			if not is_actor_perceived(other):
				var vc = other.get("visual_component")
				if vc and not vc.get("is_spotted"):
					perform_perception_check(other)

## Called each frame to update perception state.
## Now uses event-driven timer instead of per-frame iteration.
func process_update(delta: float) -> void:
	# Update cooldown only (the only per-frame thing we still need)
	if _perception_cooldown > 0:
		_perception_cooldown -= delta

## Stub for legacy support. No-op since we use timer-based expiry.
func remove_expired_actors() -> void:
	pass

## Attempts to perceive the nearest actor in range using a Wisdom-based perception check.
## Returns the nearest successfully perceived actor, or null if none found.
func detect_nearest_actor() -> Node3D:
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
		
		# Skip dead actors
		if other.is_dead:
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
## Distance affects the roll: closer actors are easier to spot (bonus), farther ones are harder (penalty).
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
	
	# Calculate tile distance and its modifier
	var tile_distance: int = _get_tile_distance_to(other)
	var distance_mod: int = _calculate_distance_modifier(tile_distance)
	
	# Set cooldown to prevent spamming checks
	_perception_cooldown = PERCEPTION_COOLDOWN
	
	# Perform the check via SkillCheckComponent
	var success: bool = false
	var scc = actor.get("skill_check_component")
	
	if scc:
		var result: Dictionary = scc.perform_check(wis_val + distance_mod, stealth_dc, "Perception Check", other, wis_val, distance_mod, tile_distance)
		success = result.success
	
	if success:
		perceived_enemies[other] = PERCEPTION_EXPIRY
		actor_perceived.emit(other)
		_schedule_next_expiry()
		
	return success

## Calculates the hex tile distance between this actor and another actor.
## Uses hex coordinate system for accurate distance measurement.
func _get_tile_distance_to(other: Node3D) -> int:
	var arena = _get_arena()
	var hex_size: float = 1.5
	if arena and arena.get("hex_size"):
		hex_size = arena.hex_size
	
	var tic = actor.get("tile_interaction_component")
	var other_tic = other.get("tile_interaction_component")
	
	if tic and other_tic:
		var actor_tile = tic.get_ground_tile()
		var other_tile = other_tic.get_ground_tile()
		if actor_tile and other_tile and arena:
			var a: Vector2i = actor_tile.axial_coords
			var b: Vector2i = other_tile.axial_coords
			return (abs(a.x - b.x) + abs(a.x + a.y - b.x - b.y) + abs(a.y - b.y)) / 2
	
	# Fallback to world space distance using proper hex conversion
	var world_dist: float = actor.global_position.distance_to(other.global_position)
	return int(world_dist / (sqrt(3.0) * hex_size))

## Calculates the distance modifier for a perception check.
## Closer actors grant a bonus, farther ones incur a penalty.
## Formula: modifier = floor((detection_range - tile_distance) / 2)
func _calculate_distance_modifier(tile_distance: int) -> int:
	var range_tiles: int = int(detection_range)
	if tile_distance < range_tiles:
		# Bonus for being closer than max range
		return floor((range_tiles - tile_distance) / 2.0)
	return 0  # No penalty for now, just no bonus

## Caches the arena reference to avoid repeated tree queries.
var _cached_arena: Node = null

func _get_arena() -> Node:
	if is_instance_valid(_cached_arena):
		return _cached_arena
	_cached_arena = actor.get_tree().get_first_node_in_group("arena")
	return _cached_arena

func _notification(what: int) -> void:
	if what == Node.NOTIFICATION_EXIT_TREE:
		_cached_arena = null

## Stub for legacy support. Performs a perception check immediately.
func add_actor_in_range(other: Node3D) -> void:
	if not other in perceived_enemies:
		perform_perception_check(other)

## Stub for legacy support.
func remove_actor_in_range(other: Node3D) -> void:
	if perceived_enemies.has(other):
		perceived_enemies.erase(other)
		actor_lost.emit(other)

## Returns true if the given actor is currently perceived (successfully detected).
func is_actor_perceived(other: Node3D) -> bool:
	return perceived_enemies.has(other) and perceived_enemies[other] > 0

## Returns all currently perceived actors.
func get_perceived_actors() -> Array[Node3D]:
	var result: Array[Node3D] = []
	for enemy in perceived_enemies.keys():
		if perceived_enemies[enemy] > 0:
			result.append(enemy)
	return result

## Clears all perceived actors.
func clear_all() -> void:
	for enemy in perceived_enemies.keys():
		actor_lost.emit(enemy)
	perceived_enemies.clear()
