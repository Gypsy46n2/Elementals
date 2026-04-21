class_name FarmerActor
extends Actor

@onready var _whack_player: AudioStreamPlayer3D = get_node_or_null("WhackPlayer")
@onready var _swoosh_player: AudioStreamPlayer3D = get_node_or_null("SwooshPlayer")

const THWAK_TEXTURE = preload("res://assets/generated/thwak_popup_frame_0_1774916398.png")
const FARMER_IDLE = preload("res://assets/Characters/farmer_sprites/walk_down_1.png")
const FARMER_SWING = preload("res://assets/Characters/farmer_sprites/swing_0.png")

var _club_cooldown: float = 0.0
var _last_dir: StringName = &"down"
const CLUB_REACH = 2.0
const CLUB_COOLDOWN = 0.6

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
	move_speed = 7.0

func _ready() -> void:
	super._ready()
	# Farmer is the default character, ensure HP is correct
	if health_component:
		health_component.max_health = max_hp
		health_component.current_health = max_hp

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
	
	if _club_cooldown > 0:
		if sprite.animation != &"swing":
			sprite.play(&"swing")
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
	if _club_cooldown > 0:
		_club_cooldown -= delta
	_update_sprite_animation()


func _unhandled_input(event: InputEvent) -> void:
	if is_controlled and not is_stunned() and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var target_pos = _get_mouse_3d_position()
			_swing_club(target_pos)
			get_viewport().set_input_as_handled()

func _swing_club(target_pos: Vector3) -> void:
	if _club_cooldown > 0 or is_stunned():
		return
	
	_club_cooldown = CLUB_COOLDOWN
	
	if _swoosh_player:
		_swoosh_player.play()
	
	# Visual swing animation
	if _body is AnimatedSprite3D:
		var sprite = _body as AnimatedSprite3D
		sprite.play(&"swing")
		
		var tween = create_tween()
		tween.set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
		# Pivot the sprite slightly for the swing
		tween.tween_property(sprite, "rotation:z", deg_to_rad(-15) if not sprite.flip_h else deg_to_rad(15), 0.1)
		tween.tween_property(sprite, "rotation:z", 0.0, 0.2).set_delay(0.1)

	# Small lunge
	var dir = (target_pos - global_position).normalized()
	dir.y = 0
	if movement_component:
		movement_component.apply_external_force(dir * 5.0)
	
	# Check for hits
	var space_state = get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = CLUB_REACH
	query.shape = sphere
	query.transform = global_transform.translated(dir * 1.0)
	query.collision_mask = 2 # Actor layer
	
	var hits = space_state.intersect_shape(query)
	var hit_anything = false
	for hit in hits:
		var collider = hit.collider
		if collider != self and collider is Actor:
			_handle_club_hit(collider)
			hit_anything = true
	
	if not hit_anything:
		# Check for features (trees etc)
		var feature_query = PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 0.5, 0), global_position + dir * CLUB_REACH + Vector3(0, 0.5, 0))
		feature_query.collision_mask = 1 # Static layer
		var ray_hit = space_state.intersect_ray(feature_query)
		if not ray_hit.is_empty():
			var collider = ray_hit.collider
			var potential_feature = collider
			while potential_feature and not potential_feature.has_method("apply_element"):
				potential_feature = potential_feature.get_parent()
				if potential_feature == get_tree().root:
					potential_feature = null
					break
			
			if potential_feature and potential_feature.has_method("apply_element"):
				if potential_feature.apply_element("headbutt", dir): # Using "headbutt" for blunt damage
					_play_whack()
					_show_thwak_visual(ray_hit.position)
					hit_anything = true


func _handle_club_hit(target: Actor) -> void:
	var damage = _rng.randi_range(1, 4)
	target.take_damage(damage)
	target.stun(0.3)
	_play_whack()
	_show_thwak_visual(target.global_position + Vector3(0, 1.0, 0))
	
	if target.movement_component:
		var dir = (target.global_position - global_position).normalized()
		dir.y = 0.2
		target.movement_component.apply_external_force(dir * 8.0)

func _play_whack() -> void:
	if _whack_player:
		_whack_player.play()

func _show_thwak_visual(pos: Vector3) -> void:
	var sprite = Sprite3D.new()
	if THWAK_TEXTURE:
		sprite.texture = THWAK_TEXTURE
		sprite.pixel_size = 0.08
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	if get_parent():
		get_parent().add_child(sprite)
	else:
		add_child(sprite)
	sprite.global_position = pos
	
	sprite.scale = Vector3.ZERO
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector3.ONE * 1.5, 0.1)
	tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position:y", sprite.position.y + 0.4, 0.3).set_delay(0.2)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3).set_delay(0.2)
	tween.tween_callback(sprite.queue_free)

func _get_mouse_3d_position() -> Vector3:
	var camera = get_viewport().get_camera_3d()
	if not camera: return Vector3.ZERO
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	if abs(ray_direction.y) < 1e-6: return Vector3.ZERO
	var t = -ray_origin.y / ray_direction.y
	return ray_origin + ray_direction * t

func herd_goat(goat: GoatActor) -> void:
	if goat.has_method("_scream"):
		goat.call("_scream")
	if goat.movement_component and decision_component:
		var center = (decision_component as FarmerDecisionComponent).farm_center
		var push_dir = (center - goat.global_position).normalized()
		goat.movement_component.apply_external_force(push_dir * 5.0)

func launch_projectile_at(_target_position: Vector3) -> void:
	# Farmer doesn't shoot projectiles normally, uses Club
	_swing_club(_target_position)

func get_main_action_progress() -> float:
	if _club_cooldown > 0:
		return 1.0 - (_club_cooldown / CLUB_COOLDOWN)
	return 1.0
