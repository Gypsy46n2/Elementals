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
	max_hp = 4
	move_speed = 3.0

func _setup_actor() -> void:
	# Commoner stats (1.0 = base multiplier)
	ability_scores_component.strength = 1.0
	ability_scores_component.dexterity = 1.0
	ability_scores_component.constitution = 1.0
	ability_scores_component.intelligence = 1.0
	ability_scores_component.wisdom = 1.0
	ability_scores_component.charisma = 1.0

	if _body is AnimatedSprite3D:
		var sprite = _body as AnimatedSprite3D
		sprite.pixel_size = 0.02
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.play(&"idle")
		# 48x48 frames
		sprite.offset.y = 24

func _create_decision_component() -> ActorDecisionComponent:
	return FarmerDecisionComponent.new()

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
		_last_dir = get_cardinal_direction(horizontal_velocity.normalized())
		
		if _last_dir == &"right":
			sprite.play(&"walk_right")
			sprite.flip_h = false
		elif _last_dir == &"left":
			if sprite.sprite_frames.has_animation(&"walk_left"):
				sprite.play(&"walk_left")
				sprite.flip_h = false
			else:
				sprite.play(&"walk_right")
				sprite.flip_h = true
		elif _last_dir == &"up":
			sprite.play(&"walk_up")
			sprite.flip_h = false
		else:
			sprite.play(&"walk_down")
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
