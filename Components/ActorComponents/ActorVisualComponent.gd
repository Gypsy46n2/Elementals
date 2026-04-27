class_name ActorVisualComponent
extends Node3D

@export var actor: Actor
@export var body: Node3D
@export var mana_particle_texture: Texture2D
@export var hide_body: bool = false

var last_dir: StringName = &"down"
var last_attack_dir: Vector3 = Vector3.FORWARD
var body_sprite: SpriteBase3D
var body_model: Node3D

var initial_model_scale: Vector3 = Vector3.ONE

func setup(p_actor: Actor, p_body: Node3D) -> void:
	actor = p_actor
	body = p_body
	if body is SpriteBase3D:
		body_sprite = body
	else:
		body_model = body
		if body_model:
			initial_model_scale = body_model.scale
	
	if hide_body and body:
		body.visible = false

func _process(delta: float) -> void:
	if actor:
		if body_sprite:
			_update_sprite_flip()
		elif body_model:
			_update_model_rotation(delta)

func _update_model_rotation(delta: float) -> void:
	if not body_model: return
	
	var target_dir: Vector3 = Vector3.ZERO
	
	# If attacking, face attack direction
	if actor.weapon_component and actor.weapon_component.is_on_cooldown():
		target_dir = last_attack_dir
	else:
		# If player controlled, face mouse (same mechanics as weapon idle)
		if actor.is_controlled:
			target_dir = _get_mouse_direction()
		
		# If still no direction (not player or no mouse hit), or if we prefer movement dir when moving
		var velocity = actor.velocity
		var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
		if horizontal_velocity.length() > 0.1:
			# For NPCs, movement direction is the default
			# For players, we might want to still face mouse even when moving, 
			# but many games face movement direction if no target is active.
			# However, "facing the same way as the weapon" implies facing the mouse.
			if target_dir.length() < 0.1:
				target_dir = horizontal_velocity.normalized()

	if target_dir.length() > 0.1:
		# Basis.looking_at(target_dir, UP) makes -Z face target_dir.
		# Since the goblin model faces +Z, we rotate the result by 180 degrees (PI).
		var target_basis = Basis.looking_at(target_dir, Vector3.UP).rotated(Vector3.UP, PI)
		
		# Slerp the normalized basis to keep rotation smooth
		var current_basis = body_model.global_transform.basis.orthonormalized()
		var next_basis = current_basis.slerp(target_basis, delta * 15.0).orthonormalized()
		
		# Re-apply the initial scale to ensure the model doesn't grow/shrink
		body_model.global_transform.basis = next_basis.scaled(initial_model_scale)

func _get_mouse_direction() -> Vector3:
	var mouse_pos = get_viewport().get_mouse_position()
	var camera = get_viewport().get_camera_3d()
	if not camera: return Vector3.ZERO
	
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_dir = camera.project_ray_normal(mouse_pos)
	
	# Create a plane at actor's height
	var plane = Plane(Vector3.UP, actor.global_position.y)
	var target_3d = plane.intersects_ray(ray_origin, ray_dir)
	
	if target_3d:
		var dir = (target_3d - actor.global_position).normalized()
		dir.y = 0
		return dir
	return Vector3.ZERO

func _update_sprite_flip() -> void:
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return
		
	var cam_right = camera.global_transform.basis.x
	var target_dir: Vector3 = Vector3.ZERO
	
	if actor.weapon_component and actor.weapon_component.is_on_cooldown():
		target_dir = last_attack_dir
	elif actor.is_controlled:
		target_dir = _get_mouse_direction()
	else:
		var velocity = actor.velocity
		target_dir = Vector3(velocity.x, 0, velocity.z)
		
	if target_dir.length() > 0.1:
		var dot_right = target_dir.dot(cam_right)
		
		# Determine horizontal flip based on screen-space direction
		if dot_right > 0.1:
			body_sprite.flip_h = false # Facing right
		elif dot_right < -0.1:
			body_sprite.flip_h = true # Facing left

func update_attack_direction(target_position: Vector3) -> void:
	var dir: Vector3 = (target_position - actor.global_position).normalized()
	dir.y = 0
	if dir.length() > 0.01:
		last_attack_dir = dir
	last_dir = get_cardinal_direction(dir)

func get_cardinal_direction(dir: Vector3) -> StringName:
	var camera: Camera3D = get_viewport().get_camera_3d()
	if not camera: return &"down"
	
	var cam_basis: Basis = camera.global_transform.basis
	var cam_right: Vector3 = cam_basis.x
	var cam_forward: Vector3 = -cam_basis.z
	cam_forward.y = 0
	cam_forward = cam_forward.normalized()
	
	var dot_right: float = dir.dot(cam_right)
	var dot_forward: float = dir.dot(cam_forward)
	
	if abs(dot_right) > abs(dot_forward):
		return &"right" if dot_right > 0 else &"left"
	else:
		return &"up" if dot_forward > 0 else &"down"

func get_actor_color() -> Color:
	if actor and actor.has_method("get_actor_color"):
		return actor.get_actor_color()
	return Color.WHITE

func get_mana_particle_texture() -> Texture2D:
	return mana_particle_texture
