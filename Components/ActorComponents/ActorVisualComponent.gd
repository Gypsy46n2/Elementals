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

## If false, the actor is effectively invisible to the player (alpha 0.0).
## Set to true when the player's actor successfully performs a perception check.
var is_spotted: bool = true

# Caching for optimization
var _camera: Camera3D
var _last_mouse_pos: Vector2 = Vector2.ZERO
var _last_actor_pos: Vector3 = Vector3.ZERO
var _cached_mouse_dir: Vector3 = Vector3.ZERO
var _last_cam_right: Vector3 = Vector3.ZERO
var _last_target_dir: Vector3 = Vector3.ZERO

func _ready() -> void:
	# Initial camera fetch
	_camera = get_viewport().get_camera_3d()

func _get_camera() -> Camera3D:
	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()
	return _camera

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
	if not actor or actor.is_dead:
		return
	
	var cam = _get_camera()
	if not cam:
		return
		
	if body_sprite:
		_update_sprite_flip(cam)
	elif body_model:
		_update_model_rotation(delta, cam)

func _update_model_rotation(delta: float, p_camera: Camera3D) -> void:
	if not body_model: return
	
	var target_dir: Vector3 = Vector3.ZERO
	
	# If attacking, face attack direction
	if actor.weapon_component and actor.weapon_component.is_on_cooldown():
		target_dir = last_attack_dir
	else:
		# If player controlled, face mouse
		if actor.is_controlled:
			target_dir = _get_mouse_direction(p_camera)
		
		# If still no direction (not player or no mouse hit), or if we prefer movement dir when moving
		var velocity = actor.velocity
		var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
		if horizontal_velocity.length() > 0.1:
			if target_dir.length() < 0.1:
				target_dir = horizontal_velocity.normalized()

	if target_dir.length() > 0.1:
		var target_basis = Basis.looking_at(target_dir, Vector3.UP).rotated(Vector3.UP, PI)
		var current_basis = body_model.global_transform.basis.orthonormalized()
		
		# Optimization: skip slerp if already reached target
		if current_basis.is_equal_approx(target_basis):
			return
			
		var next_basis = current_basis.slerp(target_basis, delta * 15.0).orthonormalized()
		body_model.global_transform.basis = next_basis.scaled(initial_model_scale)

func _get_mouse_direction(p_camera: Camera3D) -> Vector3:
	var mouse_pos = get_viewport().get_mouse_position()
	
	# Optimization: skip raycast if mouse and actor haven't moved
	if mouse_pos == _last_mouse_pos and actor.global_position.is_equal_approx(_last_actor_pos):
		return _cached_mouse_dir
	
	var ray_origin = p_camera.project_ray_origin(mouse_pos)
	var ray_dir = p_camera.project_ray_normal(mouse_pos)
	
	# Create a plane at actor's height
	var plane = Plane(Vector3.UP, actor.global_position.y)
	var target_3d = plane.intersects_ray(ray_origin, ray_dir)
	
	if target_3d:
		var dir = (target_3d - actor.global_position).normalized()
		dir.y = 0
		
		_last_mouse_pos = mouse_pos
		_last_actor_pos = actor.global_position
		_cached_mouse_dir = dir
		return dir
	return Vector3.ZERO

func _update_sprite_flip(p_camera: Camera3D) -> void:
	var cam_right = p_camera.global_transform.basis.x
	var target_dir: Vector3 = Vector3.ZERO
	
	if actor.weapon_component and actor.weapon_component.is_on_cooldown():
		target_dir = last_attack_dir
	elif actor.is_controlled:
		target_dir = _get_mouse_direction(p_camera)
	else:
		var velocity = actor.velocity
		target_dir = Vector3(velocity.x, 0, velocity.z)
		
	if target_dir.length() > 0.1:
		# Optimization: skip if direction and camera haven't changed
		if target_dir.is_equal_approx(_last_target_dir) and cam_right.is_equal_approx(_last_cam_right):
			return
			
		_last_target_dir = target_dir
		_last_cam_right = cam_right
		
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
	var camera: Camera3D = _get_camera()
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

## Sets the transparency (alpha) of the actor's body.
## [param alpha] should be between 0.0 (invisible) and 1.0 (opaque).
## [param recursive] controls whether to apply to children as well.
func set_alpha(alpha: float, recursive: bool = true) -> void:
	if not body:
		return
	
	if not is_spotted:
		alpha = 0.15
	else:
		alpha = clampf(alpha, 0.0, 1.0)
	
	if recursive:
		_apply_alpha_recursive(body, alpha)
	else:
		_apply_alpha_single(body, alpha)

func _apply_alpha_single(node: Node, alpha: float) -> void:
	if node is SpriteBase3D:
		node.modulate.a = alpha
	elif node is GeometryInstance3D:
		_apply_geometry_alpha(node, alpha)

func _apply_alpha_recursive(node: Node, alpha: float) -> void:
	_apply_alpha_single(node, alpha)
	for child in node.get_children():
		_apply_alpha_recursive(child, alpha)

func _apply_geometry_alpha(node: GeometryInstance3D, alpha: float) -> void:
	# For gl_compatibility renderer: set instance alpha
	node.set_instance_shader_parameter("instance_alpha", alpha)
	
	if alpha >= 1.0:
		# Reset to fully opaque
		if node is MeshInstance3D:
			var mat = node.get_active_material(0)
			if mat and mat is StandardMaterial3D and node.material_override and node.material_override.has_meta("is_transparency_override"):
				node.material_override = null
		return
	
	# Set transparency for opaque-ish actors
	node.transparency = 1.0 - alpha
	
	# Fallback for StandardMaterial3D in Compatibility mode
	if node is MeshInstance3D:
		var mat = node.get_active_material(0)
		if mat is StandardMaterial3D:
			if not node.material_override or not node.material_override.has_meta("is_transparency_override"):
				var override = mat.duplicate()
				override.set_meta("is_transparency_override", true)
				node.material_override = override
			
			if node.material_override is StandardMaterial3D:
				node.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				node.material_override.albedo_color.a = alpha
