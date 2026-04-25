class_name GoblinMinion
extends Actor

## Goblin Minion: Small Fey (Goblinoid), Chaotic Neutral
## AC 12, HP 2d6, Speed 3
## Nimble Escape: Disengage (dodge) or Hide (invisibility)

@export_group("Goblin Stats")
@export var armor_class: int = 12
@export var stealth_modifier: int = 6
@export var passive_perception: int = 9

var is_hidden: bool = false:
	set(v):
		is_hidden = v
		if _body:
			_body.modulate.a = 0.4 if is_hidden else 1.0
		if is_hidden:
			print(name, " is now HIDDEN")
		else:
			print(name, " is now REVEALED")

var is_disengaged: bool = false
var daggers_remaining: int = 3

var _hide_check_timer: float = 0.0
const HIDE_CHECK_INTERVAL: float = 3.0

func _init() -> void:
	element_type = "goblin"
	should_bob = false
	is_playable = false
	is_friendly = false
	
	# D&D Stats mapping: 10 = 1.0
	strength = 0.8  # 8
	dexterity = 1.5 # 15
	constitution = 1.0 # 10
	intelligence = 1.0 # 10
	wisdom = 0.8 # 8
	charisma = 0.8 # 8
	
	move_speed = 3.0

func _ready() -> void:
	super._ready()
	
	# Roll HP: 2d6
	var rolled_hp = _rng.randi_range(1, 6) + _rng.randi_range(1, 6)
	if health_component:
		health_component.max_health = float(rolled_hp)
		health_component.current_health = float(rolled_hp)
	
	# Load Dagger weapon - overrides the default if found
	var wl = get_node_or_null("/root/ItemsAutoload")
	if wl:
		for w in wl.weapons:
			if w.name == "Dagger":
				_on_weapon_selected(w)
				break
	
	if not equipped_weapon:
		# Fallback if ItemsAutoload not ready or dagger not found
		_on_weapon_selected(WeaponData.new("Dagger", "2 gp", "1d4", "piercing", 1, "Finesse, light, thrown (range 10/30), ammo 5"))

func _create_decision_component() -> ActorDecisionComponent:
	return GoblinDecisionComponent.new()

func _setup_actor() -> void:
	if _body is AnimatedSprite3D:
		var sprite = _body as AnimatedSprite3D
		sprite.pixel_size = 0.02
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.play(&"idle")
		sprite.offset.y = 24

func take_damage(amount: float, type: String = "normal", direction: Vector3 = Vector3.ZERO) -> void:
	if is_disengaged:
		print(name, " avoided damage due to Disengage!")
		return
	
	# Simple AC check for "normal" attacks if we want to simulate D&D
	# Usually Actor.take_damage is called directly with a fixed amount.
	# If we want to use AC, we'd need to know the attack roll.
	# For now, let's just use the standard damage system.
	
	super.take_damage(amount, type, direction)
	
	# Being hit reveals the goblin
	if is_hidden:
		is_hidden = false

func launch_projectile_at(target_position: Vector3) -> void:
	if is_stunned(): return
	
	# If hidden, attacking reveals the goblin
	if is_hidden:
		is_hidden = false
		
	super.launch_projectile_at(target_position)

func take_nimble_escape_action(type: String = "random") -> void:
	if is_stunned(): return
	
	if type == "random":
		type = "hide" if _rng.randf() > 0.5 else "disengage"
	
	if type == "disengage":
		_disengage()
	elif type == "hide":
		_hide()

func _disengage() -> void:
	print(name, " uses Nimble Escape: DISENGAGE")
	is_disengaged = true
	# Invulnerability frames for a short duration
	var timer = get_tree().create_timer(0.5)
	timer.timeout.connect(func(): is_disengaged = false)
	
	# Visual effect: dash or blur?
	if movement_component:
		# Push away from nearest enemy or just random dash
		var dash_dir = -velocity.normalized() if velocity.length() > 0.1 else Vector3(_rng.randf_range(-1,1), 0, _rng.randf_range(-1,1)).normalized()
		movement_component.apply_external_force(dash_dir * 10.0)

func _hide() -> void:
	print(name, " uses Nimble Escape: HIDE")
	# Perform stealth check against all enemies
	var enemies = get_tree().get_nodes_in_group("actors") # Assuming actors group
	if enemies.is_empty():
		enemies = get_tree().get_nodes_in_group("goats") # Fallback
	
	is_hidden = true
	_hide_check_timer = 0.0

func _process(delta: float) -> void:
	super._process(delta)
	_update_sprite_animation()
	
	if is_hidden:
		# Crouching speed (half speed)
		if movement_component:
			movement_component.move_speed = move_speed * 0.5
		
		if velocity.length() > 0.1:
			_hide_check_timer += delta
			if _hide_check_timer >= HIDE_CHECK_INTERVAL:
				_hide_check_timer = 0.0
				_perform_stealth_check()
	else:
		if movement_component:
			movement_component.move_speed = move_speed

func _update_sprite_animation() -> void:
	if not _body is AnimatedSprite3D: return
	var sprite = _body as AnimatedSprite3D
	
	if weapon and weapon.is_on_cooldown():
		if sprite.animation != &"attack":
			sprite.play(&"attack")
		return

	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	if horizontal_velocity.length() > 0.2:
		var camera = get_viewport().get_camera_3d()
		if not camera: return
		
		var cam_basis = camera.global_transform.basis
		var cam_right = cam_basis.x
		var cam_forward = -cam_basis.z # Camera looks towards -Z
		cam_forward.y = 0
		cam_forward = cam_forward.normalized()
		
		var move_dot_right = horizontal_velocity.dot(cam_right)
		var move_dot_forward = horizontal_velocity.dot(cam_forward)
		
		if abs(move_dot_right) > abs(move_dot_forward):
			if move_dot_right > 0:
				sprite.play(&"walk_right")
				sprite.flip_h = false
				_last_dir = &"right"
			else:
				sprite.play(&"walk_left")
				sprite.flip_h = false
				_last_dir = &"left"
		else:
			if move_dot_forward > 0:
				sprite.play(&"walk_up") # Moving away from camera
				_last_dir = &"up"
			else:
				sprite.play(&"walk_down") # Moving towards camera
				_last_dir = &"down"
			sprite.flip_h = false
	else:
		if sprite.sprite_frames.has_animation("idle_" + _last_dir):
			sprite.play("idle_" + _last_dir)
		else:
			sprite.play(&"idle")

func _perform_stealth_check() -> void:
	# "To check for a successful hide action, you use the hiding goblins dexterity vs the opponents wisdom. 
	# the modifier is the difference between these two stats. on a d20, a roll of 10 or higher succeeds 
	# and the goblin remains visible to that actor."
	
	# For simplicity, we'll check against the currently controlled actor or nearby ones
	var arena = _arena_grid
	if not arena: return
	
	for actor in arena.actors:
		if actor == self: continue
		if actor is Actor:
			var roll = _rng.randi_range(1, 20)
			var dex_val = int(dexterity * 10)
			var wis_val = int(actor.wisdom * 10)
			var modifier = wis_val - dex_val # Observer's Wisdom vs Goblin's Dexterity
			
			if roll + modifier >= 10:
				# Success for the OBSERVER, they see the goblin
				print(actor.name, " spotted the goblin! (Roll: ", roll, " + Mod: ", modifier, " = ", roll + modifier, ")")
				is_hidden = false
				break
	
	if is_hidden:
		print("Goblin remains hidden after stealth check.")

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	# If we are hidden and move too fast, we might be revealed?
	# User says: "A goblin can remain hidden as long as it moves at crouch speed(half speed)."
	# This is handled in _process by setting move_speed.
