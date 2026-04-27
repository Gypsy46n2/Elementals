## Specialized decision component for Actors that navigate a hexagonal grid.
## Handles tile-based movement, obstacle avoidance, and basic combat logic.
class_name ActorDecisionComponent
extends DecisionComponent

## Reference to the actor node this component controls.
@export var actor: Node3D
## Maximum distance from the starting position the actor will roam.
@export var roam_radius: float = 22.0

## Tracks the previous tile to avoid immediate backtracking.
var _previous_tile: HexTileData
## The specific 3D coordinate the actor is currently trying to reach.
var _movement_target: Vector3
## Local RNG for randomized movement decisions.
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	if not actor and get_parent() is Actor:
		actor = get_parent()
	
	if actor:
		_movement_target = actor.global_transform.origin
		if movement_component:
			# If the movement component gets stuck, force a recalculation of the target.
			movement_component.stuck.connect(_choose_new_target)
		# Use call_deferred to ensure arena grid and other dependencies are fully initialized.
		call_deferred("_choose_new_target")

func _physics_process(delta: float) -> void:
	# Disable logic if the actor is currently stunned.
	if actor and actor.is_stunned():
		if movement_component:
			movement_component.apply_gravity(delta)
			movement_component.stop(delta)
		return
		
	super._physics_process(delta)

## Implements the autonomous logic for NPCs: moves toward a target and fires projectiles.
func _handle_ai_logic(delta: float) -> void:
	if not actor or not actor._arena_grid or not movement_component:
		return
		
	var current_pos_2d = Vector2(actor.global_transform.origin.x, actor.global_transform.origin.z)
	var target_pos_2d = Vector2(_movement_target.x, _movement_target.z)
	
	# If we've reached the current target tile, pick a new one.
	if current_pos_2d.distance_to(target_pos_2d) < 0.2:
		_choose_new_target()
		
	var direction = (target_pos_2d - current_pos_2d).normalized()
	var dir_3d = Vector3(direction.x, 0, direction.y)
	
	# Calculate a steering vector to push the actor away from Trees, Stones, and Cliffs.
	var avoidance = _get_obstacle_avoidance_vector()
	if avoidance.length_squared() > 0.01:
		# Blend the target direction with the avoidance force.
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
	
	# Check a radius around the actor for obstacles (roughly 2 hexes away).
	var nearby_tiles = actor._arena_grid.get_tiles_within_distance(my_pos, 3.5)
	for tile in nearby_tiles:
		var is_obstacle = false
		var obstacle_weight = 1.0
		
		# 1. Check for Trees and Fences (Visual features that block movement)
		if tile.feature:
			if tile.feature is TreeFeature:
				if tile.feature.current_state in [TreeFeature.State.TREE, TreeFeature.State.STUMP, TreeFeature.State.BURNT_STUMP]:
					is_obstacle = true
					obstacle_weight = 1.5 # Trees are solid and wide.
			elif tile.feature is FenceFeature:
				is_obstacle = true
				obstacle_weight = 1.8 # Fences are narrow but must be navigated around.
		
		# 2. Check for Stone Walls (The hard boundaries of the arena)
		if not is_obstacle and tile.current_state == TileConstants.State.STONE:
			is_obstacle = true
			obstacle_weight = 2.0 # Arena borders should be avoided aggressively.
			
		# 3. Check for Cliffs (Abrupt changes in height)
		if not is_obstacle:
			var tile_y = actor._arena_grid._get_tile_surface_y(tile)
			if tile_y > ground_y + 0.3: # Stepping up onto high ground.
				is_obstacle = true
				obstacle_weight = 1.4
			elif tile_y < ground_y - 1.5: # Avoiding accidental falls off high ledges.
				is_obstacle = true
				obstacle_weight = 0.8
		
		if is_obstacle:
			var feature_pos = tile.position
			var diff = my_pos - feature_pos
			diff.y = 0
			var dist = diff.length()
			
			# Avoidance threshold: slightly larger than a hex to ensure early detection.
			var threshold = 2.2
			if dist < threshold and dist > 0.1:
				var weight = (threshold - dist) / threshold * obstacle_weight
				var repulsion = diff.normalized() * weight
				avoidance += repulsion
				
				# Add a "sidestep" force to break symmetry.
				# This prevents the AI from jittering when heading perfectly straight at a wall.
				var move_dir = Vector3(actor.velocity.x, 0, actor.velocity.z).normalized()
				if move_dir.length_squared() > 0.1:
					var dot = move_dir.dot(-diff.normalized())
					if dot > 0.5: # Heading mostly at the obstacle.
						var side_dir = Vector3(-diff.z, 0, diff.x).normalized()
						# Bias towards the side we are already leaning towards.
						if move_dir.dot(side_dir) < 0:
							side_dir = -side_dir
						avoidance += side_dir * weight * 1.0
				
	return avoidance

## Selects a new adjacent tile to move toward.
func _choose_new_target() -> void:
	if not actor or not actor._arena_grid:
		return
		
	actor.tile_interaction_component.update_tile_below()
	var ground_tile = actor.tile_interaction_component.get_ground_tile()
	
	if ground_tile and actor._arena_grid:
		# Filter neighbors for those that are actually traversable (no stone, no trees, no high walls).
		var neighbors = _get_traversable_neighbors(ground_tile)
		
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

## Helper to find neighbors that the NPC can actually walk onto.
func _get_traversable_neighbors(tile: HexTileData, max_step_up: float = 3.0) -> Array[HexTileData]:
	if not tile or not actor or not actor._arena_grid: return []
	var ground_y = actor._arena_grid._get_tile_surface_y(tile)
	return actor._arena_grid._get_neighbors(tile).filter(func(t):
		if t == null or t.current_state == TileConstants.State.STONE: return false
		if t.feature:
			if t.feature is TreeFeature:
				if t.feature.current_state in [TreeFeature.State.TREE, TreeFeature.State.STUMP, TreeFeature.State.BURNT_STUMP]:
					return false
			elif t.feature is FenceFeature:
				return false
		var ty = actor._arena_grid._get_tile_surface_y(t)
		if ty > ground_y + max_step_up: return false
		return true
	)
