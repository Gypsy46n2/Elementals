## The Actor class serves as the base for all living entities in the game world, including the player and NPCs.
## It handles fundamental mechanics such as health management, movement, mana systems, and combat actions.
## The script is designed to be modular, utilizing components for health, movement, and decision-making (AI).
class_name Actor
extends CharacterBody3D

@export_group("Identity")
@export var is_playable: bool = true
@export var is_friendly: bool = true
@export var element_type: String = "none"

@export_group("Stats")
@export var move_speed: float = 3.0:
	set(v):
		move_speed = v
		if movement_component: movement_component.move_speed = v
@export var max_hp: float = 10.0:
	set(v):
		max_hp = v
		if health_component: health_component.max_health = v
@export var max_mana: float = 100.0:
	set(v):
		max_mana = v
		if mana_component: mana_component.max_mana = v
@export var armor_class: int = 10:
	set(v):
		armor_class = v
		if health_component: health_component.armor_class = v

@export_group("Combat")
@export var projectile_scene: PackedScene:
	set(v):
		projectile_scene = v
		if projectile_component: projectile_component.projectile_scene = v
@export var lob_projectile_scene: PackedScene:
	set(v):
		lob_projectile_scene = v
		if projectile_component: projectile_component.lob_projectile_scene = v
@export var projectile_speed: float = 14.0:
	set(v):
		projectile_speed = v
		if projectile_component: projectile_component.projectile_speed = v
@export var projectile_lifetime: float = 5.0:
	set(v):
		projectile_lifetime = v
		if projectile_component: projectile_component.projectile_lifetime = v
@export var projectile_max_range: float = 45.0:
	set(v):
		projectile_max_range = v
		if projectile_component: projectile_component.projectile_max_range = v

@export_group("Visuals")
@export var should_bob: bool = false:
	set(v):
		should_bob = v
		if bob_component: bob_component.should_bob = v

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

var is_controlled: bool = false:
	set(value):
		is_controlled = value
		if decision_component: decision_component.is_controlled = value
		if movement_component: movement_component.is_controlled = value

var current_mana: float:
	get: return mana_component.current_mana if mana_component else 0.0
	set(v): if mana_component: mana_component.current_mana = v

var _last_dir: StringName:
	get: return visual_component.last_dir if visual_component else &"down"
	set(v): if visual_component: visual_component.last_dir = v

var weapon: WeaponData:
	get: return equipped_weapon

var equipped_weapon: WeaponData:
	get: return weapon_component.weapon_data if weapon_component else null
	set(v): if weapon_component: weapon_component.weapon_data = v

signal mana_changed(new_mana: float, max_mana: float)

var _arena_grid: ArenaGrid
var _origin: Vector3
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()
	_arena_grid = _find_arena_grid()
	_origin = global_transform.origin
	
	_setup_components()

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
	# 1. Visuals & Particles
	visual_component = _add_comp(ActorVisualComponent.new())
	visual_component.setup(self, _body)
	
	particle_component = _add_comp(ActorParticleComponent.new())
	particle_component.setup(self)
	
	# 2. Health & Damage
	health_component = DamageComponent.find_health_component(self)
	if not health_component:
		health_component = _add_comp(HealthComponent.new())
	
	health_component.bar_color = visual_component.get_actor_color()
	health_component.health_depleted.connect(die)
	health_component.max_health = max_hp
	health_component.current_health = max_hp
	health_component.armor_class = armor_class

	# 3. Movement & AI
	movement_component = _add_comp(MovementComponent.new())
	movement_component.target = self
	movement_component.is_controlled = is_controlled
	movement_component.move_speed = move_speed
	
	decision_component = _add_comp(_create_decision_component())
	decision_component.movement_component = movement_component
	decision_component.actor = self
	decision_component.is_controlled = is_controlled

	# 4. Mana & Stun
	mana_component = _add_comp(ManaComponent.new())
	mana_component.mana_changed.connect(func(c, m): mana_changed.emit(c, m))
	mana_component.max_mana = max_mana
	mana_component.current_mana = max_mana
	mana_component.setup(self)
	
	stun_component = _add_comp(StunComponent.new())
	stun_component.setup(self)

	# 5. Tile Interaction
	tile_interaction_component = _add_comp(ActorTileInteractionComponent.new())
	tile_interaction_component.setup(self)

	# 6. RPG Systems
	ability_scores_component = _add_comp(AbilityScoresComponent.new())
	ability_scores_component.setup(self)

	skill_check_component = _add_comp(SkillCheckComponent.new())
	skill_check_component.setup(self)

	# 7. Polish (Bob, Debug)
	bob_component = _add_comp(BobComponent.new())
	bob_component.should_bob = should_bob
	bob_component.setup(_body, _body.position.y if _body else 0.0, particle_component.mana_particles_container)

	debug_component = _add_comp(DebugComponent.new())
	debug_component.setup(self)

	# 8. Combat (Projectile, Weapon)
	projectile_component = _add_comp(ProjectileComponent.new())
	projectile_component.projectile_scene = projectile_scene
	projectile_component.lob_projectile_scene = lob_projectile_scene
	projectile_component.projectile_speed = projectile_speed
	projectile_component.projectile_lifetime = projectile_lifetime
	projectile_component.projectile_max_range = projectile_max_range
	projectile_component.setup(self)

	weapon_component = _add_comp(WeaponComponent.new())
	weapon_component.setup(self)

# Helper for adding and returning components
func _add_comp(comp: Node) -> Node:
	add_child(comp)
	return comp

func _create_decision_component() -> ActorDecisionComponent:
	return ActorDecisionComponent.new()

func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint(): return
	move_and_slide()

func take_damage(amount: float, type: String = "normal", direction: Vector3 = Vector3.ZERO) -> void:
	if health_component:
		health_component.take_damage(amount, type, direction)

func show_miss(direction: Vector3 = Vector3.ZERO) -> void:
	if health_component:
		health_component.show_miss(direction)

func stun(duration: float) -> void:
	if stun_component: stun_component.stun(duration)

func is_stunned() -> bool:
	return stun_component.is_stunned() if stun_component else false

func die() -> void:
	if weapon_component: weapon_component.drop_inventory()
	GameEvents.actor_died.emit(self)
	respawn()

func respawn() -> void:
	if health_component:
		health_component.reset()
	
	global_transform.origin = _origin + Vector3(0, 0.5, 0)
	velocity = Vector3.ZERO
	if decision_component:
		decision_component.set("_movement_target", _origin)
	
	force_update_transform()

func cycle_attack_pattern() -> void:
	if projectile_component: projectile_component.cycle_attack_pattern()

func prev_attack_pattern() -> void:
	if projectile_component: projectile_component.prev_attack_pattern()

func apply_pickup_penalty() -> void:
	if movement_component: movement_component.apply_pickup_penalty()

func hit_by_projectile(projectile: BaseProjectile) -> void:
	var dir = projectile._direction if "_direction" in projectile else Vector3.ZERO
	take_damage(projectile.remaining_charges, projectile.element_type, dir)

func get_actor_color() -> Color:
	return Color.WHITE

func get_main_action_progress() -> float:
	return weapon_component.get_main_action_progress() if weapon_component else 1.0

func get_cardinal_direction(dir: Vector3) -> StringName:
	return visual_component.get_cardinal_direction(dir) if visual_component else &"down"
