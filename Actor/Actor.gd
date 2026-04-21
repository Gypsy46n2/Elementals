class_name Actor
extends CharacterBody3D

@export_group("Movement")
@export var move_speed: float = 7.0:
	set(v):
		move_speed = v
		if movement_component:
			movement_component.move_speed = v
@export var acceleration: float = 60.0
@export var friction: float = 20.0
@export var jump_force: float = 8.0
@export var gravity: float = 9.8

@export var roam_radius: float = 22.0
@export var bob_amplitude: float = 0.35
@export var bob_speed: float = 2.2
@export_range(1.0, 10.0, 0.25) var trigger_range_in_tiles: float = 3.0
@export var should_bob: bool = true
@export var projectile_interval: float = 1.0
@export var projectile_speed: float = 14.0
@export var projectile_lifetime: float = 5.0
@export var projectile_max_range_in_tiles: float = 20.0
@export var projectile_charge_capacity: int = 5
@export var projectile_scene: PackedScene
@export var lob_projectile_scene: PackedScene

enum AttackPattern { SINGLE, SPREAD, LOB }
var current_attack_pattern: AttackPattern = AttackPattern.SINGLE

@export_group("Ability Scores")
@export var strength: float = 1.0: # Physical power
	set(v): strength = v
@export var dexterity: float = 1.0: # Agility
	set(v): dexterity = v
@export var constitution: float = 1.0: # Endurance
	set(v): constitution = v
@export var intelligence: float = 1.0: # Reasoning and memory
	set(v): intelligence = v
@export var wisdom: float = 1.0: # Perception and insight
	set(v): wisdom = v
@export var charisma: float = 1.0: # Force of personality
	set(v): charisma = v

@export_group("Stats")
@export var max_hp: int = 10
@export var max_mana: float = 100.0
@export var mana_regen_rate: float = 20.0
@export var shot_mana_cost: float = 20.0

@onready var tile_detector: RayCast3D = $TileDetector
@onready var _body: Node3D = get_node_or_null("Body")

var health_component: HealthComponent
var movement_component: MovementComponent
var decision_component: ActorDecisionComponent

var is_controlled: bool = false:
	set(value):
		is_controlled = value
		if is_controlled:
			print(name, ": Controlled!")
		if decision_component:
			decision_component.is_controlled = value
		if movement_component:
			movement_component.is_controlled = value

var element_type: String = "none"

signal mana_changed(new_mana: float, max_mana: float)

static var debug_enabled: bool = false

var current_mana: float = 100.0:
	set(value):
		var old_int = int(current_mana)
		current_mana = value
		if int(current_mana) != old_int:
			mana_changed.emit(current_mana, max_mana)

var _arena_grid: ArenaGrid
var _base_height: float
var _bob_phase: float = 0.0
var _origin: Vector3
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _ground_tile: HexTileData

var _stun_timer: float = 0.0
var _stun_visual: Node3D

var _base_visual_y: float = 0.0
var _mana_particles: Array[Sprite3D] = []
var _mana_particles_container: Node3D
var _mana_phase: float = 0.0
var _mana_texture: Texture2D
var _debug_label: Label3D

func _ready() -> void:
	_rng.randomize()
	_mana_phase = _rng.randf_range(0, 100) # Random start
	_arena_grid = get_parent() as ArenaGrid
	if not _arena_grid:
		var scene = get_tree().get_current_scene()
		if scene:
			_arena_grid = scene.get_node_or_null("Arena") as ArenaGrid
	
	_origin = global_transform.origin
	_base_height = global_position.y
	
	if _body:
		_base_visual_y = _body.position.y
		print(name, ": Body found.")
	else:
		print(name, ": Body NOT found!")
	
	_setup_health_component()
	_setup_components()
	current_mana = max_mana
	
	_mana_texture = _get_mana_particle_texture()
	
	_setup_actor()
	_setup_mana_visuals()
	_setup_stun_visuals()
	_setup_debug_label()

func _setup_debug_label() -> void:
	_debug_label = Label3D.new()
	_debug_label.pixel_size = 0.005
	_debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_debug_label.no_depth_test = true
	_debug_label.render_priority = 20
	_debug_label.position = Vector3(0, 2.5, 0) # Above HP bar
	_debug_label.outline_render_priority = 19
	_debug_label.modulate = Color.YELLOW
	add_child(_debug_label)

func _setup_stun_visuals() -> void:
	# StunVisual3D is the Looney Tunes style spinning birds and stars
	_stun_visual = StunVisual3D.new()
	_stun_visual.position = Vector3(0, 2.0, 0) # Higher up for effect
	_stun_visual.visible = false
	_stun_visual.set_process(false)
	add_child(_stun_visual)

func _setup_health_component() -> void:
	health_component = DamageComponent.find_health_component(self)
	if not health_component:
		health_component = HealthComponent.new()
		add_child(health_component)
	
	health_component.max_health = max_hp
	health_component.current_health = max_hp
	health_component.bar_color = get_actor_color()
	health_component.bar_offset = Vector3(0, 1.5, 0) # Adjust as needed
	health_component.health_depleted.connect(die)

func _setup_components() -> void:
	# Movement Component
	movement_component = MovementComponent.new()
	movement_component.name = "MovementComponent"
	movement_component.target = self
	movement_component.move_speed = move_speed
	movement_component.acceleration = acceleration
	movement_component.friction = friction
	movement_component.gravity = gravity
	movement_component.jump_force = jump_force
	movement_component.is_controlled = is_controlled
	add_child(movement_component)
	
	# Decision Component
	decision_component = ActorDecisionComponent.new()
	decision_component.name = "DecisionComponent"
	decision_component.movement_component = movement_component
	decision_component.actor = self
	decision_component.is_controlled = is_controlled
	add_child(decision_component)

func _setup_mana_visuals() -> void:
	_mana_particles_container = Node3D.new()
	_mana_particles_container.name = "ManaParticlesContainer"
	add_child(_mana_particles_container)
	# Set initial position to match where Body would be
	if _body:
		_mana_particles_container.position.y = _body.position.y


func _get_mana_particle_texture() -> Texture2D:
	return null

func take_damage(amount: float, type: String = "normal") -> void:
	if health_component:
		health_component.take_damage(amount, type)
	print(name, " took ", amount, " damage (", type, ").")

func hit_by_projectile(projectile: BaseProjectile) -> void:
	## Default implementation for being hit by a projectile.
	take_damage(projectile.remaining_charges)

func stun(duration: float) -> void:
	_stun_timer = max(_stun_timer, duration)

func is_stunned() -> bool:
	return _stun_timer > 0.0

func die() -> void:
	GameEvents.actor_died.emit(self)

	# Respawns at the original position provided by ArenaGrid
	if health_component:
		health_component.current_health = health_component.max_health
	
	global_transform.origin = _origin + Vector3(0, 0.5, 0) # spawn slightly higher
	velocity = Vector3.ZERO
	if decision_component:
		decision_component._movement_target = _origin
	
	# Ensure physics is reset
	force_update_transform()

func _setup_actor() -> void:
	# Virtual method for subclasses to configure their specific visuals/particles
	pass

func _process(delta: float) -> void:
	_update_mana_visuals(delta)
	_update_stun(delta)
	_update_debug_label()

func _update_debug_label() -> void:
	if not _debug_label: return
	
	_debug_label.visible = debug_enabled
	if not debug_enabled: return
	
	var state_text = "IDLE"
	if decision_component:
		state_text = decision_component.get_debug_state()
	
	if is_stunned():
		state_text += " (STUNNED)"
	
	_debug_label.text = state_text

func _update_stun(delta: float) -> void:
	if _stun_timer > 0:
		_stun_timer -= delta
		if _stun_visual and not _stun_visual.visible:
			_stun_visual.visible = true
			_stun_visual.set_process(true)
	else:
		if _stun_visual and _stun_visual.visible:
			_stun_visual.visible = false
			_stun_visual.set_process(false)

func _update_mana_visuals(delta: float) -> void:
	var texture = _mana_texture
	if not texture:
		# Cleanup if no texture
		for p in _mana_particles:
			if is_instance_valid(p): p.queue_free()
		_mana_particles.clear()
		return
		
	var charges = 0
	if shot_mana_cost > 0:
		charges = int(current_mana / 5)
	
	# Sync number of sprites
	while _mana_particles.size() < charges:
		var sprite = Sprite3D.new()
		sprite.texture = texture
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.03
		sprite.render_priority = 5
		sprite.transparent = true
		if "shading_mode" in sprite:
			sprite.set("shading_mode", BaseMaterial3D.SHADING_MODE_UNSHADED)
		
		# Give it unique movement data
		# We'll use a random rotation to orient the figure-8 orbit in 3D space
		var rand_axis = Vector3(_rng.randf_range(-1,1), _rng.randf_range(-1,1), _rng.randf_range(-1,1)).normalized()
		if rand_axis == Vector3.ZERO: rand_axis = Vector3.UP
		var orbit_basis = Basis(rand_axis, _rng.randf_range(0, TAU))
		
		sprite.set_meta("orbit_rotation", orbit_basis)
		sprite.set_meta("phase_offset", _rng.randf_range(0, TAU))
		sprite.set_meta("speed_mult", _rng.randf_range(0.3, 0.6)) # Slow and loitering
		
		if _mana_particles_container:
			_mana_particles_container.add_child(sprite)
		else:
			add_child(sprite)
		_mana_particles.append(sprite)
		
	while _mana_particles.size() > charges:
		var sprite = _mana_particles.pop_back()
		if is_instance_valid(sprite):
			sprite.queue_free()
		
	# Update positions using figure-8 pattern
	_mana_phase += delta
	var orbit_radius = 1.1
	for i in range(_mana_particles.size()):
		var sprite = _mana_particles[i]
		if not is_instance_valid(sprite): continue
		
		var phase = _mana_phase * sprite.get_meta("speed_mult") + sprite.get_meta("phase_offset")
		
		# Figure 8 in local space: Lissajous curve
		var lx = sin(phase) * orbit_radius
		var ly = sin(2.0 * phase) * (orbit_radius * 0.5)
		var lz = cos(phase) * (orbit_radius * 0.2) # Adds some 3D depth to the path
		
		var orbit_rot = sprite.get_meta("orbit_rotation") as Basis
		sprite.position = orbit_rot * Vector3(lx, ly, lz)
		
		# Scale pulse slightly to feel more alive
		var s = 0.8 + sin(phase * 1.5) * 0.15
		sprite.scale = Vector3.ONE * s

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	# Mana regeneration for everyone
	var current_regen = mana_regen_rate
	if is_on_floor():
		_update_tile_below()
		if _ground_tile:
			if element_type == "fire" and _ground_tile.current_state == TileConstants.State.FIRE:
				current_regen *= 2.0
			elif element_type == "water" and _ground_tile.current_state == TileConstants.State.PUDDLE:
				current_regen *= 2.0
				
	current_mana = min(current_mana + current_regen * delta, max_mana)
		
	# Movement is now handled by DecisionComponent (which calls MovementComponent)
	# But we still need move_and_slide here because components shouldn't ideally call it 
	# (or they can, but CharacterBody3D usually wants it in physics_process)
	
	# Actually, MovementComponent doesn't call move_and_slide in my current implementation.
	# It just updates velocity.
	
	move_and_slide()

	_apply_bob(delta)
	
	if is_on_floor():
		_apply_ground_effects()
	
	if not is_controlled:
		if current_mana >= max_mana and not is_stunned():
			_launch_projectile()

func _get_move_speed() -> float:
	return move_speed

func _get_jump_force() -> float:
	return jump_force

func _handle_controlled_movement(_delta: float) -> void:
	pass # Handled by DecisionComponent

func get_actor_color() -> Color:
	# Virtual method for subclasses
	return Color.WHITE

func get_main_action_progress() -> float:
	## Returns the progress (0.0 to 1.0) of the primary action (mana for projectiles, etc.).
	if max_mana > 0:
		return current_mana / max_mana
	return 1.0

func cycle_attack_pattern() -> void:
	current_attack_pattern = (current_attack_pattern + 1) % AttackPattern.size() as AttackPattern
	print(name, " switched to ", AttackPattern.keys()[current_attack_pattern], " pattern.")
	if is_controlled and _arena_grid:
		_arena_grid._update_ui() # Update UI to show pattern if we add it there

func launch_projectile_at(target_position: Vector3) -> void:
	if not _arena_grid:
		return
	
	match current_attack_pattern:
		AttackPattern.SINGLE:
			_launch_single_shot(target_position)
		AttackPattern.SPREAD:
			_launch_spread_shot(target_position)
		AttackPattern.LOB:
			_launch_lob_shot(target_position)

func _launch_single_shot(target_position: Vector3) -> void:
	if not projectile_scene or current_mana < shot_mana_cost:
		return
	current_mana -= shot_mana_cost
	_do_launch_projectile(target_position)

func _launch_spread_shot(target_position: Vector3) -> void:
	var spread_cost = shot_mana_cost * 1.5
	if not projectile_scene or current_mana < spread_cost:
		return
	current_mana -= spread_cost
	
	var spawn_position = global_transform.origin
	var base_direction = (target_position - spawn_position).normalized()
	base_direction.y = 0
	if base_direction == Vector3.ZERO: base_direction = Vector3.FORWARD
	
	var angles = [-30, -15, 0, 15, 30]
	for angle in angles:
		var rad = deg_to_rad(angle)
		var direction = base_direction.rotated(Vector3.UP, rad)
		# Spread shots are only 1 charge each
		_do_launch_projectile_with_params(projectile_scene, spawn_position, direction, projectile_speed, 1, projectile_lifetime)

func _launch_lob_shot(target_position: Vector3) -> void:
	var lob_cost = shot_mana_cost * 1.2
	var scene = lob_projectile_scene if lob_projectile_scene else projectile_scene
	if not scene or current_mana < lob_cost:
		return
	current_mana -= lob_cost
	
	var spawn_position = global_transform.origin
	var parent = get_parent() if get_parent() else get_tree().get_current_scene()
	
	# Launch 5 projectiles that all target the same general area
	for i in range(5):
		var projectile = scene.instantiate()
		parent.add_child(projectile)
		projectile.global_transform = Transform3D(Basis(), spawn_position)
		
		# Slight offset for target to make it look like a cluster
		var offset = Vector3(_rng.randf_range(-1.0, 1.0), 0, _rng.randf_range(-1.0, 1.0))
		var cluster_target = target_position + offset
		
		if projectile.has_method("initialize_lob"):
			projectile.initialize_lob(_arena_grid, spawn_position, cluster_target, projectile_speed * 0.8, 1, projectile_lifetime)
		elif projectile.has_method("initialize"):
			var dir = (cluster_target - spawn_position).normalized()
			projectile.initialize(_arena_grid, spawn_position, 0.0, dir, projectile_speed, 1, projectile_lifetime)

func _do_launch_projectile(target_position: Vector3) -> void:
	var spawn_position = global_transform.origin
	var direction = (target_position - spawn_position).normalized()
	direction.y = 0
	if direction == Vector3.ZERO: direction = Vector3.FORWARD
	_do_launch_projectile_with_params(projectile_scene, spawn_position, direction, projectile_speed, projectile_charge_capacity, projectile_lifetime)

func _do_launch_projectile_with_params(scene: PackedScene, spawn_pos: Vector3, direction: Vector3, p_velocity: float, charges: int, p_lifetime: float) -> void:
	var projectile = scene.instantiate()
	var parent = get_parent() if get_parent() else get_tree().get_current_scene()
	parent.add_child(projectile)
	projectile.global_transform = Transform3D(Basis(), spawn_pos)
	if projectile.has_method("initialize"):
		projectile.initialize(_arena_grid, spawn_pos, _effective_range_world(), direction, p_velocity, charges, p_lifetime, _projectile_max_range_world())

func _handle_wandering(_delta: float) -> void:
	pass # Handled by DecisionComponent

func _apply_bob(delta: float) -> void:
	var bob_offset: float = 0.0
	if should_bob:
		_bob_phase += bob_speed * delta
		bob_offset = sin(_bob_phase) * bob_amplitude
	
	if _body:
		_body.position.y = _base_visual_y + bob_offset
	
	if _mana_particles_container:
		_mana_particles_container.position.y = _base_visual_y + bob_offset
	
	if not _body and not is_controlled:
		# Fallback if no Body node found
		global_position.y = _base_height + bob_offset

func _apply_ground_effects() -> void:
	if _ground_tile:
		if _check_tile_damage(_ground_tile):
			return
		_do_tile_effect(_ground_tile)

func _check_tile_damage(tile: HexTileData) -> bool:
	if element_type == "fire":
		if tile.current_state == TileConstants.State.MUD:
			take_damage(1)
			if _arena_grid:
				_arena_grid.set_tile_state(tile, TileConstants.State.DIRT)
			return true
		elif tile.current_state == TileConstants.State.PUDDLE:
			take_damage(2)
			if _arena_grid:
				_arena_grid.set_tile_state(tile, TileConstants.State.DIRT)
			return true
	elif element_type == "water":
		if tile.current_state == TileConstants.State.FIRE:
			take_damage(1)
			if _arena_grid:
				_arena_grid.set_tile_state(tile, TileConstants.State.MUD)
			return true
	return false

func _do_tile_effect(_tile: HexTileData) -> void:
	# Virtual method for subclasses
	pass

func _update_tile_below() -> void:
	if _arena_grid:
		_ground_tile = _arena_grid.get_tile_data_at_world_position(global_transform.origin)
	else:
		_ground_tile = null

func _launch_projectile() -> void:
	# Randomly choose an attack pattern for AI
	var patterns = [AttackPattern.SINGLE, AttackPattern.SPREAD, AttackPattern.LOB]
	current_attack_pattern = patterns[_rng.randi_range(0, patterns.size() - 1)]
	
	# Pick a random direction and distance for the AI to "aim" at
	var heading = _rng.randf_range(0.0, TAU)
	var distance = _rng.randf_range(5.0, _effective_range_world())
	var target_position = global_transform.origin + Vector3(cos(heading), 0.0, sin(heading)) * distance
	
	launch_projectile_at(target_position)

func _effective_range_world() -> float:
	var base_hex_size = _arena_grid.hex_size if _arena_grid else 1.0
	return trigger_range_in_tiles * base_hex_size * 1.5

func _projectile_max_range_world() -> float:
	var base_hex_size = _arena_grid.hex_size if _arena_grid else 1.0
	return projectile_max_range_in_tiles * base_hex_size * 1.5

func _choose_new_target() -> void:
	if decision_component:
		decision_component._choose_new_target()


## Standardizes GPUParticles3D setup for actors and tiles.
static func setup_gpu_particles(particles: GPUParticles3D, params: Dictionary) -> void:
	if not particles: return
	
	particles.emitting = params.get("emitting", true)
	particles.amount = params.get("amount", 20)
	particles.lifetime = params.get("lifetime", 1.0)
	particles.local_coords = params.get("local_coords", true)
	
	var material = particles.process_material as ParticleProcessMaterial
	if not material:
		material = ParticleProcessMaterial.new()
		particles.process_material = material
		
	material.direction = params.get("direction", Vector3.UP)
	material.spread = params.get("spread", 45.0)
	material.initial_velocity_min = params.get("velocity_min", 1.0)
	material.initial_velocity_max = params.get("velocity_max", 2.0)
	material.gravity = params.get("gravity", Vector3.ZERO)
	material.scale_min = params.get("scale_min", 0.1)
	material.scale_max = params.get("scale_max", 0.2)
	material.color = params.get("color", Color.WHITE)
	
	if params.has("emission_shape"):
		material.emission_shape = params["emission_shape"]
	if params.has("emission_box_extents"):
		material.emission_box_extents = params["emission_box_extents"]
	if params.has("damping_min"):
		material.damping_min = params["damping_min"]
	if params.has("damping_max"):
		material.damping_max = params["damping_max"]

	if not particles.draw_pass_1:
		var pass_mesh = QuadMesh.new()
		var p_mat = StandardMaterial3D.new()
		p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p_mat.vertex_color_use_as_albedo = true
		p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		
		if params.has("texture"):
			var tex = params["texture"]
			if tex is String:
				p_mat.albedo_texture = load(tex)
			elif tex is Texture2D:
				p_mat.albedo_texture = tex
				
		pass_mesh.material = p_mat
		particles.draw_pass_1 = pass_mesh
