class_name FarmerDecisionComponent
extends ActorDecisionComponent

enum State { PATROLLING, HERDING, RETURNING }
var current_state: State = State.PATROLLING

@export var herd_distance: float = 12.0 # Distance from house to start herding
@export var nudge_range: float = 3.0 # Distance to nudge a goat
@export var farm_center: Vector3 = Vector3.ZERO

var _target_goat: Node3D = null
var _state_timer: float = 0.0

func _ready() -> void:
	super._ready()
	_rng.randomize()

func _handle_ai_logic(delta: float) -> void:
	if not actor or not actor.get("_arena_grid") or is_controlled:
		return

	match current_state:
		State.PATROLLING:
			_update_patrolling(delta)
		State.HERDING:
			_update_herding(delta)
		State.RETURNING:
			_update_returning(delta)
	
	# Always perform base AI logic for movement/avoidance
	super._handle_ai_logic(delta)

func _update_patrolling(_delta: float) -> void:
	# Randomly wander near the farm center
	if _movement_target.distance_to(farm_center) > 10.0:
		_movement_target = farm_center + Vector3(_rng.randf_range(-5, 5), 0, _rng.randf_range(-5, 5))
	
	# Look for goats far from center
	_target_goat = _find_stray_goat()
	if _target_goat:
		current_state = State.HERDING

func _update_herding(_delta: float) -> void:
	if not is_instance_valid(_target_goat):
		current_state = State.PATROLLING
		return
		
	var dist_to_goat = actor.global_position.distance_to(_target_goat.global_position)
	var goat_dist_to_center = _target_goat.global_position.distance_to(farm_center)
	
	if goat_dist_to_center < 5.0:
		# Goat is back home
		current_state = State.PATROLLING
		return
		
	# Move to the opposite side of the goat from the center
	var dir_from_center = (_target_goat.global_position - farm_center).normalized()
	_movement_target = _target_goat.global_position + dir_from_center * 2.0
	
	if dist_to_goat < nudge_range:
		# "Nudge" the goat: for now just scream or something to trigger its response
		if actor.has_method("herd_goat"):
			actor.herd_goat(_target_goat)
			current_state = State.RETURNING
			_state_timer = 2.0

func _update_returning(delta: float) -> void:
	_movement_target = farm_center
	
	_state_timer -= delta
	if _state_timer <= 0:
		current_state = State.PATROLLING

func _find_stray_goat() -> Node3D:
	var strays: Array[Node3D] = []
	var arena_grid = actor.get("_arena_grid")
	if not arena_grid: return null
	
	for e in arena_grid.get("actors"):
		if e.get("element_type") == "goat":
			if e.global_position.distance_to(farm_center) > herd_distance:
				strays.append(e)
	
	if strays.is_empty():
		return null
		
	# Return the furthest stray
	strays.sort_custom(func(a, b):
		return a.global_position.distance_to(farm_center) > b.global_position.distance_to(farm_center)
	)
	return strays[0]

func get_debug_state() -> String:
	return State.keys()[current_state]
