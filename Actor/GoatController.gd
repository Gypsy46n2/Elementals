class_name GoatController
extends ActorAIController

## Specialized AI for goats to make them rowdy and rambunctious.
## They seek out other actors, scream at them, and headbutt them.

enum State { WANDERING, ALERT, CHARGING, COOLDOWN }
var current_state: State = State.WANDERING

@export var alert_duration: float = 1.0
@export var cooldown_duration: float = 3.0

## Flocking needs to be upgraded to a State
## make a res://Components/ActorComponents/NPC Behavior/States/AIFlockinState.gd and move function there.
@export_group("Flocking")
## Minimum distance to keep from the player goat.
@export var min_follow_distance: float = 1.0
## Maximum distance to allow from the player goat before seeking them.
@export var max_follow_distance: float = 5.0

var _state_timer: float = 0.0
var _target_actor: Node3D = null

# REFACTOR: Consider caching the actor reference locally and validating
# DebugComponent.debug_enabled before spending cycles on _setup_debug_line().
# see res://Components/DebugComponent.gd
func _ready() -> void:
	super._ready()

func _init_state_machine() -> void:
	super._init_state_machine()
	if state_machine:
		state_machine.register_state("flock", AIFlockinState.new())

# REFACTOR: Replace string-based reflection (.get("_arena_grid")) with typed
# references or at least constants for property names. The current approach
# is fragile and bypasses compile-time checks. Consider caching the result
# and updating it via signals when control changes rather than polling.
func _get_player_goat() -> Node3D:
	if not actor or not actor.get("_arena_grid"):
		return null
	var target = actor.get("_arena_grid").get("current_controlled_actor")
	if is_instance_valid(target) and target.get("element_type") == "goat" and target != actor:
		return target
	return null

# REFACTOR: This function violates Single Responsibility Principle.
# 1. The flocking distance check should live in WANDERING state logic.
# 2. The "rowdy_bonus" scans all actors every frame (O(n)). Cache nearby
#    goats using an Area3D overlap check or update on a slower timer.
# 3. State dispatch and speed multiplier application should be separate methods.
# 4. Avoid calling super._handle_ai_logic() from child states (WANDERING/COOLDOWN)
#    as it creates tight coupling; prefer composition or explicit behavior nodes.
func _handle_ai_logic(delta: float) -> void:
	if not actor or not actor.get("_arena_grid") or not movement_component:
		return
		
	if is_controlled:
		return
		
	# Social rowdiness: speed up if others are nearby
	var rowdy_bonus = 1.0
	var arena_grid = actor.get("_arena_grid")
	for other in arena_grid.get("actors"):
		if is_instance_valid(other) and other.get("element_type") == "goat" and other != actor:
			if other.global_position.distance_to(actor.global_position) < 8.0:
				rowdy_bonus += 0.25
	
	# Combine rowdy bonus with state-specific multipliers
	var state_mult = 1.0
	match current_state:
		State.WANDERING:
			state_mult = 1.0
			_update_wandering(delta)
		State.ALERT:
			state_mult = 1.5
			_update_alert(delta)
		State.CHARGING:
			state_mult = 1.0
			_update_charging(delta)
		State.COOLDOWN:
			state_mult = 0.5
			_update_cooldown(delta)
			
	movement_component.speed_multiplier = rowdy_bonus * state_mult

# REFACTOR: Calling super._handle_ai_logic() inside a state update is a code smell;
# it re-enters base class logic unpredictably. Inline the needed wandering behavior
# or delegate to a dedicated WanderingBehavior node. Cache _find_nearby_actor()
# result to avoid duplicate raycasts/detection work.
func _update_wandering(delta: float) -> void:
	var player_goat := _get_player_goat()
	if player_goat and state_machine and state_machine.get_base_state_name() != "flock":
		state_machine.change_state("flock")
	elif not player_goat and state_machine and state_machine.get_base_state_name() == "flock":
		state_machine.change_state("roam")
	
	super._handle_ai_logic(delta)
	
	var target := _find_nearby_actor(player_goat)
	if target:
		_target_actor = target
		_transition_to(State.ALERT)

# REFACTOR: Add null-check for _target_actor before accessing its global_position.
# Consider using a Tween or Timer node instead of manual _state_timer bookkeeping.
# Facing logic should use actor.look_at() or a dedicated face_direction() method.
func _update_alert(delta: float) -> void:
	# Stop moving and face the target
	movement_component.stop(delta)
	_face_target(_target_actor.global_position)
	
	_state_timer -= delta
	if _state_timer <= 0:
		_transition_to(State.CHARGING)

# REFACTOR: Scanning ability_comp.actions every frame is expensive. Cache the
# GoatCharge action reference in _ready(). Also, _delta is unused; if the method
# truly doesn't need delta, document why. Validate _target_actor validity before
# using its position. Consider moving charge triggering to the _transition_to()
# method so it fires once on state entry rather than every frame.
func _update_charging(_delta: float) -> void:
	# The GoatCharge ability handles the actual charge physics
	# We just need to trigger it once
	var is_charging := false
	var ability_comp = actor.get("ability_component")
	if ability_comp:
		for action in ability_comp.actions:
			if action is GoatCharge and action.is_charging:
				is_charging = true
				break

	if not is_charging:
		# If we aren't charging yet, start it
		var target_pos = _target_actor.global_position

		if ability_comp:
			ability_comp.execute_ability("charge", target_pos)

		_transition_to(State.COOLDOWN)

# REFACTOR: Like _update_wandering, calling super._handle_ai_logic() here couples
# child state to base implementation. Prefer explicit cooldown movement behavior.
# Use a Timer node instead of manual _state_timer countdown.
func _update_cooldown(delta: float) -> void:
	# Wander slowly or stay still
	super._handle_ai_logic(delta)
	
	_state_timer -= delta
	if _state_timer <= 0:
		_transition_to(State.WANDERING)

# REFACTOR: Replace with a proper state machine (State pattern or HierarchicalFSM).
# Emit a signal like state_changed(new_state) so other systems (audio, particles)
# can react without hardcoded side-effects (e.g., _scream). Avoid using
# actor.call("_scream") for private methods; use a public interface or signal.
func _transition_to(new_state: State) -> void:
	current_state = new_state
	match new_state:
		State.WANDERING:
			_target_actor = null
		State.ALERT:
			_state_timer = alert_duration
			if actor.has_method("_scream"):
				actor.call("_scream")
		State.CHARGING:
			pass
		State.COOLDOWN:
			_state_timer = cooldown_duration

# REFACTOR: Consider making this a property with a setter that updates a UI label
# only when the state actually changes, rather than polling every frame.
func get_debug_state() -> String:
	if is_controlled:
		return "CONTROLLED"
	return State.keys()[current_state]

# REFACTOR: Replace magic number 1e9 with INF or a named constant MAX_DISTANCE.
# The scoring heuristic (dist_to_self + dist_from_player * 0.5) is opaque;
# extract into a _score_target(target) method with documented weights.
# Filter by detection_range before sorting to reduce iteration cost.
# Cache player_goat distance if used in a loop.
func _find_nearby_actor(p_player_goat: Node3D = null) -> Node3D:
	if not actor or not actor.get("_arena_grid"):
		return null
		
	var player_goat: Node3D = p_player_goat if p_player_goat else _get_player_goat()
	var possible_targets: Array[Node3D] = []
	
	var arena_grid = actor.get("_arena_grid")
	for other in arena_grid.get("actors"):
		if not is_instance_valid(other) or other == actor:
			continue
		
		if actor.is_enemy(other):
			possible_targets.append(other)
			
	if possible_targets.is_empty():
		return null
		
	var best_target: Node3D = null
	var min_score = INF
	
	for target in possible_targets:
		var dist_to_self = actor.global_position.distance_to(target.global_position)
		var dist_from_player = player_goat.global_position.distance_to(target.global_position) if player_goat else INF
		
		# Candidate if near me OR near the player (herd awareness)
		if dist_to_self > detection_range and dist_from_player > detection_range:
			continue
			
		# Seek target near player first
		var score = dist_to_self + (dist_from_player * 0.5)
			
		if score < min_score:
			min_score = score
			best_target = target
			
	return best_target
