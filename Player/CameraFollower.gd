class_name CameraFollower
extends Camera3D

@export var follow_offset: Vector3 = Vector3(0.0, 30.0, 30.0)
@export var zoom_speed: float = 2.0
@export var min_zoom: float = 5.0
@export var max_zoom: float = 40.0:
	set(value):
		max_zoom = value
		_current_zoom_dist = clamp(_current_zoom_dist, min_zoom, max_zoom)

var _follow_target: Node3D
var _current_zoom_dist: float

func _ready() -> void:
	# Calculate initial zoom distance from the starting follow_offset
	_current_zoom_dist = follow_offset.length()

func set_target(target: Node3D) -> void:
	_follow_target = target

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_current_zoom_dist = clamp(_current_zoom_dist - zoom_speed, min_zoom, max_zoom)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_current_zoom_dist = clamp(_current_zoom_dist + zoom_speed, min_zoom, max_zoom)

# TODO(Optimization): Cache follow_offset.normalized() to avoid per-frame vector normalization (~0.1% CPU)
func _process(delta: float) -> void:
	if not _follow_target:
		return
	
	# Maintain the same direction but apply the current zoom distance
	var zoom_direction = follow_offset.normalized()
	var effective_offset = zoom_direction * _current_zoom_dist
	
	var target_position = _follow_target.global_transform.origin
	global_transform.origin = target_position + effective_offset
	look_at(target_position, Vector3.UP)
