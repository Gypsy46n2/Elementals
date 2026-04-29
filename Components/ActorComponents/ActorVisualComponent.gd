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

var _name_label: Label3D
var _flash_tween: Tween
var _goat_base_color: Color = Color.WHITE

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
	
	if actor is GoatActor and body_model:
		_setup_goat_visuals()

func _setup_goat_visuals() -> void:
	if not actor is GoatActor:
		return
	var goat_actor: GoatActor = actor as GoatActor
	if goat_actor.goat_data:
		update_goat_visuals(goat_actor.goat_data)

func update_goat_visuals(goat_data: GoatData) -> void:
	if not body_model or not goat_data:
		return
	
	_goat_base_color = goat_data.base_color
	
	# Scale based on body type
	var s: float = 0.7
	match goat_data.body_type:
		GoatData.BodyType.SMALL:
			s = 0.5
		GoatData.BodyType.MEDIUM:
			s = 0.7
		GoatData.BodyType.LARGE:
			s = 0.9
	
	initial_model_scale = Vector3.ONE * s
	body_model.scale = initial_model_scale
	
	# Update coat color via shared material
	var combiner: Node3D = body_model.get_node_or_null("CSGCombiner3D")
	if combiner:
		var body_mesh = combiner.get_node_or_null("Body")
		if body_mesh and body_mesh.material is ShaderMaterial:
			var mat: ShaderMaterial = body_mesh.material as ShaderMaterial
			mat.set_shader_parameter("albedo", goat_data.base_color)
	
	# Update horns visibility
	var horn_l1: Node3D = body_model.find_child("HornL1", true, false)
	var horn_r1: Node3D = body_model.find_child("HornR1", true, false)
	if horn_l1 and horn_r1:
		var show_horns: bool = goat_data.horn_type != GoatData.HornType.NONE
		horn_l1.visible = show_horns
		horn_r1.visible = show_horns
	
	# Name label
	if not _name_label:
		_name_label = Label3D.new()
		_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_name_label.no_depth_test = true
		_name_label.render_priority = 25
		_name_label.modulate = Color.YELLOW
		_name_label.outline_modulate = Color.BLACK
		_name_label.pixel_size = 0.015
		_name_label.font_size = 64
		actor.add_child(_name_label)
	
	_name_label.text = goat_data.goat_name
	_name_label.position = Vector3(0, 1.6 * s, 0)
	
	# Health bar offset
	if actor.health_component:
		actor.health_component.bar_offset = Vector3(0, 1.2 * s, 0)

func flash_red() -> void:
	if body_sprite:
		var base: Color = body_sprite.modulate
		if _flash_tween and _flash_tween.is_valid():
			_flash_tween.kill()
		_flash_tween = create_tween()
		_flash_tween.tween_property(body_sprite, "modulate", Color.RED, 0.1)
		_flash_tween.tween_property(body_sprite, "modulate", base, 0.1)
	elif body_model and actor is GoatActor:
		var combiner: Node3D = body_model.get_node_or_null("CSGCombiner3D")
		if combiner:
			var body_mesh = combiner.get_node_or_null("Body")
			if body_mesh and body_mesh.material is ShaderMaterial:
				var mat: ShaderMaterial = body_mesh.material as ShaderMaterial
				var base_color: Color = _goat_base_color
				if _flash_tween and _flash_tween.is_valid():
					_flash_tween.kill()
				_flash_tween = create_tween()
				_flash_tween.tween_method(
					func(c: Color) -> void: mat.set_shader_parameter("albedo", c),
					base_color, Color.RED, 0.1
				)
				_flash_tween.tween_method(
					func(c: Color) -> void: mat.set_shader_parameter("albedo", c),
					Color.RED, base_color, 0.1
				)

# TODO(Optimization): Cache viewport camera and update visuals only on state/direction change to reduce per-frame work (~2% CPU per actor)
func _process(delta: float) -> void:
	if actor:
		if actor.is_dead:
			return
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

## Rotates the actor's body to lie flat on the ground, as if fallen over.
func fall_over() -> void:
	if body:
		body.rotation.x = PI / 2.0

## Restores the actor's body to an upright standing position.
func stand_up() -> void:
	if body:
		body.rotation.x = 0.0
