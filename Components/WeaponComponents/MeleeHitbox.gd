## Component responsible for melee hit detection and impact effects.
## Separated from Weapon.gd to handle physics queries and damage application.
extends Node3D

var _owner_actor: Node3D
var _weapon_data: WeaponData
var _weapon: Node3D
var _whack_player: AudioStreamPlayer3D
var _hitbox_visual: MeshInstance3D

## Initializes the component with its parent weapon.
func setup(p_weapon: Node3D) -> void:
	_weapon = p_weapon
	_owner_actor = p_weapon.get("_owner_actor")
	_whack_player = p_weapon.get("_whack_player")

## Updates the weapon data used for reach and cone calculations.
func set_weapon_data(data: WeaponData) -> void:
	_weapon_data = data
	_setup_hitbox_visual()

## Performs a melee swing query in a cone and handles hits.
func perform_swing(dir: Vector3) -> void:
	if not _weapon_data or not _owner_actor: return
	
	_show_hitbox_animation(_owner_actor.global_position, dir)
	
	# Check for hits in a cone
	var space_state = _owner_actor.get_world_3d().direct_space_state
	var query = PhysicsShapeQueryParameters3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = _weapon_data.reach
	query.shape = sphere
	query.transform = _owner_actor.global_transform
	query.collision_mask = 2 # Actor layer
	
	var hits = space_state.intersect_shape(query)
	var hit_anything = false
	for hit in hits:
		var collider = hit.collider
		if collider != _owner_actor and collider.has_method("take_damage"):
			var to_target = (collider.global_position - _owner_actor.global_position).normalized()
			to_target.y = 0
			var angle = rad_to_deg(dir.angle_to(to_target))
			if angle <= _weapon_data.cone_width / 2.0:
				_handle_hit(collider, dir)
				hit_anything = true
	
	if not hit_anything:
		# Check features
		var feature_query = PhysicsRayQueryParameters3D.create(_owner_actor.global_position + Vector3(0, 0.5, 0), _owner_actor.global_position + dir * _weapon_data.reach + Vector3(0, 0.5, 0))
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

func _handle_hit(target: Node3D, _dir: Vector3) -> void:
	# Determine relevant stat
	var ability_scores = _owner_actor.get("ability_scores_component")
	if not ability_scores: return
	
	var ability_score: float = ability_scores.strength
	
	# Handle Finesse weapons (use Dex if higher)
	if _weapon_data and _weapon_data.is_finesse:
		ability_score = max(ability_scores.strength, ability_scores.dexterity)
	
	# Perform the skill check using the new component
	var skill_check = _owner_actor.get("skill_check_component")
	if not skill_check: return
	
	# Check for target redirection
	var final_target: Node3D = target
	if target.get("ability_component"):
		final_target = target.get("ability_component").get_attack_target(_owner_actor)
	
	var target_ac = final_target.get("armor_class") if final_target.get("armor_class") != null else 10
	var result: Dictionary = skill_check.perform_check(ability_score, target_ac, "Attack", final_target, ability_score)
	
	var impact_dir: Vector3 = (final_target.global_position - _owner_actor.global_position).normalized()
	
	# Use the check results
	if result.success:
		var damage: float = _weapon_data.roll_damage()
		final_target.take_damage(damage, "normal", impact_dir)
		if final_target.has_method("stun"):
			final_target.stun(0.3)
		_play_whack()
		_show_thwak_visual(final_target.global_position + Vector3(0, 1.0, 0))
		
		var movement = final_target.get("movement_component")
		if movement:
			impact_dir.y = 0.2
			movement.apply_external_force(impact_dir * 8.0)
	else:
		# Miss - "Bounces off the armor"
		if target.has_method("show_miss"):
			target.call("show_miss", impact_dir)

func _play_whack() -> void:
	if _whack_player:
		_whack_player.play()

func _setup_hitbox_visual() -> void:
	if not is_inside_tree() or not _weapon_data: return
	if _hitbox_visual:
		_hitbox_visual.queue_free()
	
	_hitbox_visual = MeshInstance3D.new()
	var plane = PlaneMesh.new()
	plane.size = Vector2(1, 1)
	_hitbox_visual.mesh = plane
	_hitbox_visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	var mat = preload("res://assets/materials/AttackHitboxMaterial.tres")
	if mat:
		mat = mat.duplicate()
		mat.set_shader_parameter("angle_degrees", _weapon_data.cone_width)
		_hitbox_visual.material_override = mat
	
	add_child(_hitbox_visual)
	_hitbox_visual.visible = false
	_hitbox_visual.top_level = true

func _show_hitbox_animation(origin: Vector3, dir: Vector3) -> void:
	if not _hitbox_visual: return
	_hitbox_visual.global_position = origin
	_hitbox_visual.global_position.y += 0.05
	var angle = atan2(dir.x, dir.z)
	_hitbox_visual.rotation = Vector3(0, angle, 0)
	_hitbox_visual.visible = true
	_hitbox_visual.scale = Vector3.ZERO
	var target_scale = _weapon_data.effective_range
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
