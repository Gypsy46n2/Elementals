## The Actor class serves as the base for all living entities in the game world, including the player and NPCs.
## It handles fundamental mechanics such as health management, movement, mana systems, and combat actions.
## The script is designed to be modular, utilizing components for health, movement, and decision-making (AI).
class_name Actor
extends CharacterBody3D

@export_group("Components")
@export var is_playable: bool = true
@export var is_friendly: bool = true
@export var element_type: String = "none"

@onready var tile_detector: RayCast3D = $TileDetector
@onready var _body: Node3D = get_node_or_null("Body")

var health_component: HealthComponent
var movement_component: MovementComponent
var decision_component: Node
var projectile_component: ProjectileComponent
var stun_component: StunComponent
var mana_component: ManaComponent
var tile_interaction_component: ActorTileInteractionComponent
var bob_component: BobComponent
var debug_component: DebugComponent
var weapon_component: WeaponComponent
var visual_component: ActorVisualComponent
var particle_component: ActorParticleComponent

var ability_scores_component: AbilityScoresComponent
var skill_check_component: SkillCheckComponent

# Pending stats set before components are ready
var _pending_move_speed: float = 3.0
var _pending_max_hp: float = 10.0
var _pending_max_mana: float = 100.0
var _pending_armor_class: int = 10
var _pending_should_bob: bool = false
var _pending_projectile_scene: PackedScene
var _pending_lob_projectile_scene: PackedScene
var _pending_projectile_speed: float = 14.0
var _pending_projectile_lifetime: float = 5.0
var _pending_projectile_max_range: float = 45.0

# Delegates for compatibility
var projectile_speed: float:
	get: return projectile_component.projectile_speed if projectile_component else _pending_projectile_speed
	set(v):
		if projectile_component: projectile_component.projectile_speed = v
		else: _pending_projectile_speed = v

var projectile_lifetime: float:
	get: return projectile_component.projectile_lifetime if projectile_component else _pending_projectile_lifetime
	set(v):
		if projectile_component: projectile_component.projectile_lifetime = v
		else: _pending_projectile_lifetime = v

var projectile_max_range: float:
	get: return projectile_component.projectile_max_range if projectile_component else _pending_projectile_max_range
	set(v):
		if projectile_component: projectile_component.projectile_max_range = v
		else: _pending_projectile_max_range = v

# Delegates for compatibility
var move_speed: float:
	get: return movement_component.move_speed if movement_component else _pending_move_speed
	set(v):
		if movement_component: movement_component.move_speed = v
		else: _pending_move_speed = v

var max_hp: float:
	get: return health_component.max_health if health_component else _pending_max_hp
	set(v):
		if health_component: health_component.max_health = v
		else: _pending_max_hp = v

var current_mana: float:
	get: return mana_component.current_mana if mana_component else 0.0
	set(v): if mana_component: mana_component.current_mana = v

var max_mana: float:
	get: return mana_component.max_mana if mana_component else _pending_max_mana
	set(v):
		if mana_component: mana_component.max_mana = v
		else: _pending_max_mana = v

var armor_class: int:
	get: return health_component.armor_class if health_component else _pending_armor_class
	set(v):
		if health_component: health_component.armor_class = v
		else: _pending_armor_class = v

var should_bob: bool:
	get: return bob_component.should_bob if bob_component else _pending_should_bob
	set(v):
		if bob_component: bob_component.should_bob = v
		else: _pending_should_bob = v

var _last_dir: StringName:
	get: return visual_component.last_dir if visual_component else &"down"
	set(v): if visual_component: visual_component.last_dir = v

var projectile_scene: PackedScene:
	get: return projectile_component.projectile_scene if projectile_component else _pending_projectile_scene
	set(v):
		if projectile_component: projectile_component.projectile_scene = v
		else: _pending_projectile_scene = v

var lob_projectile_scene: PackedScene:
	get: return projectile_component.lob_projectile_scene if projectile_component else _pending_lob_projectile_scene
	set(v):
		if projectile_component: projectile_component.lob_projectile_scene = v
		else: _pending_lob_projectile_scene = v

var weapon: WeaponData:
	get: return equipped_weapon

var equipped_weapon: WeaponData:
	get: return weapon_component.weapon_data if weapon_component else null
	set(v): if weapon_component: weapon_component.weapon_data = v

var is_controlled: bool = false:
	set(value):
		is_controlled = value
		if decision_component: decision_component.is_controlled = value
		if movement_component: movement_component.is_controlled = value

signal mana_changed(new_mana: float, max_mana: float)

var _arena_grid: ArenaGrid
var _origin: Vector3
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_arena_grid = _find_arena_grid()
	_origin = global_transform.origin
	
	_setup_components()
	_setup_actor()

func _on_weapon_selected(p_weapon: WeaponData) -> void:
	if weapon_component:
		weapon_component._on_weapon_selected(p_weapon)

func _find_arena_grid() -> ArenaGrid:
	var grid = get_parent() as ArenaGrid
	if not grid:
		var scene = get_tree().get_current_scene()
		if scene: grid = scene.get_node_or_null("Arena") as ArenaGrid
	return grid

func _setup_components() -> void:
	# 1. Visuals & Health
	visual_component = ActorVisualComponent.new()
	add_child(visual_component)
	visual_component.setup(self, _body)
	
	particle_component = ActorParticleComponent.new()
	add_child(particle_component)
	particle_component.setup(self)
	
	health_component = DamageComponent.find_health_component(self)
	if not health_component:
		health_component = HealthComponent.new()
		add_child(health_component)
	health_component.bar_color = visual_component.get_actor_color()
	health_component.health_depleted.connect(die)
	health_component.max_health = _pending_max_hp
	health_component.current_health = _pending_max_hp
	health_component.armor_class = _pending_armor_class

	# 2. Movement & AI
	movement_component = MovementComponent.new()
	movement_component.target = self
	movement_component.is_controlled = is_controlled
	add_child(movement_component)
	movement_component.move_speed = _pending_move_speed
	
	decision_component = _create_decision_component()
	decision_component.movement_component = movement_component
	decision_component.actor = self
	decision_component.is_controlled = is_controlled
	add_child(decision_component)

	# 3. Systems (Mana, Stun, Tiles)
	mana_component = ManaComponent.new()
	mana_component.mana_changed.connect(func(c, m): mana_changed.emit(c, m))
	add_child(mana_component)
	mana_component.max_mana = _pending_max_mana
	mana_component.current_mana = _pending_max_mana
	mana_component.setup(self)
	particle_component.setup_mana_visuals(visual_component.get_mana_particle_texture())

	stun_component = StunComponent.new()
	add_child(stun_component)
	stun_component.setup(self)

	tile_interaction_component = ActorTileInteractionComponent.new()
	add_child(tile_interaction_component)
	tile_interaction_component.setup(self)

	# 4. RPG Components
	ability_scores_component = AbilityScoresComponent.new()
	add_child(ability_scores_component)
	ability_scores_component.setup(self)

	skill_check_component = SkillCheckComponent.new()
	add_child(skill_check_component)
	skill_check_component.setup(self)

	# 5. Visual Effects (Bob, Debug)
	bob_component = BobComponent.new()
	add_child(bob_component)
	bob_component.should_bob = _pending_should_bob
	bob_component.setup(_body, _body.position.y if _body else 0.0, particle_component.mana_particles_container)

	debug_component = DebugComponent.new()
	add_child(debug_component)
	debug_component.setup(self)

	# 6. Combat (Projectile, Weapon)
	projectile_component = ProjectileComponent.new()
	add_child(projectile_component)
	projectile_component.projectile_scene = _pending_projectile_scene
	projectile_component.lob_projectile_scene = _pending_lob_projectile_scene
	projectile_component.setup(self)

	weapon_component = WeaponComponent.new()
	add_child(weapon_component)
	weapon_component.setup(self)

func _create_decision_component() -> ActorDecisionComponent:
	return ActorDecisionComponent.new()

func _process(delta: float) -> void:
	particle_component.update_mana_visuals(delta, mana_component.current_mana, mana_component.shot_mana_cost)
	stun_component.update_stun(delta)
	var debug_state = decision_component.get_debug_state() if decision_component.has_method("get_debug_state") else "Unknown"
	debug_component.update_debug_label(debug_state, is_stunned())

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint(): return
		
	if is_on_floor():
		tile_interaction_component.update_tile_below()
		tile_interaction_component.apply_ground_effects()
	
	mana_component.regenerate_mana(delta)
	move_and_slide()
	bob_component.apply_bob(delta)
	
	if not is_controlled:
		if mana_component.current_mana >= mana_component.max_mana and not is_stunned():
			projectile_component.launch_projectile_ai(mana_component)

func take_damage(amount: float, type: String = "normal", direction: Vector3 = Vector3.ZERO) -> void:
	if health_component:
		health_component.take_damage(amount, type, direction)

func show_miss(direction: Vector3 = Vector3.ZERO) -> void:
	if health_component:
		health_component.show_miss(direction)

func stun(duration: float) -> void:
	stun_component.stun(duration)

func is_stunned() -> bool:
	return stun_component.is_stunned()

func die() -> void:
	if weapon_component: weapon_component.drop_inventory()
	GameEvents.actor_died.emit(self)

	if health_component:
		health_component.current_health = health_component.max_health
	
	global_transform.origin = _origin + Vector3(0, 0.5, 0)
	velocity = Vector3.ZERO
	if decision_component:
		decision_component.set("_movement_target", _origin)
	
	force_update_transform()

func cycle_attack_pattern() -> void:
	projectile_component.cycle_attack_pattern()

func prev_attack_pattern() -> void:
	projectile_component.prev_attack_pattern()

func launch_projectile_at(target_position: Vector3) -> void:
	projectile_component.launch_projectile_at(target_position, mana_component)

func secondary_attack_at(target_position: Vector3) -> void:
	if weapon_component:
		visual_component.update_attack_direction(target_position)
		weapon_component.secondary_attack(target_position)

func throw_weapon_at(target_position: Vector3) -> void:
	if weapon_component:
		visual_component.update_attack_direction(target_position)
		weapon_component.secondary_attack(target_position, true)

func add_weapon_ammo(p_weapon_data: WeaponData, amount: int) -> void:
	if weapon_component: weapon_component.add_weapon_ammo(p_weapon_data, amount)

func unequip_weapon() -> void:
	if weapon_component: weapon_component.unequip_weapon()

func apply_pickup_penalty() -> void:
	if movement_component: movement_component.apply_pickup_penalty()

func hit_by_projectile(projectile: BaseProjectile) -> void:
	var dir = projectile._direction if "_direction" in projectile else Vector3.ZERO
	take_damage(projectile.remaining_charges, projectile.element_type, dir)

func get_actor_color() -> Color:
	return Color.WHITE

func get_main_action_progress() -> float:
	if weapon_component: return weapon_component.get_cooldown_progress()
	if mana_component: return mana_component.current_mana / mana_component.max_mana
	return 1.0

func _update_attack_direction(target_position: Vector3) -> void:
	visual_component.update_attack_direction(target_position)

func get_cardinal_direction(dir: Vector3) -> StringName:
	return visual_component.get_cardinal_direction(dir)

func _choose_new_target() -> void:
	if decision_component and decision_component.has_method("_choose_new_target"):
		decision_component.call("_choose_new_target")

func _setup_actor() -> void:
	pass

func _do_tile_effect(_tile: HexTileData) -> void:
	pass

func _get_mana_particle_texture() -> Texture2D:
	return null
