class_name FarmerActor
extends Actor

func _init() -> void:
	element_type = "farmer"
	should_bob = false
	max_hp = 4
	move_speed = 3.0

func _setup_actor() -> void:
	# Commoner stats (0 = base multiplier)
	ability_scores_component.strength = 0
	ability_scores_component.dexterity = 0
	ability_scores_component.constitution = 0
	ability_scores_component.intelligence = 0
	ability_scores_component.wisdom = 0
	ability_scores_component.charisma = 0

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

	if weapon_component and weapon_component.is_on_cooldown():
		var anim_name = "swing_" + _last_dir
		if sprite.sprite_frames.has_animation(anim_name):
			if sprite.animation != anim_name:
				sprite.play(anim_name)
			return
		elif sprite.sprite_frames.has_animation(&"swing"):
			if sprite.animation != &"swing":
				sprite.play(&"swing")
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
		sprite.flip_h = false

func herd_goat(goat: GoatActor) -> void:
	if goat.has_method("_scream"):
		goat.call("_scream")
	if goat.movement_component and decision_component:
		var center = (decision_component as FarmerDecisionComponent).farm_center
		var push_dir = (center - goat.global_position).normalized()
		goat.movement_component.apply_external_force(push_dir * 5.0)
