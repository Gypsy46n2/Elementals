## The Actor class serves as the base for all living entities in the game world, including the player and NPCs.
## It handles fundamental mechanics such as health management, movement, mana systems, and combat actions.
## The script is designed to be modular, utilizing components for health, movement, and decision-making (AI).
## It provides a common interface for dealing damage, managing status effects like stunning, and interacting with
## the environmental tile grid. Subclasses can override virtual methods to provide specialized visuals,
## particle effects, or unique behaviors while benefiting from the core logic implemented here.
class_name Actor
extends CharacterBody3D

@export_group("Movement")
@export var move_speed: float = 3.0:
	set(v):
		move_speed = v
		if movement_component:
			movement_component.move_speed = v
@export var acceleration: float = 60.0
@export var friction: float = 20.0
@export var jump_force: float = 4.0
@export var gravity: float = 9.8

@export var roam_radius: float = 22.0
@export var bob_amplitude: float = 0.35
@export var bob_speed: float = 2.2
@export_range(1.0, 10.0, 0.25) var trigger_range_in_tiles: float = 3.0
@export var should_bob: bool = false
@export var is_playable: bool = true
@export var is_friendly: bool = true
@export var projectile_interval: float = 1.0
@export var projectile_speed: float = 14.0
@export var projectile_lifetime: float = 5.0
@export var projectile_max_range_in_tiles: float = 20.0
@export var projectile_charge_capacity: int = 5
@export var projectile_scene: PackedScene
@export var lob_projectile_scene: PackedScene

@export_group("Ability Scores")
@export var strength: float = 1.0
@export var dexterity: float = 1.0
@export var constitution: float = 1.0
@export var intelligence: float = 1.0
@export var wisdom: float = 1.0
@export var charisma: float = 1.0

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
var projectile_component: ProjectileComponent
var stun_component: StunComponent
var mana_component: ManaComponent
var tile_interaction_component: TileInteractionComponent
var bob_component: BobComponent
var debug_component: DebugComponent

var weapon: Weapon
var equipped_weapon: WeaponData:
	get:
		return weapon.weapon_data if weapon else null
	set(v):
		if weapon:
			weapon.weapon_data = v

var current_mana: float:
	get:
		return mana_component.current_mana if mana_component else 0.0
	set(v):
		if mana_component:
			mana_component.current_mana = v

var _last_dir: StringName = &"down"
var element_type: String = "none"

signal mana_changed(new_mana: float, max_mana: float)

var is_controlled: bool = false:
	set(value):
		is_controlled = value
		if decision_component:
			decision_component.is_controlled = value
		if movement_component:
			movement_component.is_controlled = value

var _arena_grid: ArenaGrid
var _base_height: float
var _origin: Vector3
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_arena_grid = get_parent() as ArenaGrid
	if not _arena_grid:
		var scene = get_tree().get_current_scene()
		if scene:
			_arena_grid = scene.get_node_or_null("Arena") as ArenaGrid
	
	_origin = global_transform.origin
	_base_height = global_position.y
	
	var base_visual_y = 0.0
	if _body:
		base_visual_y = _body.position.y
		print(name, ": Body found.")
	
	_setup_components(base_visual_y)
	_setup_actor()

func _on_weapon_selected(p_weapon: WeaponData) -> void:
	if weapon:
		weapon._on_weapon_selected(p_weapon)

func _setup_components(base_visual_y: float) -> void:
	# Health Component
	health_component = DamageComponent.find_health_component(self)
	if not health_component:
		health_component = HealthComponent.new()
		add_child(health_component)
	health_component.max_health = max_hp
	health_component.current_health = max_hp
	health_component.bar_color = get_actor_color()
	health_component.bar_offset = Vector3(0, 1.5, 0)
	health_component.health_depleted.connect(die)

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
	decision_component = _create_decision_component()
	decision_component.name = "DecisionComponent"
	decision_component.movement_component = movement_component
	decision_component.actor = self
	decision_component.is_controlled = is_controlled
	add_child(decision_component)

	# Mana Component
	mana_component = ManaComponent.new()
	mana_component.max_mana = max_mana
	mana_component.mana_regen_rate = mana_regen_rate
	mana_component.shot_mana_cost = shot_mana_cost
	mana_component.mana_changed.connect(func(c, m): mana_changed.emit(c, m))
	add_child(mana_component)
	mana_component.setup(self, _get_mana_particle_texture())

	# Stun Component
	stun_component = StunComponent.new()
	add_child(stun_component)
	stun_component.setup(self)

	# Tile Interaction Component
	tile_interaction_component = TileInteractionComponent.new()
	add_child(tile_interaction_component)
	tile_interaction_component.setup(self)

	# Bob Component
	bob_component = BobComponent.new()
	bob_component.bob_amplitude = bob_amplitude
	bob_component.bob_speed = bob_speed
	bob_component.should_bob = should_bob
	add_child(bob_component)
	bob_component.setup(_body, base_visual_y, mana_component._mana_particles_container)

	# Debug Component
	debug_component = DebugComponent.new()
	add_child(debug_component)
	debug_component.setup(self)

	# Projectile Component
	projectile_component = ProjectileComponent.new()
	projectile_component.projectile_speed = projectile_speed
	projectile_component.projectile_lifetime = projectile_lifetime
	projectile_component.projectile_max_range_in_tiles = projectile_max_range_in_tiles
	projectile_component.projectile_charge_capacity = projectile_charge_capacity
	projectile_component.projectile_scene = projectile_scene
	projectile_component.lob_projectile_scene = lob_projectile_scene
	add_child(projectile_component)
	projectile_component.setup(self)

	# Weapon
	_setup_weapon()

func _setup_weapon() -> void:
	weapon = Weapon.new()
	weapon.name = "Weapon"
	add_child(weapon)
	weapon.setup(self)

func _create_decision_component() -> ActorDecisionComponent:
	return ActorDecisionComponent.new()

func _process(delta: float) -> void:
	mana_component.update_mana_visuals(delta)
	stun_component.update_stun(delta)
	debug_component.update_debug_label(decision_component.get_debug_state(), is_stunned())

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
		
	var current_regen_mult = 1.0
	if is_on_floor():
		tile_interaction_component.update_tile_below()
		var ground_tile = tile_interaction_component.get_ground_tile()
		if ground_tile:
			if element_type == "fire" and ground_tile.current_state == TileConstants.State.FIRE:
				current_regen_mult = 2.0
			elif element_type == "water" and ground_tile.current_state == TileConstants.State.PUDDLE:
				current_regen_mult = 2.0
				
	mana_component.regenerate_mana(delta, current_regen_mult)
	move_and_slide()
	bob_component.apply_bob(delta)
	
	if is_on_floor():
		tile_interaction_component.apply_ground_effects()
	
	if not is_controlled:
		if mana_component.current_mana >= mana_component.max_mana and not is_stunned():
			projectile_component.launch_projectile_ai(mana_component)

func take_damage(amount: float, type: String = "normal", direction: Vector3 = Vector3.ZERO) -> void:
	if health_component:
		health_component.take_damage(amount, type, direction)
	print(name, " took ", amount, " damage (", type, ").")

func stun(duration: float) -> void:
	stun_component.stun(duration)

func is_stunned() -> bool:
	return stun_component.is_stunned()

func die() -> void:
	if weapon:
		weapon.drop_inventory()
	GameEvents.actor_died.emit(self)

	if health_component:
		health_component.current_health = health_component.max_health
	
	global_transform.origin = _origin + Vector3(0, 0.5, 0)
	velocity = Vector3.ZERO
	if decision_component:
		decision_component._movement_target = _origin
	
	force_update_transform()

func cycle_attack_pattern() -> void:
	projectile_component.cycle_attack_pattern()

func prev_attack_pattern() -> void:
	projectile_component.prev_attack_pattern()

func launch_projectile_at(target_position: Vector3) -> void:
	projectile_component.launch_projectile_at(target_position, mana_component)

func secondary_attack_at(target_position: Vector3) -> void:
	if weapon:
		weapon.update_attack_direction(target_position)
		weapon.secondary_attack(target_position)

func throw_weapon_at(target_position: Vector3) -> void:
	if weapon:
		weapon.update_attack_direction(target_position)
		weapon.secondary_attack(target_position, true)

func add_weapon_ammo(p_weapon_data: WeaponData, amount: int) -> void:
	if weapon:
		weapon.add_weapon_ammo(p_weapon_data, amount)

func unequip_weapon() -> void:
	if weapon:
		weapon.unequip_weapon()

func apply_pickup_penalty() -> void:
	if movement_component:
		movement_component.apply_pickup_penalty()

func hit_by_projectile(projectile: BaseProjectile) -> void:
	var dir = projectile._direction if "_direction" in projectile else Vector3.ZERO
	take_damage(projectile.remaining_charges, projectile.element_type, dir)

func _get_move_speed() -> float:
	return move_speed

func _get_jump_force() -> float:
	return jump_force

func get_actor_color() -> Color:
	return Color.WHITE

func get_main_action_progress() -> float:
	if weapon:
		return weapon.get_cooldown_progress()
	if mana_component:
		return mana_component.current_mana / mana_component.max_mana
	return 1.0

func _update_attack_direction(target_position: Vector3) -> void:
	if weapon:
		weapon.update_attack_direction(target_position)

func _effective_range_world() -> float:
	var base_hex_size = _arena_grid.hex_size if _arena_grid else 1.0
	return trigger_range_in_tiles * base_hex_size * 1.5

func _projectile_max_range_world() -> float:
	var base_hex_size = _arena_grid.hex_size if _arena_grid else 1.0
	return projectile_max_range_in_tiles * base_hex_size * 1.5

func _choose_new_target() -> void:
	if decision_component:
		decision_component._choose_new_target()

func _setup_actor() -> void:
	pass

func _do_tile_effect(_tile: HexTileData) -> void:
	pass

func _get_mana_particle_texture() -> Texture2D:
	return null

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
