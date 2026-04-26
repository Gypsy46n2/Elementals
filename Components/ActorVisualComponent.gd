class_name ActorVisualComponent
extends Node3D

@export var actor: Actor
@export var body: Node3D

var last_dir: StringName = &"down"

func setup(p_actor: Actor, p_body: Node3D) -> void:
	actor = p_actor
	body = p_body

func update_attack_direction(target_position: Vector3) -> void:
	var dir: Vector3 = (target_position - actor.global_position).normalized()
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
	if actor and actor.has_method("_get_mana_particle_texture"):
		return actor._get_mana_particle_texture()
	return null
