## Component responsible for the visual representation of a weapon.
## Handles model loading, idle animations, and specialized orientation.
extends Node3D

var _weapon: Node3D
var _weapon_data: WeaponData
var _weapon_model: Node3D
var _owner_actor: Node3D

func setup(p_weapon: Node3D) -> void:
	_weapon = p_weapon
	_owner_actor = p_weapon.get("_owner_actor")

func set_weapon_data(data: WeaponData) -> void:
	_weapon_data = data
	update_model()

func update_model() -> void:
	if not is_inside_tree(): return
	
	if _weapon_model:
		_weapon_model.queue_free()
		_weapon_model = null
	
	if not _weapon_data:
		return
		
	# All melee weapons (including thrown ones when held) get the universal rectangle shape
	# unless they have a specialized model override.
	if not _weapon_data.is_ranged or _weapon_data.is_thrown:
		_weapon_model = Node3D.new()
		_weapon_model.name = "WeaponModel"
		
		# Specialized model loading (e.g., Dagger)
		var custom_scene_path: String = ""
		if _weapon_data.name == "Dagger":
			custom_scene_path = "res://Actor/Projectiles/DaggerProjectile.tscn"
		elif _weapon_data.projectile_scene_path != "":
			custom_scene_path = _weapon_data.projectile_scene_path
			
		if custom_scene_path != "":
			var scene = load(custom_scene_path)
			if scene:
				var instance = scene.instantiate()
				var model = instance.get_node_or_null("Model")
				if model:
					# Detach the model from the instance and add to our container
					instance.remove_child(model)
					model.owner = null
					_weapon_model.add_child(model)
					
					# Specialized orientation for Dagger/Bladed weapons:
					# We want Handle at origin, Tip at -Z.
					model.transform = Transform3D.IDENTITY
					
					# Specific Dagger adjustments (Hardcoded for this specific asset)
					if _weapon_data.name == "Dagger":
						model.rotation_degrees = Vector3(-90, 0, 0)
						model.position = Vector3(0, 0, -0.25)
					elif _weapon_data.name == "Greatclub":
						model.rotation_degrees = Vector3(-90, 0, 0)
						model.scale = Vector3(1.5, 1.5, 1.5)
					else:
						# Generic assumption for custom models: tip is along +Y, handle at 0
						model.rotation_degrees = Vector3(-90, 0, 0)
				
				instance.queue_free()
		else:
			# Generic Melee Rectangle
			var mesh_instance = MeshInstance3D.new()
			var box = BoxMesh.new()
			
			# Proportions based on weapon properties
			var length: float = 0.7
			if _weapon_data.is_heavy: length = 1.1
			if _weapon_data.is_light: length = 0.5
			if _weapon_data.reach > 2.5: length = 1.3 # Polearms etc
			
			box.size = Vector3(0.02, 0.12, length)
			mesh_instance.mesh = box
			mesh_instance.position = Vector3(0, 0, -length / 2.0)
			
			var mat = StandardMaterial3D.new()
			mat.albedo_color = Color(0.9, 0.9, 1.0)
			mat.emission_enabled = true
			mat.emission = Color(0.2, 0.2, 0.3)
			mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_PIXEL
			mesh_instance.material_override = mat
			
			_weapon_model.add_child(mesh_instance)
		
		add_child(_weapon_model)
		_weapon_model.visible = true

func _process(delta: float) -> void:
	if _weapon and _weapon.is_on_cooldown():
		return
	_update_idle_animation(delta)

func _update_idle_animation(_delta: float) -> void:
	if not _weapon_model or not _owner_actor: return
	
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
		_weapon_model.look_at(_weapon_model.global_position + dir, Vector3.UP)
		_weapon_model.rotate_object_local(Vector3.RIGHT, deg_to_rad(30))

func get_weapon_model() -> Node3D:
	return _weapon_model

## Performs the visual tween animation for a melee weapon swing.
func animate_swing(dir: Vector3) -> void:
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

## Performs the visual tween animation for throwing a weapon.
func animate_throw(cooldown: float, current_ammo: int) -> void:
	if not _weapon_model: return
	
	var original_scale = _weapon_model.scale
	var tween = create_tween()
	# Scale down/disappear then reappear
	tween.tween_property(_weapon_model, "scale", Vector3.ZERO, 0.1)
	# Only reappear if we still have ammo
	if current_ammo > 0:
		tween.tween_property(_weapon_model, "scale", original_scale, 0.1).set_delay(cooldown * 0.8)
	else:
		tween.tween_callback(func(): _weapon_model.visible = false)
