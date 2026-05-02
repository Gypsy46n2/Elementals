class_name VisibilityCullingParticles
extends GPUParticles3D

## Disables particles when not visible to reduce GPU overhead.
## Uses a simple frustum check against the current camera.

@export var cull_distance: float = 50.0
@export var update_interval: float = 0.5

var _camera: Camera3D
var _timer: float = 0.0
var _is_visible: bool = true

func _ready() -> void:
	_camera = get_viewport().get_camera_3d()
	# Start enabled
	emitting = true

func _process(delta: float) -> void:
	_timer += delta
	if _timer < update_interval:
		return
	
	_timer = 0.0
	_update_visibility()

func _update_visibility() -> void:
	if not is_instance_valid(_camera):
		# No camera found - keep emitting
		_set_emitting(true)
		return
	
	var global_pos: Vector3 = global_position
	var camera_pos: Vector3 = _camera.global_position
	
	# Distance-based culling (fastest check)
	var distance: float = global_pos.distance_to(camera_pos)
	if distance > cull_distance:
		_set_emitting(false)
		return
	
	# Direction check - skip if behind camera
	var to_particle: Vector3 = global_pos - camera_pos
	var camera_forward: Vector3 = -_camera.global_transform.basis.z
	if to_particle.dot(camera_forward) < 0:
		_set_emitting(false)
		return
	
	# Within range and in front of camera - enable
	_set_emitting(true)

func _set_emitting(enabled: bool) -> void:
	if _is_visible == enabled:
		return
	_is_visible = enabled
	emitting = enabled