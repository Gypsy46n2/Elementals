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
@export var should_bob: bool = true
@export var is_playable: bool = true
@export var is_friendly: bool = true
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

var weapon: Weapon
var equipped_weapon: WeaponData
var _last_dir: StringName = &"down"

var is_controlled: bool = false:
	set(value):
		is_controlled = value
		if is_controlled:
			print(name, ": Controlled!")
			var wl = get_node_or_null("/root/ItemsAutoload")
			if wl and wl.selected_weapon:
				_on_weapon_selected(wl.selected_weapon)
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

## Initializes the actor by setting up random seeds, finding the arena grid, storing original transforms,
## and calling various setup functions for components, mana, and visuals. It ensures all internal references
## and initial states (like max mana) are correctly established before the actor starts processing.
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

## Creates and configures a Label3D used for displaying debug information above the actor's head.
## This label is only made visible when the global debug mode is enabled, providing a quick way to
## see the current state or AI intentions of the actor during development.
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

## Instantiates and configures the stun visual effect, typically used to indicate when the actor is
## incapacitated. It sets the relative position and initial visibility of the stun effect, 
## ensuring it is ready to be toggled on or off when the actor's stun state changes.
func _setup_stun_visuals() -> void:
	# StunVisual3D is the Looney Tunes style spinning birds and stars
	_stun_visual = StunVisual3D.new()
	_stun_visual.position = Vector3(0, 1.2, 0) # Higher up for effect
	_stun_visual.visible = false
	_stun_visual.set_process(false)
	add_child(_stun_visual)

## Locates or creates a HealthComponent for the actor, setting up its maximum health, initial health,
## and UI bar properties. It also connects the health depletion signal to the actor's die function,
## centralizing life cycle management within the health system.
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

## Creates and initializes the primary weapon node for the actor, linking it back to the actor instance.
## It also subscribes to global weapon selection events from the ItemsAutoload to handle inventory
## changes and ensures the correct weapon is equipped if the actor is player-controlled.
func _setup_weapon() -> void:
	weapon = Weapon.new()
	weapon.name = "Weapon"
	add_child(weapon)
	weapon.setup(self)
	
	var wl = get_node_or_null("/root/ItemsAutoload")
	if wl:
		wl.weapon_selected.connect(_on_global_weapon_selected)
		if is_controlled and wl.selected_weapon:
			_on_weapon_selected(wl.selected_weapon)

## Responds to weapon selection signals emitted globally, filtering for changes that apply to this actor.
## If the actor is currently being controlled by the player, it updates the equipped weapon to match
## the global selection, facilitating seamless inventory swaps across the game.
func _on_global_weapon_selected(p_weapon: WeaponData) -> void:
	if is_controlled:
		_on_weapon_selected(p_weapon)

## Updates the actor's equipped weapon data and synchronizes the active weapon node with the new data.
## This function is called when a specific weapon is chosen for the actor, ensuring that the visual
## representation and functional properties (like damage or ammo) are correctly applied.
func _on_weapon_selected(p_weapon: WeaponData) -> void:
	equipped_weapon = p_weapon
	if weapon:
		weapon.weapon_data = p_weapon

## Instantiates and initializes the modular components for movement and decision-making (AI).
## This setup links these components to the actor and configures their initial parameters,
## such as speed and control status, to ensure the actor's behavior matches its exported properties.
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
	decision_component = _create_decision_component()
	decision_component.name = "DecisionComponent"
	decision_component.movement_component = movement_component
	decision_component.actor = self
	decision_component.is_controlled = is_controlled
	add_child(decision_component)

func _create_decision_component() -> ActorDecisionComponent:
	return ActorDecisionComponent.new()

## Sets up a container node for mana-related particle effects, ensuring it is positioned correctly
## relative to the actor's visual body. This container provides a dedicated space for managing
## the floating sprites that represent the actor's current mana pool.
func _setup_mana_visuals() -> void:
	_mana_particles_container = Node3D.new()
	_mana_particles_container.name = "ManaParticlesContainer"
	add_child(_mana_particles_container)
	# Set initial position to match where Body would be
	if _body:
		_mana_particles_container.position.y = _body.position.y


## A virtual method intended to return the texture used for mana particles. Subclasses can override
## this to provide unique textures for different types of actors, allowing for visual distinction
## between various characters' magical energy representations.
func _get_mana_particle_texture() -> Texture2D:
	return null

## Processes incoming damage by forwarding the amount and type to the health component and
## triggering a visual damage indicator. It also logs the damage event for debugging purposes,
## providing feedback on the actor's durability and the effectiveness of attacks.
func take_damage(amount: float, type: String = "normal", direction: Vector3 = Vector3.ZERO) -> void:
	if health_component:
		health_component.take_damage(amount, type)
	_show_damage_indicator(amount, direction)
	print(name, " took ", amount, " damage (", type, ").")

## Spawns a floating damage indicator in the world at the actor's position to visually communicate
## the impact of an attack. It handles the placement of the indicator, ensuring it appears
## correctly in the scene hierarchy and moves according to the specified hit direction.
func _show_damage_indicator(amount: float, direction: Vector3) -> void:
	var indicator = DamageIndicator.new()
	var parent = get_parent()
	if parent:
		parent.add_child(indicator)
		indicator.global_position = global_position + Vector3(0, 1.5, 0)
	else:
		add_child(indicator)
		indicator.position = Vector3(0, 1.5, 0)
	
	indicator.setup(amount, direction)

## Handles being struck by a projectile, extracting the damage information and direction from the
## projectile instance to apply damage to the actor. This serves as a standard entry point for
## projectile-based combat interactions, ensuring consistent damage application.
func hit_by_projectile(projectile: BaseProjectile) -> void:
	## Default implementation for being hit by a projectile.
	var dir = projectile._direction if "_direction" in projectile else Vector3.ZERO
	take_damage(projectile.remaining_charges, projectile.element_type, dir)

func stun(duration: float) -> void:
	_stun_timer = max(_stun_timer, duration)

## Checks if the actor is currently in a stunned state by examining the remaining stun timer.
## This is frequently used to gate actions and movement, ensuring the actor remains stationary
## while incapacitated by a stun effect.
func is_stunned() -> bool:
	return _stun_timer > 0.0

func die() -> void:
	_drop_inventory()
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

## Drops the currently equipped weapon as a pickup item in the world when the actor dies or
## chooses to discard it. It calculates the correct projectile scene based on the weapon type
## and initializes the dropped item with the remaining ammo and weapon data.
func _drop_inventory() -> void:
	if not weapon or not equipped_weapon or equipped_weapon.name == "Unarmed strike":
		return
		
	if not _arena_grid: return
	
	# Drop the current weapon and its remaining ammo
	var projectile_path = "res://Actor/Projectiles/ArrowProjectile.tscn"
	if equipped_weapon.name == "Dagger":
		projectile_path = "res://Actor/Projectiles/DaggerProjectile.tscn"
		
	var proj_scene = load(projectile_path)
	var drop = proj_scene.instantiate()
	get_parent().add_child(drop)
	drop.global_position = global_position + Vector3(0, 0.5, 0)
	
	drop.initialize(_arena_grid, self, global_position, 0.0, Vector3.FORWARD, 0.0, 1, 100.0)
	drop.source_weapon_data = equipped_weapon
	drop.remaining_charges = weapon.current_ammo
	drop._stick() # Make it a pickup
	
	# Revert to unarmed after dropping
	unequip_weapon()

func _setup_actor() -> void:
	# Virtual method for subclasses to configure their specific visuals/particles
	pass

## The standard per-frame update loop that handles mana visuals, stun state timers, and debug
## label updates. It ensures that time-dependent visual elements and status effects are
## updated consistently regardless of physics steps.
func _process(delta: float) -> void:
	_update_mana_visuals(delta)
	_update_stun(delta)
	_update_debug_label()

## Synchronizes the content and visibility of the debug label with the actor's current internal state.
## It displays information like the AI's current decision state or stun status, helping
## developers visualize the actor's logic flow in real-time.
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

## Increments or decrements the stun timer based on the elapsed time and updates the visibility
## of stun-related visual effects. When the timer reaches zero, it disables the stun visuals,
## signaling that the actor is no longer incapacitated.
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

## Manages the generation and movement of mana particle sprites based on the actor's current mana pool.
## It adds or removes sprites to match the mana level and animates them in a figure-eight pattern,
## providing a clear visual representation of how much mana the actor has available.
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

## Handles physics-related updates including mana regeneration, ground effect application,
## and character movement via move_and_slide. It also triggers AI-driven projectile attacks
## when mana is full and the actor is not incapacitated, maintaining the core gameplay loop.
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

## Returns the base move speed of the actor. This serves as a getter that can be overridden by
## subclasses to implement dynamic speed modifiers or specific movement logic while maintaining
## a consistent interface for the movement component.
func _get_move_speed() -> float:
	return move_speed

## Returns the base jump force of the actor. Similar to move speed, this provides a standard way
## for components to access the actor's jumping capability, which can be modified by status effects
## or specialized character traits in subclasses.
func _get_jump_force() -> float:
	return jump_force

## A placeholder for handling player-controlled movement. In the current component-based architecture,
## this logic is moved to the DecisionComponent, but the function remains as a hook or for potential
## specific overrides in complex actor implementations.
func _handle_controlled_movement(_delta: float) -> void:
	pass # Handled by DecisionComponent

## Returns the representative color for the actor, often used for UI elements like health bars.
## This is a virtual method that subclasses should override to provide visual consistency
## across different factions or character types in the game.
func get_actor_color() -> Color:
	# Virtual method for subclasses
	return Color.WHITE

func get_main_action_progress() -> float:
	## Returns the progress (0.0 to 1.0) of the primary action.
	if weapon:
		return weapon.get_cooldown_progress()
	if max_mana > 0:
		return current_mana / max_mana
	return 1.0

## Determines the cardinal direction (up, down, left, right) the actor should face when attacking
## a target. It uses the camera's perspective to map the 3D direction vector into a 2D orientation,
## ensuring that attack animations and effects align with player expectations.
func _update_attack_direction(target_position: Vector3) -> void:
	var dir = (target_position - global_position).normalized()
	dir.y = 0
	
	var camera = get_viewport().get_camera_3d()
	if camera:
		var cam_basis = camera.global_transform.basis
		var cam_right = cam_basis.x
		var cam_forward = -cam_basis.z
		cam_forward.y = 0
		cam_forward = cam_forward.normalized()
		
		var dot_right = dir.dot(cam_right)
		var dot_forward = dir.dot(cam_forward)
		
		if abs(dot_right) > abs(dot_forward):
			if dot_right > 0:
				_last_dir = &"right"
			else:
				_last_dir = &"left"
		else:
			if dot_forward > 0:
				_last_dir = &"up"
			else:
				_last_dir = &"down"

## Cycles through the available attack patterns (Single, Spread, Lob) for the actor.
## This allows the player or AI to switch their combat style, and it triggers a UI update
## to reflect the newly selected pattern for better player feedback.
func cycle_attack_pattern() -> void:
	current_attack_pattern = (current_attack_pattern + 1) % AttackPattern.size() as AttackPattern
	print(name, " switched to ", AttackPattern.keys()[current_attack_pattern], " pattern.")
	if is_controlled and _arena_grid:
		_arena_grid._update_ui() # Update UI to show pattern if we add it there

## Initiates a projectile attack targeting a specific position in the world. Depending on the
## equipped weapon or current attack pattern, it delegates the actual firing logic to specialized
## functions that handle different projectile behaviors and resource costs.
func launch_projectile_at(target_position: Vector3) -> void:
	if not _arena_grid:
		return
	
	if weapon:
		_update_attack_direction(target_position)
		weapon.swing(target_position)
		return
	
	match current_attack_pattern:
		AttackPattern.SINGLE:
			_launch_single_shot(target_position)
		AttackPattern.SPREAD:
			_launch_spread_shot(target_position)
		AttackPattern.LOB:
			_launch_lob_shot(target_position)

## Executes the secondary attack of the equipped weapon towards the target position. This is
## typically used for special moves or alternative fire modes that differ from the primary
## projectile launch, adding depth to the actor's combat capabilities.
func secondary_attack_at(target_position: Vector3) -> void:
	if not _arena_grid:
		return
	
	if weapon:
		_update_attack_direction(target_position)
		weapon.secondary_attack(target_position)

## Performs a weapon throw action towards the target position, essentially using the weapon as
## a one-time projectile. This consumes the weapon's availability but provides a powerful
## ranged option in certain combat scenarios.
func throw_weapon_at(target_position: Vector3) -> void:
	if not _arena_grid:
		return
	
	if weapon:
		_update_attack_direction(target_position)
		weapon.secondary_attack(target_position, true)

## Adds ammunition to the actor's equipped weapon or equips a new weapon if the actor is currently
## unarmed. It ensures ammo counts stay within defined maximums and facilitates automatic weapon
## acquisition when picking up items in the world.
func add_weapon_ammo(p_weapon_data: WeaponData, amount: int) -> void:
	if equipped_weapon == p_weapon_data:
		if weapon:
			weapon.current_ammo = min(weapon.current_ammo + amount, p_weapon_data.max_ammo)
	elif equipped_weapon.name == "Unarmed strike":
		# Check if we have this weapon in our "inventory" or if it matches the one we just picked up
		# For now, if we are unarmed, we just take it.
		_on_weapon_selected(p_weapon_data)
		if weapon:
			weapon.current_ammo = amount

## Applies a temporary movement speed reduction to the actor, typically after picking up an item.
## This penalty adds a weight or recovery feel to interacting with the environment, briefly slowing
## the actor down before returning them to their normal move speed.
func apply_pickup_penalty() -> void:
	if movement_component:
		movement_component.speed_multiplier = 0.5
		var timer := get_tree().create_timer(0.5)
		timer.timeout.connect(func():
			if movement_component:
				movement_component.speed_multiplier = 1.0
		)

## Reverts the actor to an unarmed state by selecting the "Unarmed strike" weapon from the global
## items list. This is called when a weapon is dropped or broken, ensuring the actor always has
## a basic form of interaction/attack available.
func unequip_weapon() -> void:
	var wl = get_node_or_null("/root/ItemsAutoload")
	if wl:
		for w in wl.weapons:
			if w.name == "Unarmed strike":
				_on_weapon_selected(w)
				break

## Fires a single projectile at the target if the actor has sufficient mana. It deducts the mana
## cost and triggers the projectile spawning logic, representing the most basic form of
## active magical attack.
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

## Fires a cluster of projectiles that arc through the air towards a target location. This lobbing
## behavior is useful for bypassing obstacles and creates a concentrated zone of impact,
## often using a specialized lobbing projectile scene for correct physics.
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
			projectile.initialize_lob(_arena_grid, self, spawn_position, cluster_target, projectile_speed * 0.8, 1, projectile_lifetime)
		elif projectile.has_method("initialize"):
			var dir = (cluster_target - spawn_position).normalized()
			projectile.initialize(_arena_grid, self, spawn_position, 0.0, dir, projectile_speed, 1, projectile_lifetime)

## Calculates the firing direction and initiates a projectile launch using the actor's default
## projectile settings. It ensures the direction is normalized and restricted to the horizontal
## plane, providing a consistent firing baseline for standard attacks.
func _do_launch_projectile(target_position: Vector3) -> void:
	var spawn_position = global_transform.origin
	var direction = (target_position - spawn_position).normalized()
	direction.y = 0
	if direction == Vector3.ZERO: direction = Vector3.FORWARD
	_do_launch_projectile_with_params(projectile_scene, spawn_position, direction, projectile_speed, projectile_charge_capacity, projectile_lifetime)

## Handles the actual instantiation and initialization of a projectile node with specific parameters.
## This function connects the projectile to the arena grid, sets its owner, and defines its
## trajectory and lifetime, serving as the low-level firing mechanism for all projectile types.
func _do_launch_projectile_with_params(scene: PackedScene, spawn_pos: Vector3, direction: Vector3, p_velocity: float, charges: int, p_lifetime: float) -> void:
	var projectile = scene.instantiate()
	var parent = get_parent() if get_parent() else get_tree().get_current_scene()
	parent.add_child(projectile)
	projectile.global_transform = Transform3D(Basis(), spawn_pos)
	if projectile.has_method("initialize"):
		projectile.initialize(_arena_grid, self, spawn_pos, _effective_range_world(), direction, p_velocity, charges, p_lifetime, _projectile_max_range_world())

## A placeholder for handling non-controlled wandering behavior. This logic is typically managed
## by the DecisionComponent in the modern component-based setup, but the function remains for
## compatibility or as a potential extension point for specific NPC movement patterns.
func _handle_wandering(_delta: float) -> void:
	pass # Handled by DecisionComponent

## Applies a vertical oscillating 'bobbing' motion to the actor's visual body and mana particles.
## This adds a sense of life and floatiness to the characters, with parameters for speed and
## amplitude that can be adjusted via the actor's exported properties.
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

## Checks the ground tile below the actor and applies any relevant environmental effects.
## This includes taking damage from hazardous tiles or benefiting from element-specific
## ground states, ensuring that the actor's position on the grid matters for gameplay.
func _apply_ground_effects() -> void:
	if _ground_tile:
		if _check_tile_damage(_ground_tile):
			return
		_do_tile_effect(_ground_tile)

## Evaluates whether the actor should take damage based on the state of the tile they are currently
## standing on and their elemental affinity. For example, fire-aligned actors take damage from
## water or mud tiles, creating elemental counters within the grid system.
func _check_tile_damage(tile: HexTileData) -> bool:
	if element_type == "fire":
		if tile.current_state == TileConstants.State.MUD:
			take_damage(1, "normal", Vector3.UP)
			if _arena_grid:
				_arena_grid.set_tile_state(tile, TileConstants.State.DIRT)
			return true
		elif tile.current_state == TileConstants.State.PUDDLE:
			take_damage(2, "normal", Vector3.UP)
			if _arena_grid:
				_arena_grid.set_tile_state(tile, TileConstants.State.DIRT)
			return true
	elif element_type == "water":
		if tile.current_state == TileConstants.State.FIRE:
			take_damage(1, "normal", Vector3.UP)
			if _arena_grid:
				_arena_grid.set_tile_state(tile, TileConstants.State.MUD)
			return true
	return false

## A virtual method for subclasses to implement custom ground-based effects. This allows specific
## actor types to react uniquely to certain tile states without cluttering the base class
## with every possible environmental interaction.
func _do_tile_effect(_tile: HexTileData) -> void:
	# Virtual method for subclasses
	pass

## Updates the internal reference to the tile directly beneath the actor by querying the arena grid
## using the actor's current global position. This is essential for the ground effect system
## to function accurately as the actor moves around the arena.
func _update_tile_below() -> void:
	if _arena_grid:
		_ground_tile = _arena_grid.get_tile_data_at_world_position(global_transform.origin)
	else:
		_ground_tile = null

## Handles AI-driven projectile firing by randomly choosing an attack pattern and picking a
## semi-random target direction within the actor's effective range. This provides basic
## hostile or autonomous behavior for NPCs that aren't player-controlled.
func _launch_projectile() -> void:
	# Randomly choose an attack pattern for AI
	var patterns = [AttackPattern.SINGLE, AttackPattern.SPREAD, AttackPattern.LOB]
	current_attack_pattern = patterns[_rng.randi_range(0, patterns.size() - 1)]
	
	# Pick a random direction and distance for the AI to "aim" at
	var heading = _rng.randf_range(0.0, TAU)
	var distance = _rng.randf_range(5.0, _effective_range_world())
	var target_position = global_transform.origin + Vector3(cos(heading), 0.0, sin(heading)) * distance
	
	launch_projectile_at(target_position)

## Converts the actor's tile-based trigger range into world-space units based on the arena's hex size.
## This ensures that range-based logic (like AI targeting) scales correctly with the size of the
## environment's grid cells.
func _effective_range_world() -> float:
	var base_hex_size = _arena_grid.hex_size if _arena_grid else 1.0
	return trigger_range_in_tiles * base_hex_size * 1.5

## Converts the actor's maximum projectile range from tiles to world-space units. This defines the
## absolute limit a projectile can travel before expiring, providing consistency between grid-based
## design and world-space physics.
func _projectile_max_range_world() -> float:
	var base_hex_size = _arena_grid.hex_size if _arena_grid else 1.0
	return projectile_max_range_in_tiles * base_hex_size * 1.5

## Commands the decision component to re-evaluate its current goal and choose a new target.
## This is used to refresh AI behavior when the previous target is reached or when environmental
## changes necessitate a shift in priority.
func _choose_new_target() -> void:
	if decision_component:
		decision_component._choose_new_target()


## Standardizes GPUParticles3D setup for actors and tiles.
## A static utility function that configures a GPUParticles3D node with a common set of parameters.
## It handles the setup of materials, emission shapes, and velocities, allowing for consistent
## and easy creation of particle effects for both actors and environmental tiles.
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
