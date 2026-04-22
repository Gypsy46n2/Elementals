class_name Weapon
extends Node3D

@onready var _whack_player: AudioStreamPlayer3D = get_node_or_null("WhackPlayer")
@onready var _swoosh_player: AudioStreamPlayer3D = get_node_or_null("SwooshPlayer")

var weapon_data: WeaponData:
	set(v):
		weapon_data = v
		_setup_hitbox_visual()
		_update_weapon_model()
		if weapon_data:
			current_ammo = weapon_data.max_ammo

var _cooldown: float = 0.0
var _hitbox_visual: MeshInstance3D
var _weapon_model: Node3D
var _owner_actor: Actor
var current_ammo: int = -1

func setup(actor: Actor) -> void:
	_owner_actor = actor
	if weapon_data:
		current_ammo = weapon_data.max_ammo
	# Try to find audio players on the owner if not on self
	if not _whack_player:
		_whack_player = _owner_actor.get_node_or_null("WhackPlayer")
	if not _swoosh_player:
		_swoosh_player = _owner_actor.get_node_or_null("SwooshPlayer")
	
	_update_weapon_model()

func _ready() -> void:
	if weapon_data:
		_setup_hitbox_visual()
		_update_weapon_model()

func _update_weapon_model() -> void:
	if not is_inside_tree(): return
	
	if _weapon_model:
		_weapon_model.queue_free()
		_weapon_model = null
	
	if not weapon_data:
		return
		
	# All melee weapons (including thrown ones when held) get the universal rectangle shape
	if not weapon_data.is_ranged or weapon_data.is_thrown:
		_weapon_model = Node3D.new()
		_weapon_model.name = "WeaponModel"
		
		# Special Case: Dagger uses its custom model
		if weapon_data.name == "Dagger":
			var dagger_scene = load("res://Actor/Projectiles/DaggerProjectile.tscn")
			if dagger_scene:
				var dagger_instance = dagger_scene.instantiate()
				var dagger_model = dagger_instance.get_node("Model")
				# Detach the model from the projectile and add to our container
				dagger_instance.remove_child(dagger_model)
				_weapon_model.add_child(dagger_model)
				dagger_instance.queue_free()
				
				# The dagger model in the scene is pointed up (Y) and rotated 90 deg around X
				# to point Z. Its center is roughly at origin.
				# We want Handle at origin, Tip at -Z.
				# In the scene: Handle is at Y=-0.25, Tip at Y=0.275.
				# The Model node has a -90 deg X rotation.
				# Let's reset its transform and manually orient it.
				dagger_model.transform = Transform3D.IDENTITY
				# Point it along -Z: Blade is along Y, so rotate -90 deg around X.
				# This makes original Y -> -Z.
				dagger_model.rotation_degrees = Vector3(-90, 0, 0)
				# Offset so handle (originally at Y=-0.25) is at origin (Z=0).
				# After -90 deg X rotation: Z_new = -Y_old.
				# Handle Z_new = -(-0.25) = 0.25.
				# To move Handle to Z=0, we set position.z to -0.25.
				dagger_model.position = Vector3(0, 0, -0.25)
		else:
			# Generic Melee Rectangle
			var mesh_instance = MeshInstance3D.new()
			var box = BoxMesh.new()
			
			# Proportions based on weapon properties
			var length: float = 0.7
			if weapon_data.is_heavy: length = 1.1
			if weapon_data.is_light: length = 0.5
			if weapon_data.reach > 2.5: length = 1.3 # Polearms etc
			
			# The "Rectangle Fill" look: thin but visible width
			box.size = Vector3(0.02, 0.12, length)
			mesh_instance.mesh = box
			
			# Pivot at the handle (back of the box)
			mesh_instance.position = Vector3(0, 0, -length / 2.0)
			
			# Stylized Material
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.9, 0.9, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.2, 0.3)
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mesh_instance.material_override = mat
			
			_weapon_model.add_child(mesh_instance)
		
		add_child(_weapon_model)
		_weapon_model.visible = true
	
	# If it's a specific named weapon like Dagger and we have a custom projectile model,
	# we might still use that for the actual PROJECTILE, but for the HELD weapon, 
	# we are now using the universal rectangle.

func _setup_hitbox_visual() -> void:
	if not is_inside_tree() or not weapon_data: return
	if _hitbox_visual:
		_hitbox_visual.queue_free()
	
	_hitbox_visual = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(1, 1)
	_hitbox_visual.mesh = plane
	_hitbox_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	var mat = preload("res://Actor/AttackHitboxMaterial.tres")
	if mat:
		mat = mat.duplicate()
		mat.set_shader_parameter("angle_degrees", weapon_data.cone_width)
		_hitbox_visual.material_override = mat
	
	add_child(_hitbox_visual)
	_hitbox_visual.visible = false
	_hitbox_visual.top_level = true

func _process(delta: float) -> void:
	if _cooldown > 0:
		_cooldown -= delta
	
	_update_idle_animation(delta)

func _update_idle_animation(_delta: float) -> void:
	if not _weapon_model or _cooldown > 0: return
	
	# Get mouse direction and point dagger towards it
	var mouse_pos = get_viewport().get_mouse_position()
	var camera = get_viewport().get_camera_3d()
	if not camera: return
	
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	var plane = Plane(Vector3.UP, _owner_actor.global_position.y)
	var target_3d = plane.intersects_ray(ray_origin, ray_dir)
	
	if target_3d:
		var actor_pos = _owner_actor.global_position
		var dir = (target_3d - actor_pos).normalized()
		dir.y = 0
		if dir.length() < 0.01: 
			dir = -_owner_actor.global_transform.basis.z
		
		var orbit_dist = 0.7
		var float_height = 1.1
		var t = Time.get_ticks_msec() * 0.002
		var bob = sin(t) * 0.04
		
		# Position: Orbit the actor towards the mouse
		var target_pos = dir * orbit_dist + Vector3(0, float_height + bob, 0)
		_weapon_model.position = target_pos
		
		# Orientation: Handle towards actor, tip towards target
		# Since the model is oriented Tip -> -Z, look_at(pos + dir) points Tip at target
		_weapon_model.look_at(_weapon_model.global_position + dir, Vector3.UP)
		
		# Point it "upward" as well (rotate around local X)
		_weapon_model.rotate_object_local(Vector3.RIGHT, deg_to_rad(30))

func is_on_cooldown() -> bool:
	return _cooldown > 0

func get_cooldown_progress() -> float:
	if weapon_data and weapon_data.cooldown > 0:
		return 1.0 - (_cooldown / weapon_data.cooldown)
	return 1.0

func swing(target_pos: Vector3) -> bool:
	if not _owner_actor or is_on_cooldown() or _owner_actor.is_stunned():
		return false
	
	if not weapon_data: return false
	
	_cooldown = weapon_data.cooldown
	
	var dir = (target_pos - _owner_actor.global_position).normalized()
	dir.y = 0
	
	if _swoosh_player:
		_swoosh_player.play()
	
	if weapon_data.is_ranged:
		_launch_ranged_weapon(target_pos, dir)
		_animate_throw(dir)
	else:
		_swing_melee(target_pos, dir)
		_animate_swing(dir)
	
	return true

func _animate_swing(dir: Vector3) -> void:
	if not _weapon_model: return
	
	var orbit_dist: float = 0.7
	var float_height: float = 1.1
	
	# Helper to update weapon position and orientation radially
	var update_weapon: Callable = func(params: Vector2) -> void:
		var angle_offset: float = params.x
		var dist_mult: float = params.y
		
		# Current radial direction relative to the attack direction
		var current_dir: Vector3 = dir.rotated(Vector3.UP, deg_to_rad(angle_offset))
		
		# Position relative to actor
		var target_pos: Vector3 = current_dir * (orbit_dist * dist_mult) + Vector3(0, float_height, 0)
		_weapon_model.position = target_pos
		
		# Orientation: Point Tip away from actor (Tip is -Z in model)
		# We use global_position + current_dir because look_at uses world coordinates
		var look_target: Vector3 = _weapon_model.global_position + current_dir
		_weapon_model.look_at(look_target, Vector3.UP)
		
		# Match the idle tilt (30 degrees "up" around local X)
		_weapon_model.rotate_object_local(Vector3.RIGHT, deg_to_rad(30))

	var tween: Tween = create_tween()
	# Wind up: Pull back 60 degrees, shrink orbit slightly
	tween.tween_method(update_weapon, Vector2(0, 1.0), Vector2(60, 0.7), 0.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# The swing: Arc from 60 to -60 degrees, extend orbit
	tween.tween_method(update_weapon, Vector2(60, 0.7), Vector2(-60, 1.3), 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	
	# Return to neutral (0 degrees, 1.0 orbit)
	tween.tween_method(update_weapon, Vector2(-60, 1.3), Vector2(0, 1.0), 0.1).set_trans(Tween.TRANS_SINE)

func _animate_throw(_dir: Vector3) -> void:
	if not _weapon_model: return
	
	var tween = create_tween()
	# Scale down/disappear then reappear
	tween.tween_property(_weapon_model, "scale", Vector3.ZERO, 0.1)
	# Only reappear if we still have ammo
	if current_ammo > 0:
		tween.tween_property(_weapon_model, "scale", Vector3.ONE * 0.8, 0.1).set_delay(weapon_data.cooldown * 0.8)
	else:
		tween.tween_callback(func(): _weapon_model.visible = false)

func secondary_attack(target_pos: Vector3, forced: bool = false) -> bool:
	if not _owner_actor or is_on_cooldown() or _owner_actor.is_stunned():
		return false
	
	if not weapon_data: return false
	
	# If not forced, check if it's naturally thrown
	if not forced and not weapon_data.is_thrown: return false
	
	if current_ammo == 0:
		return false
		
	_cooldown = weapon_data.cooldown
	
	var dir = (target_pos - _owner_actor.global_position).normalized()
	dir.y = 0
	
	if _swoosh_player:
		_swoosh_player.play()
	
	_launch_ranged_weapon(target_pos, dir)
	
	if current_ammo > 0:
		current_ammo -= 1
		if current_ammo == 0:
			_owner_actor.unequip_weapon()
			
	return true

func _swing_melee(_target_pos: Vector3, dir: Vector3) -> void:
	_show_hitbox_animation(_owner_actor.global_position, dir)
	
	if current_ammo == 0:
		return
	
	# Check for hits in a cone
	var space_state = _owner_actor.get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = weapon_data.reach
	query.shape = sphere
	query.transform = _owner_actor.global_transform
	query.collision_mask = 2 # Actor layer
	
	var hits = space_state.intersect_shape(query)
	var hit_anything = false
	for hit in hits:
		var collider = hit.collider
		if collider != _owner_actor and collider is Actor:
			var to_target = (collider.global_position - _owner_actor.global_position).normalized()
			to_target.y = 0
			var angle = rad_to_deg(dir.angle_to(to_target))
			if angle <= weapon_data.cone_width / 2.0:
				_handle_melee_hit(collider, dir)
				hit_anything = true
	
	if not hit_anything:
		# Check features
		var feature_query = PhysicsRayQueryParameters3D.create(_owner_actor.global_position + Vector3(0, 0.5, 0), _owner_actor.global_position + dir * weapon_data.reach + Vector3(0, 0.5, 0))
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
				if potential_feature.apply_element("headbutt", dir): 
					_play_whack()
					_show_thwak_visual(ray_hit.position)
					hit_anything = true

func _launch_ranged_weapon(target_position: Vector3, _dir: Vector3) -> void:
	var spawn_pos = _owner_actor.global_position + Vector3(0, 1.2, 0)
	var direction = (target_position - spawn_pos).normalized()
	
	var projectile_path = "res://Actor/Projectiles/ArrowProjectile.tscn"
	if weapon_data and weapon_data.name == "Dagger":
		projectile_path = "res://Actor/Projectiles/DaggerProjectile.tscn"
		
	var proj_scene = load(projectile_path)
	var proj = proj_scene.instantiate()
	var parent = _owner_actor.get_parent() if _owner_actor.get_parent() else _owner_actor.get_tree().get_current_scene()
	parent.add_child(proj)
	
	proj.global_transform.origin = spawn_pos
	
	var damage = weapon_data.roll_damage()
	var hex_size = _owner_actor._arena_grid.hex_size if _owner_actor._arena_grid else 1.5
	var proj_range = float(weapon_data.range_max) * hex_size * 1.5
	if proj_range <= 0:
		proj_range = _owner_actor.projectile_max_range_in_tiles * hex_size * 1.5 # Fallback
	
	proj.initialize(_owner_actor._arena_grid, _owner_actor, _owner_actor.global_position, 0.0, direction, _owner_actor.projectile_speed, damage, _owner_actor.projectile_lifetime, proj_range)
	if "source_weapon_data" in proj:
		proj.source_weapon_data = weapon_data

func _handle_melee_hit(target: Actor, _dir: Vector3) -> void:
	var damage = weapon_data.roll_damage()
	var impact_dir = (target.global_position - _owner_actor.global_position).normalized()
	target.take_damage(damage, "normal", impact_dir)
	target.stun(0.3)
	_play_whack()
	_show_thwak_visual(target.global_position + Vector3(0, 1.0, 0))
	
	if target.movement_component:
		impact_dir.y = 0.2
		target.movement_component.apply_external_force(impact_dir * 8.0)

func _play_whack() -> void:
	if _whack_player:
		_whack_player.play()

func _show_hitbox_animation(origin: Vector3, dir: Vector3) -> void:
	if not _hitbox_visual: return
	_hitbox_visual.global_position = origin
	_hitbox_visual.global_position.y += 0.05
	var angle = atan2(dir.x, dir.z)
	_hitbox_visual.rotation = Vector3(0, angle, 0)
	_hitbox_visual.visible = true
	_hitbox_visual.scale = Vector3.ZERO
	var target_scale = weapon_data.reach * 2.0
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.tween_property(_hitbox_visual, "scale", Vector3(target_scale, 1.0, target_scale), 0.1)
	tween.tween_property(_hitbox_visual, "scale", Vector3.ZERO, 0.2).set_delay(0.1)
	tween.tween_callback(func(): _hitbox_visual.visible = false)

func _show_thwak_visual(pos: Vector3) -> void:
	const THWAK_TEXTURE = preload("res://assets/generated/thwak_popup_frame_0_1774916398.png")
	var sprite = Sprite3D.new()
	sprite.texture = THWAK_TEXTURE
	sprite.pixel_size = 0.02
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	var parent = _owner_actor.get_parent() if _owner_actor.get_parent() else _owner_actor
	parent.add_child(sprite)
	sprite.global_position = pos
	sprite.scale = Vector3.ZERO
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector3.ONE * 1.0, 0.1)
	tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position:y", sprite.position.y + 0.4, 0.3).set_delay(0.2)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3).set_delay(0.2)
	tween.tween_callback(sprite.queue_free)
