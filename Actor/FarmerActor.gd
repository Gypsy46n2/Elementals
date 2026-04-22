class_name FarmerActor
extends Actor

@onready var _whack_player: AudioStreamPlayer3D = get_node_or_null("WhackPlayer")
@onready var _swoosh_player: AudioStreamPlayer3D = get_node_or_null("SwooshPlayer")

const THWAK_TEXTURE = preload("res://assets/generated/thwak_popup_frame_0_1774916398.png")
const FARMER_IDLE = preload("res://assets/Characters/farmer_sprites/walk_down_1.png")
const FARMER_SWING = preload("res://assets/Characters/farmer_sprites/attack_down_0.png")

func _init() -> void:
	element_type = "farmer"
	should_bob = false
	# Commoner stats (10 = 1.0 multiplier)
	strength = 1.0
	dexterity = 1.0
	constitution = 1.0
	intelligence = 1.0
	wisdom = 1.0
	charisma = 1.0
	max_hp = 4
	move_speed = 3.0

func _ready() -> void:
	super._ready()
	_setup_weapon()
	
	# Farmer is the default character, ensure HP is correct
	if health_component:
		health_component.max_health = max_hp
		health_component.current_health = max_hp
	
	# Farmer specific: default to Club if no weapon equipped yet
	var wl = get_node_or_null("/root/ItemsAutoload")
	if not equipped_weapon:
		if wl:
			for w in wl.weapons:
				if w.name == "Club":
					_on_weapon_selected(w)
					break
		else:
			# Fallback
			_on_weapon_selected(WeaponData.new("Club", "1 sp", "1d4", "bludgeoning", 2, "Light"))

func _setup_actor() -> void:
	if _body is AnimatedSprite3D:
		var sprite = _body as AnimatedSprite3D
		sprite.pixel_size = 0.02
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.play(&"idle")
		# 48x48 frames
		sprite.offset.y = 24

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
	
	# Decision Component - specialized for Farmer
	decision_component = FarmerDecisionComponent.new()
	decision_component.name = "DecisionComponent"
	decision_component.movement_component = movement_component
	decision_component.actor = self
	decision_component.is_controlled = is_controlled
	add_child(decision_component)

func get_actor_color() -> Color:
	return Color.YELLOW_GREEN

func _update_sprite_animation() -> void:
	if not _body is AnimatedSprite3D: return
	var sprite = _body as AnimatedSprite3D
	
	if weapon and weapon.is_on_cooldown():
		if sprite.animation != &"swing":
			var anim_name = "swing_" + _last_dir
			if not sprite.sprite_frames.has_animation(anim_name):
				anim_name = &"swing"
			sprite.play(anim_name)
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
				# Using walk_left if available, or walk_right flipped
				if sprite.sprite_frames.has_animation(&"walk_left"):
					sprite.play(&"walk_left")
					sprite.flip_h = false
				else:
					sprite.play(&"walk_right")
					sprite.flip_h = true
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
		sprite.play("idle_" + _last_dir)

func _process(delta: float) -> void:
	super._process(delta)
	_update_sprite_animation()

func herd_goat(goat: GoatActor) -> void:
	if goat.has_method("_scream"):
		goat.call("_scream")
	if goat.movement_component and decision_component:
		var center = (decision_component as FarmerDecisionComponent).farm_center
		var push_dir = (center - goat.global_position).normalized()
		goat.movement_component.apply_external_force(push_dir * 5.0)

func launch_projectile_at(target_position: Vector3) -> void:
	var was_swinging = weapon and weapon.is_on_cooldown()
	super.launch_projectile_at(target_position)
	
	if weapon and weapon.is_on_cooldown() and not was_swinging:
		# Visual swing animation rotation
		if _body is AnimatedSprite3D:
			var sprite = _body as AnimatedSprite3D
			var tween = create_tween()
			tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
			# Pivot the sprite slightly for the swing
			tween.tween_property(sprite, "rotation:z", deg_to_rad(-15) if not sprite.flip_h else deg_to_rad(15), 0.1)
			tween.tween_property(sprite, "rotation:z", 0.0, 0.2).set_delay(0.1)

func get_main_action_progress() -> float:
	return super.get_main_action_progress()
