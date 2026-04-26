class_name GoblinMinion
extends Actor

## Goblin Minion: Small Fey (Goblinoid), Chaotic Neutral
## AC 12, HP 2d6, Speed 3
## Nimble Escape: Disengage (dodge) or Hide (invisibility)

@export_group("Goblin Stats")
@export var stealth_modifier: int = 6
@export var passive_perception: int = 9

var is_hidden: bool = false:
	set(v):
		if is_hidden == v: return
		is_hidden = v
		if _body:
			_body.modulate.a = 0.4 if is_hidden else 1.0
		
		if is_hidden:
			print(name, " is now HIDDEN")
		else:
			print(name, " is now REVEALED")
			if movement_component:
				movement_component.speed_multiplier = 1.0

var is_disengaged: bool = false
var _hide_check_timer: float = 0.0
const HIDE_CHECK_INTERVAL: float = 3.0

func _init() -> void:
	element_type = "goblin"
	should_bob = false
	is_playable = false
	is_friendly = false
	armor_class = 12
	move_speed = 3.0

func _create_decision_component() -> ActorDecisionComponent:
	return GoblinDecisionComponent.new()

func _ready() -> void:
	super._ready()
	# Stat bonuses
	ability_scores_component.strength = -1
	ability_scores_component.dexterity = 2.5
	ability_scores_component.constitution = 0
	ability_scores_component.intelligence = 0
	ability_scores_component.wisdom = -1
	ability_scores_component.charisma = -1

	# Roll HP: 2d6
	max_hp = float(_rng.randi_range(1, 6) + _rng.randi_range(1, 6))
	health_component.current_health = max_hp
	
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

	if _body is AnimatedSprite3D:
		var sprite = _body as AnimatedSprite3D
		sprite.pixel_size = 0.02
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.play(&"idle")
		sprite.offset.y = 24

	if weapon_component:
		weapon_component.attack_performed.connect(_on_attack_performed)

func _on_attack_performed(_target_position: Vector3) -> void:
	is_hidden = false

func take_damage(amount: float, type: String = "normal", direction: Vector3 = Vector3.ZERO) -> void:
	if is_disengaged:
		print(name, " avoided damage due to Disengage!")
		return
	
	super.take_damage(amount, type, direction)
	
	# Being hit reveals the goblin
	is_hidden = false

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
	get_tree().create_timer(0.5).timeout.connect(func(): is_disengaged = false)
	
	if movement_component:
		# Push away from nearest enemy or just random dash
		var dash_dir = -velocity.normalized() if velocity.length() > 0.1 else Vector3(_rng.randf_range(-1,1), 0, _rng.randf_range(-1,1)).normalized()
		movement_component.apply_external_force(dash_dir * 10.0)

func _hide() -> void:
	print(name, " uses Nimble Escape: HIDE")
	is_hidden = true
	_hide_check_timer = 0.0

func _process(delta: float) -> void:
	_update_sprite_animation()
	
	if is_hidden:
		# Crouching speed (half speed)
		if movement_component:
			movement_component.speed_multiplier = 0.5
		
		if velocity.length() > 0.1:
			_hide_check_timer += delta
			if _hide_check_timer >= HIDE_CHECK_INTERVAL:
				_hide_check_timer = 0.0
				_perform_stealth_check()

func _perform_stealth_check() -> void:
	var arena = _arena_grid
	if not arena: return
	
	for actor_node in arena.actors:
		if actor_node == self: continue
		if actor_node is Actor:
			var dex_val = ability_scores_component.dexterity * 10
			var wis_val = actor_node.ability_scores_component.wisdom * 10
			var modifier = wis_val - dex_val # Observer's Wisdom vs Goblin's Dexterity
			
			var result = skill_check_component.perform_check(modifier, 10, "Stealth vs Perception")
			if result.success:
				# Success for the OBSERVER, they see the goblin
				is_hidden = false
				break

func _update_sprite_animation() -> void:
	if not _body is AnimatedSprite3D: return
	var sprite = _body as AnimatedSprite3D
	
	if weapon and weapon_component.is_on_cooldown():
		if sprite.animation != &"attack":
			sprite.play(&"attack")
		return

	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	if horizontal_velocity.length() > 0.2:
		_last_dir = get_cardinal_direction(horizontal_velocity.normalized())
		var anim_name = "walk_" + _last_dir
		if sprite.animation != anim_name:
			sprite.play(anim_name)
		sprite.flip_h = false
	else:
		var anim_name = StringName("idle_" + _last_dir) if sprite.sprite_frames.has_animation("idle_" + _last_dir) else &"idle"
		if sprite.animation != anim_name:
			sprite.play(anim_name)
		sprite.flip_h = false
