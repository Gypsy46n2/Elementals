class_name Weapon
extends Node3D

@onready var _whack_player: AudioStreamPlayer3D = get_node_or_null("WhackPlayer")
@onready var _swoosh_player: AudioStreamPlayer3D = get_node_or_null("SwooshPlayer")

var weapon_data: WeaponData:
	set(v):
		weapon_data = v
		_setup_hitbox_visual()
		if weapon_data:
			current_ammo = weapon_data.max_ammo

var _cooldown: float = 0.0
var _hitbox_visual: MeshInstance3D
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

func _ready() -> void:
	if weapon_data:
		_setup_hitbox_visual()

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
	else:
		_swing_melee(target_pos, dir)
	
	return true

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
	
	var arrow_scene = preload("res://Actor/Projectiles/ArrowProjectile.tscn")
	var arrow = arrow_scene.instantiate()
	var parent = _owner_actor.get_parent() if _owner_actor.get_parent() else _owner_actor.get_tree().get_current_scene()
	parent.add_child(arrow)
	
	arrow.global_transform.origin = spawn_pos
	
	var damage = weapon_data.roll_damage()
	var hex_size = _owner_actor._arena_grid.hex_size if _owner_actor._arena_grid else 1.5
	var proj_range = float(weapon_data.range_max) * hex_size * 1.5
	if proj_range <= 0:
		proj_range = _owner_actor.projectile_max_range_in_tiles * hex_size * 1.5 # Fallback
	
	arrow.initialize(_owner_actor._arena_grid, _owner_actor, _owner_actor.global_position, 0.0, direction, _owner_actor.projectile_speed, damage, _owner_actor.projectile_lifetime, proj_range)
	if "source_weapon_data" in arrow:
		arrow.source_weapon_data = weapon_data

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
