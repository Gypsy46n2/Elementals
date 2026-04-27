class_name TreeFeature
extends Node3D

enum State { PINECONE, SAPLING, TREE, STUMP, BURNT_STUMP }

@export var current_state: State = State.TREE:
	set(v):
		if current_state == v and current_state_node != null:
			return
		current_state = v
		if is_node_ready():
			_update_state_node(v)

@export var species: TreeSpecies

var current_state_node: TreeState = null

var timer: float = 10.0
var grass_spread_timer: float = 5.0 # Timer for spreading grass
var is_moving: bool = false
var target_tile: HexTileData = null
var tile: HexTileData = null

func set_tile(p_tile: HexTileData) -> void:
	tile = p_tile
var move_speed: float = 8.0 # Slightly faster movement for pinecones

## Tree Health System
var health_component: HealthComponent
# movement_component is used for moving pinecones when they are pushed by elements (water/headbutt)
var movement_component: MovementComponent 
var fire_damage_accumulator: float = 0.0 # To track 1 HP per second

## Cap on pinecones per tree: Track the pinecone this tree spawned.
var spawned_pinecone_ref: WeakRef = null

@onready var sprite: Sprite3D = $Sprite3D
@onready var collision_body: StaticBody3D = $StaticBody3D
@onready var audio_player: AudioStreamPlayer3D = $AudioStreamPlayer3D

func _ready() -> void:
	_setup_health_component()
	_setup_movement_component()
	if audio_player:
		audio_player.stream = load("res://assets/SoundFiles/Tree fall.mp3")
	
	_update_state_node(current_state)

func _setup_health_component() -> void:
	health_component = DamageComponent.find_health_component(self)
	if not health_component:
		health_component = HealthComponent.new()
		add_child(health_component)
	
	var max_hp = species.max_health if species else 5.0
	health_component.max_health = max_hp
	health_component.current_health = max_hp
	health_component.bar_color = Color.GREEN
	health_component.bar_offset = Vector3(0, 2.5, 0)
	health_component.health_depleted.connect(_on_health_depleted)

func _setup_movement_component() -> void:
	movement_component = MovementComponent.new()
	movement_component.name = "MovementComponent"
	movement_component.move_speed = move_speed
	movement_component.interpolation_finished.connect(_on_movement_finished)
	add_child(movement_component)

func _on_movement_finished() -> void:
	if not target_tile:
		return
		
	# Arrived at tile
	# Check if the tile we arrived at is burning
	if target_tile.tile_type == TileConstants.Type.FIRE:
		take_damage(5.0, true) # Pinecone dies instantly to fire on landing
		return

	if tile:
		tile.feature = null
	
	tile = target_tile
	tile.feature = self
	position = tile.position
	
	is_moving = false
	target_tile = null
	timer = 10.0

func _on_health_depleted() -> void:
	if current_state_node:
		var is_fire = (tile and tile.tile_type == TileConstants.Type.FIRE)
		current_state_node.die(is_fire)

func _update_state_node(new_state: State) -> void:
	# Cleanup old state
	if current_state_node:
		current_state_node.exit()
		remove_child(current_state_node)
		current_state_node.queue_free()
	
	# Initialize new state
	match new_state:
		State.PINECONE: current_state_node = TreePineconeState.new()
		State.SAPLING: current_state_node = TreeSaplingState.new()
		State.TREE: current_state_node = TreeMaturedState.new()
		State.STUMP: current_state_node = TreeStumpState.new()
		State.BURNT_STUMP: current_state_node = TreeBurntStumpState.new()
	
	if current_state_node:
		current_state_node.name = "CurrentState"
		current_state_node.tree = self
		add_child(current_state_node)
		current_state_node.enter()

func _process(delta: float) -> void:
	# If on a burning tile, burn the feature
	var on_fire = tile and tile.tile_type == TileConstants.Type.FIRE
	if on_fire:
		fire_damage_accumulator += delta
		if fire_damage_accumulator >= 1.0:
			take_damage(1.0, true)
			fire_damage_accumulator -= 1.0
	else:
		fire_damage_accumulator = 0.0

	if current_state_node:
		current_state_node.update(delta)

func take_damage(amount: float, is_fire: bool) -> void:
	if health_component:
		health_component.take_damage(amount, "fire" if is_fire else "normal")

func _update_collision() -> void:
	if not collision_body: return
	# Trees and stumps block movement
	var should_block = current_state in [State.TREE, State.STUMP, State.BURNT_STUMP]
	collision_body.process_mode = PROCESS_MODE_INHERIT if should_block else PROCESS_MODE_DISABLED

func _is_on_tree_tile() -> bool:
	if not tile: return false
	var arena = get_parent() as ArenaGrid
	if not arena: return false
	
	# Check neighbors for other trees
	for n in arena._get_neighbors(tile):
		if n.feature and n.feature is TreeFeature:
			if n.feature.current_state in [State.TREE, State.STUMP, State.BURNT_STUMP, State.SAPLING]:
				return true
	return false

func _spawn_pinecone() -> void:
	if not tile: return
	var arena = get_parent() as ArenaGrid
	if not arena: return
	
	if spawned_pinecone_ref and spawned_pinecone_ref.get_ref():
		var pine = spawned_pinecone_ref.get_ref() as TreeFeature
		if pine.current_state == State.PINECONE:
			return
			
	var pinecone = load("res://Play Space/tree_feature.tscn").instantiate()
	pinecone.species = species
	pinecone.current_state = State.PINECONE
	arena.add_child(pinecone)
	pinecone.set_tile(tile)
	pinecone.position = tile.position
	spawned_pinecone_ref = weakref(pinecone)

func apply_element(element: String, direction: Vector3 = Vector3.ZERO) -> bool:
	if current_state_node:
		return current_state_node.handle_element(element, direction)
	return false

func apply_fire() -> bool:
	# For instant fire application, we deal max damage to kill it and turn it to burnt stump
	take_damage(5.0, true)
	return true

func apply_water(direction: Vector3 = Vector3.ZERO) -> bool:
	return apply_element("water", direction)

func _push_pinecone(direction: Vector3) -> void:
	if is_moving or not movement_component or not tile: return
	var arena = get_parent() as ArenaGrid
	if not arena: return
	
	var push_dir = direction.normalized()
	if push_dir.length_squared() < 0.1:
		push_dir = Vector3(randf_range(-1,1), 0, randf_range(-1,1)).normalized()

	# Find the neighbor whose position is closest to the push direction
	var max_dot = -2.0
	var best_neighbor = null
	for n in arena._get_neighbors(tile):
		# Pinecones cannot move onto tiles that have other features (fences, house) or are interior yard
		if n.feature != null:
			continue
		if n in arena.farmstead_interior_tiles:
			continue
			
		var dir_to_n = (n.position - tile.position).normalized()
		var dot = push_dir.dot(dir_to_n)
		if dot > max_dot:
			max_dot = dot
			best_neighbor = n
			
	if best_neighbor:
		target_tile = best_neighbor
		is_moving = true
		var target_pos = target_tile.position
		target_pos.y = global_position.y
		movement_component.move_to(target_pos)
