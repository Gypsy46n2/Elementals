class_name GoatDecisionComponent
extends ActorDecisionComponent

## Specialized AI for goats to make them rowdy and rambunctious.
## They seek out other actors, scream at them, and headbutt them.

enum State { WANDERING, ALERT, CHARGING, COOLDOWN }
var current_state: State = State.WANDERING

@export var detection_range: float = 10.0
@export var charge_range: float = 6.0
@export var alert_duration: float = 1.0
@export var cooldown_duration: float = 3.0

@export_group("Flocking")
## Minimum distance to keep from the player goat.
@export var min_follow_distance: float = 1.0
## Maximum distance to allow from the player goat before seeking them.
@export var max_follow_distance: float = 5.0

var _state_timer: float = 0.0
var _target_actor: Node3D = null

var _debug_line: MeshInstance3D
var _debug_material: StandardMaterial3D

func _ready() -> void:
	_rng.randomize()
	if not actor and get_parent().get("element_type") != null: # Duck typing check for Actor
		actor = get_parent()
	
	if actor:
		_movement_target = actor.global_transform.origin
		if movement_component:
			movement_component.stuck.connect(_choose_new_target)
		# Use call_deferred to ensure arena grid is ready
		call_deferred("_choose_new_target")
	
	_setup_debug_line()

func _setup_debug_line() -> void:
	_debug_line = MeshInstance3D.new()
	_debug_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	_debug_material = StandardMaterial3D.new()
	_debug_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_debug_material.vertex_color_use_as_albedo = true
	_debug_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	_debug_line.mesh = ImmediateMesh.new()
	add_child(_debug_line)

func _physics_process(delta: float) -> void:
	if actor and actor.has_method("is_stunned") and actor.is_stunned():
		if movement_component:
			movement_component.apply_gravity(delta)
			movement_component.stop(delta)
		return
	
	_update_debug_visuals()
	super._physics_process(delta)

func _update_debug_visuals() -> void:
	if not _debug_line: return
	
	var should_show = DebugComponent.debug_enabled and not is_controlled
	_debug_line.visible = should_show
	
	if not should_show: return
	
	var player = _get_player_goat()
	if not player: 
		if _debug_line.mesh is ImmediateMesh:
			(_debug_line.mesh as ImmediateMesh).clear_surfaces()
		return
	
	var dist = actor.global_position.distance_to(player.global_position)
	var color = Color.GREEN
	if dist < min_follow_distance:
		color = Color.RED
	elif dist < max_follow_distance:
		color = Color.YELLOW
		
	var mesh = _debug_line.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, _debug_material)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(Vector3.ZERO)
	mesh.surface_add_vertex(actor.to_local(player.global_position))
	mesh.surface_end()

func _get_player_goat() -> Node3D:
	if not actor or not actor.get("_arena_grid"):
		return null
	var target = actor.get("_arena_grid").get("current_controlled_actor")
	if is_instance_valid(target) and target.get("element_type") == "goat" and target != actor:
		return target
	return null

func _choose_new_target() -> void:
	if not actor or not actor.get("_arena_grid"):
		return
		
	var player_goat = _get_player_goat()
	if not player_goat:
		super._choose_new_target()
		return
		
	actor.tile_interaction_component.update_tile_below()
	var ground_tile = actor.tile_interaction_component.get_ground_tile()
	if not ground_tile:
		super._choose_new_target()
		return

	var dist_to_player = actor.global_position.distance_to(player_goat.global_position)
	
	# Get valid neighbors using base class helper
	var neighbors = _get_traversable_neighbors(ground_tile)
	
	if neighbors.is_empty():
		super._choose_new_target()
		return

	var next_tile: HexTileData = null
	
	if dist_to_player > max_follow_distance:
		# Seek player: pick neighbor closest to player
		neighbors.sort_custom(func(a, b):
			return a.position.distance_to(player_goat.global_position) < b.position.distance_to(player_goat.global_position)
		)
		next_tile = neighbors[0]
	elif dist_to_player < min_follow_distance:
		# Repel/Maintain: pick neighbor further from player
		neighbors.sort_custom(func(a, b):
			return a.position.distance_to(player_goat.global_position) > b.position.distance_to(player_goat.global_position)
		)
		next_tile = neighbors[0]
	else:
		# Random wander within neighbors
		var candidates = neighbors.filter(func(t): return t != _previous_tile)
		if candidates.size() > 0:
			next_tile = candidates[_rng.randi_range(0, candidates.size() - 1)]
		else:
			next_tile = neighbors.pick_random()

	if next_tile:
		_previous_tile = ground_tile
		_movement_target = next_tile.position
		_movement_target.y = actor.global_position.y

func _handle_ai_logic(delta: float) -> void:
	if not actor or not actor.get("_arena_grid") or not movement_component:
		return
		
	if is_controlled:
		return
		
	# Reactive Flocking: If we are way too far from the player, force a re-target
	var player_goat = _get_player_goat()
	if player_goat and current_state == State.WANDERING:
		var dist_to_player = actor.global_position.distance_to(player_goat.global_position)
		if dist_to_player > max_follow_distance * 1.5:
			# Force immediate movement update if current target is moving away or too far
			var target_dist_to_player = _movement_target.distance_to(player_goat.global_position)
			if target_dist_to_player > max_follow_distance:
				_choose_new_target()

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

func _update_wandering(delta: float) -> void:
	# Normal wandering behavior from base class
	super._handle_ai_logic(delta)
	
	# Look for a target
	var target = _find_nearby_actor()
	if target:
		_target_actor = target
		_transition_to(State.ALERT)

func _update_alert(delta: float) -> void:
	# Stop moving and face the target
	movement_component.stop(delta)
	_face_target(_target_actor.global_position)
	
	_state_timer -= delta
	if _state_timer <= 0:
		_transition_to(State.CHARGING)

func _update_charging(delta: float) -> void:
	# The GoatActor script handles the actual charge physics
	# We just need to trigger it once
	if not actor.get("_is_charging"):
		# If we aren't charging yet, start it
		var target_pos = _target_actor.global_position
		
		# Set the charge direction in the goat script
		var dir = (target_pos - actor.global_position).normalized()
		dir.y = 0
		
		# We use the internal charge method by simulating a mouse click or calling it directly
		# GoatActor._start_charge() uses mouse position, so we should add an AI-friendly version
		if actor.has_method("ai_start_charge"):
			actor.ai_start_charge(target_pos)
		
		_transition_to(State.COOLDOWN)

func _update_cooldown(delta: float) -> void:
	# Wander slowly or stay still
	super._handle_ai_logic(delta)
	
	_state_timer -= delta
	if _state_timer <= 0:
		_transition_to(State.WANDERING)

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

func get_debug_state() -> String:
	if is_controlled:
		return "CONTROLLED"
	return State.keys()[current_state]

func _find_nearby_actor() -> Node3D:
	if not actor or not actor.get("_arena_grid"):
		return null
		
	var player_goat = _get_player_goat()
	var possible_targets: Array[Node3D] = []
	
	var arena_grid = actor.get("_arena_grid")
	for other in arena_grid.get("actors"):
		if not is_instance_valid(other) or other == actor or other.get("is_friendly") == true:
			continue
		
		# Only target enemies (non-goats)
		possible_targets.append(other)
			
	if possible_targets.is_empty():
		return null
		
	var best_target: Node3D = null
	var min_score = 1e9
	
	for target in possible_targets:
		var dist_to_self = actor.global_position.distance_to(target.global_position)
		var dist_from_player = player_goat.global_position.distance_to(target.global_position) if player_goat else 1e9
		
		# Candidate if near me OR near the player (herd awareness)
		if dist_to_self > detection_range and dist_from_player > detection_range:
			continue
			
		# Seek target near player first
		var score = dist_to_self + (dist_from_player * 0.5)
			
		if score < min_score:
			min_score = score
			best_target = target
			
	return best_target

func _face_target(pos: Vector3) -> void:
	# The sprite flip logic in GoatActor handles visual facing
	# But we can update velocity slightly to influence it if needed
	var dir = (pos - actor.global_position).normalized()
	actor.velocity.x = dir.x * 0.01
	actor.velocity.z = dir.z * 0.01
