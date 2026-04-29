## Specialized controller for Actors that navigate a hexagonal grid.
## Handles tile-based movement, obstacle avoidance, and basic combat logic.
class_name ActorAIController
extends ActorController

## Reference to the actor node this component controls.
@export var actor: Node3D
## Maximum distance from the starting position the actor will roam.
@export var roam_radius: float = 22.0
## Distance at which the actor can detect enemies.
## Computed from Wisdom: base 10 + (Wisdom modifier × 2).
var detection_range: float:
	get:
		if actor and actor.ability_scores_component:
			return 10.0 + (actor.ability_scores_component.wisdom * 2.0)
		return 10.0
## Distance at which the actor will begin attacking.
@export var attack_range: float = 10.0
## Health percentage below which the actor will attempt to flee.
@export var flee_health_threshold: float = 0.3

## Tracks the previous tile to avoid immediate backtracking.
var _previous_tile: HexTileData
## The specific 3D coordinate the actor is currently trying to reach.
var _movement_target: Vector3
## Local RNG for randomized movement decisions.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Tracks enemies this actor has successfully perceived.
var _perceived_enemies: Dictionary = {}
## Cooldown timer to prevent perception roll spam.
var _perception_cooldown_timer: float = 0.0
const PERCEPTION_EXPIRY: float = 3.0
const PERCEPTION_COOLDOWN: float = 1.0

## The state machine driving this controller's behavior.
var state_machine: ActorStateMachine

var _tile_signals: TileSignalComponent
var _active_obstacles: Array[Dictionary] = []
var _nearby_cliffs: Array[HexTileData] = []

func _ready() -> void:
	_rng.randomize()
	if not actor and get_parent() is Actor:
		actor = get_parent()

	if actor:
		_movement_target = actor.global_transform.origin
		if movement_component:
			# If the movement component gets stuck, force a recalculation of the target.
			movement_component.stuck.connect(_on_movement_stuck)
		# Deferred initialization because the actor may not have finished creating
		# all components (tile_interaction_component, stun_component, etc.) yet.
		call_deferred("_init_state_machine")
		call_deferred("_connect_stun_signals")
		call_deferred("_connect_death_signals")
		call_deferred("_choose_new_target")
		call_deferred("_setup_tile_signals")

func _setup_tile_signals() -> void:
	if not actor or not actor._arena_grid or not actor._arena_grid.tile_signals:
		return
		
	var signals = actor._arena_grid.tile_signals
	signals.register_actor(actor)
	signals.trigger_activated.connect(_on_global_trigger_entered)
	signals.trigger_deactivated.connect(_on_global_trigger_exited)
	
	# Connect to actor's tile_changed to manage local neighbor lists (for cliffs)
	if not actor.tile_changed.is_connected(_on_actor_tile_changed_npc):
		actor.tile_changed.connect(_on_actor_tile_changed_npc)
	
	# Initial cliff scan
	var current_tile = actor.tile_interaction_component.get_ground_tile()
	if current_tile:
		_on_actor_tile_changed_npc(current_tile)

func _on_global_trigger_entered(trigger: Dictionary, p_actor: Node3D) -> void:
	if p_actor != actor:
		return
		
	if not trigger in _active_obstacles:
		# Only track triggers that have weight (our obstacle triggers)
		if trigger.has("metadata") and trigger["metadata"].has("weight"):
			_active_obstacles.append(trigger)

func _on_global_trigger_exited(trigger: Dictionary, p_actor: Node3D) -> void:
	if p_actor != actor:
		return
	_active_obstacles.erase(trigger)

func _on_actor_tile_changed_npc(new_tile: HexTileData) -> void:
	if not actor or not actor._arena_grid:
		return
	# Update nearby tiles for cliff detection (Radius 2)
	var neighbors = actor._arena_grid._get_neighbors(new_tile)
	var radius2: Array[HexTileData] = []
	radius2.append_array(neighbors)
	for n in neighbors:
		for nn in actor._arena_grid._get_neighbors(n):
			if nn != new_tile and not nn in radius2:
				radius2.append(nn)
	_nearby_cliffs = radius2

## Frame-update hook for non-physics state logic (animations, timers, etc.).
func _process(delta: float) -> void:
	if state_machine:
		state_machine.update(delta)
	
	# Update perception cooldown
	if _perception_cooldown_timer > 0:
		_perception_cooldown_timer -= delta
	
	# Decrement perceived enemy timers and remove expired
	var expired: Array = []
	for enemy in _perceived_enemies.keys():
		if not is_instance_valid(enemy):
			expired.append(enemy)
			continue
		_perceived_enemies[enemy] -= delta
		if _perceived_enemies[enemy] <= 0:
			expired.append(enemy)
	for enemy in expired:
		_perceived_enemies.erase(enemy)

func _physics_process(delta: float) -> void:
	# Stun is now handled as an affected state inside the state machine.
	# Emergency fallback only if the state machine hasn't initialized yet.
	if actor and actor.is_stunned() and not state_machine:
		if movement_component:
			movement_component.apply_gravity(delta)
			movement_component.stop(delta)
		return

	super._physics_process(delta)

## Dispatches AI logic to the active state machine state.
func _handle_ai_logic(delta: float) -> void:
	if not actor or not actor._arena_grid or not movement_component:
		return

	if state_machine:
		state_machine.physics_update(delta)
	else:
		# Fallback for safety if state machine failed to initialize
		_execute_legacy_ai(delta)

## Legacy AI behavior kept as a fallback when the state machine is unavailable.
func _execute_legacy_ai(delta: float) -> void:
	var current_pos_2d := Vector2(actor.global_transform.origin.x, actor.global_transform.origin.z)
	var target_pos_2d := Vector2(_movement_target.x, _movement_target.z)

	if current_pos_2d.distance_to(target_pos_2d) < 0.2:
		_choose_new_target()

	var direction := (target_pos_2d - current_pos_2d).normalized()
	var dir_3d := Vector3(direction.x, 0, direction.y)

	var avoidance := _get_obstacle_avoidance_vector()
	if avoidance.length_squared() > 0.01:
		dir_3d = (dir_3d + avoidance * 2.0).normalized()

	movement_component.move(dir_3d, delta)
	movement_component.apply_gravity(delta)

	# AI Combat Logic: Auto-fire when mana is full.
	if actor.mana_component and actor.projectile_component:
		if actor.mana_component.current_mana >= actor.mana_component.max_mana and not actor.is_stunned():
			actor.projectile_component.launch_projectile_ai(actor.mana_component)

## Scans the immediate vicinity for obstacles and returns a repulsion vector.
func _get_obstacle_avoidance_vector() -> Vector3:
	var avoidance := Vector3.ZERO
	if not actor or not actor._arena_grid:
		return avoidance
		
	var my_pos = actor.global_position
	var ground_y = 0.0
	var ground_tile = actor.tile_interaction_component.get_ground_tile()
	if ground_tile:
		ground_y = actor._arena_grid._get_tile_surface_y(ground_tile)
	
	# 1. Process active static obstacles from the signal system
	for trigger in _active_obstacles:
		var tile: HexTileData = trigger["center"]
		var obstacle_weight: float = trigger["metadata"]["weight"]
		avoidance += _calculate_repulsion(my_pos, tile.position, obstacle_weight)

	# 2. Process nearby cliffs (Dynamic height avoidance)
	for tile in _nearby_cliffs:
		var tile_y = actor._arena_grid._get_tile_surface_y(tile)
		var obstacle_weight = 0.0
		
		if tile_y > ground_y + 0.3: # Stepping up onto high ground.
			obstacle_weight = 1.4
		elif tile_y < ground_y - 1.5: # Avoiding accidental falls off high ledges.
			obstacle_weight = 0.8
		
		if obstacle_weight > 0.0:
			avoidance += _calculate_repulsion(my_pos, tile.position, obstacle_weight)
				
	return avoidance

func _calculate_repulsion(my_pos: Vector3, obstacle_pos: Vector3, obstacle_weight: float) -> Vector3:
	var diff = my_pos - obstacle_pos
	diff.y = 0
	var dist = diff.length()
	
	# Avoidance threshold: slightly larger than a hex to ensure early detection.
	var threshold = 2.2
	if dist < threshold and dist > 0.1:
		var weight = (threshold - dist) / threshold * obstacle_weight
		var repulsion = diff.normalized() * weight
		
		# Add a "sidestep" force to break symmetry.
		var move_dir = Vector3(actor.velocity.x, 0, actor.velocity.z).normalized()
		if move_dir.length_squared() > 0.1:
			var dot = move_dir.dot(-diff.normalized())
			if dot > 0.5: # Heading mostly at the obstacle.
				var side_dir = Vector3(-diff.z, 0, diff.x).normalized()
				# Bias towards the side we are already leaning towards.
				if move_dir.dot(side_dir) < 0:
					side_dir = -side_dir
				repulsion += side_dir * weight * 1.0
		
		return repulsion
	return Vector3.ZERO

## Selects a new adjacent tile to move toward.
func _choose_new_target() -> void:
	if not actor or not actor._arena_grid:
		return
		
	actor.tile_interaction_component.update_tile_below()
	var ground_tile = actor.tile_interaction_component.get_ground_tile()
	
	if ground_tile and actor._arena_grid:
		# Filter neighbors for those that are actually traversable (no stone, no trees, no high walls).
		var neighbors = actor.tile_navigation_component.get_traversable_neighbors(ground_tile)
		
		if neighbors.size() > 0:
			# Try to avoid going back to the tile we just came from.
			var candidates = neighbors.filter(func(t): return t != _previous_tile)
			var next_tile: HexTileData
			if candidates.size() > 0:
				next_tile = candidates[_rng.randi_range(0, candidates.size() - 1)]
			else:
				next_tile = neighbors[_rng.randi_range(0, neighbors.size() - 1)]
			
			_previous_tile = ground_tile
			_movement_target = next_tile.position
			_movement_target.y = actor.global_position.y
			return

	# Fallback logic: if no valid neighbors exist, pick any non-stone tile or a random direction.
	var fallback_neighbors = actor._arena_grid._get_neighbors(ground_tile if ground_tile else actor._arena_grid.get_tile_at_grid_coords(0,0)).filter(func(t): 
		return t != null and t.current_state != TileConstants.State.STONE
	)
	
	if fallback_neighbors.size() > 0:
		_movement_target = fallback_neighbors.pick_random().position
	else:
		var heading = _rng.randf_range(0.0, TAU)
		_movement_target = actor.global_transform.origin + Vector3(cos(heading), 0.0, sin(heading)) * 3.0

	_movement_target.y = actor.global_position.y

## Initializes the state machine and registers all default AI states.
func _init_state_machine() -> void:
	if state_machine:
		return
	state_machine = ActorStateMachine.new()
	state_machine.actor = actor
	state_machine.controller = self

	state_machine.register_state("idle", AIIdleState.new())
	state_machine.register_state("roam", AIRoamState.new())
	state_machine.register_state("chase", AIChaseState.new())
	state_machine.register_state("attack", AIAttackState.new())
	state_machine.register_state("flee", AIFleeState.new())
	state_machine.register_state("investigate", AIInvestigateState.new())
	state_machine.register_state("stunned", AIStunnedState.new())
	state_machine.register_state("death", AIDeathState.new())

	state_machine.change_state("roam")

## Connects to the actor's stun component so affected states are applied automatically.
func _connect_stun_signals() -> void:
	if not actor or not actor.stun_component:
		return
	actor.stun_component.stun_started.connect(_on_stun_started)
	actor.stun_component.stun_ended.connect(_on_stun_ended)
	# Handle edge case where actor is already stunned when this controller initializes
	if actor.stun_component.is_stunned():
		state_machine.change_affected_state("stunned")

## Called when the actor begins being stunned.
func _on_stun_started(_duration: float) -> void:
	if state_machine:
		state_machine.change_affected_state("stunned")

## Called when the actor recovers from stun.
func _on_stun_ended() -> void:
	if state_machine:
		state_machine.clear_affected_state()

## Connects to the actor's death and resurrection signals.
func _connect_death_signals() -> void:
	if not actor:
		return
	actor.died.connect(_on_actor_died)
	actor.resurrected.connect(_on_actor_resurrected)

## Called when the actor dies. Transitions the state machine to the death state.
func _on_actor_died() -> void:
	if state_machine:
		state_machine.change_state("death")

## Called when the actor is resurrected. Returns to roaming behavior.
func _on_actor_resurrected() -> void:
	if state_machine:
		state_machine.change_state("roam")

## Finds the nearest enemy actor that has been successfully perceived.
## Perception check: d20 + Wisdom modifier vs DC = distance + target's Dexterity modifier.
func _find_nearest_enemy() -> Node3D:
	if not actor or not actor._arena_grid:
		return null
	
	var current_detection_range: float = detection_range
	var nearest: Node3D = null
	var nearest_dist: float = INF
	
	for other in actor._arena_grid.actors:
		if not is_instance_valid(other) or other == actor:
			continue
		if not actor.is_enemy(other):
			continue
		
		var dist: float = actor.global_position.distance_to(other.global_position)
		if dist > current_detection_range:
			continue
		
		# Already perceived and not expired
		if _perceived_enemies.has(other) and _perceived_enemies[other] > 0:
			if dist < nearest_dist:
				nearest = other
				nearest_dist = dist
			continue
		
		# Attempt a new perception check if cooldown allows
		if _perception_cooldown_timer <= 0 and actor.skill_check_component:
			var target_dex: float = 0.0
			if other.get("ability_scores_component"):
				target_dex = other.ability_scores_component.dexterity
			
			var dc: float = dist + target_dex
			var result: Dictionary = actor.skill_check_component.perform_check(
				actor.ability_scores_component.wisdom,
				dc,
				"Perception",
				other
			)
			_perception_cooldown_timer = PERCEPTION_COOLDOWN
			
			if result["success"]:
				_perceived_enemies[other] = PERCEPTION_EXPIRY
				if dist < nearest_dist:
					nearest = other
					nearest_dist = dist
	
	return nearest

## Returns true if the actor's health is below the flee threshold.
func _should_flee() -> bool:
	if not actor or not actor.health_component:
		return false
	return actor.health_component.current_health / actor.health_component.max_health < flee_health_threshold

## Rotates the actor to face a world position (updates visual facing).
func _face_target(target_pos: Vector3) -> void:
	var dir := (target_pos - actor.global_position).normalized()
	dir.y = 0
	if dir.length() > 0.01 and actor.visual_component:
		actor.visual_component.last_attack_dir = dir
		# Nudge velocity slightly so the visual component picks up the direction
		actor.velocity.x = dir.x * 0.01
		actor.velocity.z = dir.z * 0.01

## Called when the movement component reports being stuck.
func _on_movement_stuck() -> void:
	_choose_new_target()

## Returns a string representation of the current control state for debugging tools.
func get_debug_state() -> String:
	if is_controlled:
		return "CONTROLLED"
	if state_machine:
		return state_machine.get_current_state_name().to_upper()
	return "AI"
