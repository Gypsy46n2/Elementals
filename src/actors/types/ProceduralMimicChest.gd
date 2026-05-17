class_name ProceduralMimicChest
extends Node3D

@export_group("Voxel Size")
@export var width_vox: int = 32
@export var height_vox: int = 24
@export var depth_vox: int = 20
@export var grid_step: int = 1
@export var unit_scale: float = 0.03

@export_group("Variation")
@export var use_procedural_variation: bool = true
@export var variation_seed: int = 0
@export var tooth_count_min: int = 6
@export var tooth_count_max: int = 11

@export_group("Animation")
@export var animate_lid_idle: bool = true
@export var idle_speed: float = 5.0
@export var idle_min_angle: float = 15.0
@export var idle_max_angle: float = 35.0
@export var bite_open_angle: float = 65.0
@export var bite_closed_angle: float = 5.0
@export var bite_duration: float = 0.22

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _lid_pivot: Node3D = null
var _tongue_root: Node3D = null
var _bite_time_left: float = 0.0
var _hinge_vox: Vector3 = Vector3.ZERO
var _active_width: int = 32
var _active_height: int = 24
var _active_depth: int = 20
var _wood_color: Color = Color(0.33, 0.21, 0.12)
var _metal_color: Color = Color(0.58, 0.52, 0.44)
var _eye_color: Color = Color(0.95, 0.15, 0.10)
var _tongue_color: Color = Color(0.76, 0.25, 0.32)

func _ready() -> void:
	_rng.randomize()
	if variation_seed != 0:
		_rng.seed = variation_seed
	_build()

func _process(_delta: float) -> void:
	if _lid_pivot == null:
		return

	var owner_actor: Node = get_parent()
	var in_object_form: bool = false
	if owner_actor:
		in_object_form = bool(owner_actor.get_meta("mimic_object_form", false))

	if in_object_form:
		_lid_pivot.rotation_degrees.x = -8.0
		if _tongue_root:
			_tongue_root.visible = false
		return

	if _tongue_root:
		_tongue_root.visible = true
		_tongue_root.position.y = _to_units(_snapf(_active_height * 0.18 + sin(Time.get_ticks_msec() / 1000.0 * 4.0) * 0.5))

	if _bite_time_left > 0.0:
		_bite_time_left -= _delta
		var t: float = clampf(1.0 - (_bite_time_left / bite_duration), 0.0, 1.0)
		var bite_curve: float = pow(1.0 - t, 3.0)
		var angle: float = lerpf(bite_closed_angle, bite_open_angle, bite_curve)
		_lid_pivot.rotation_degrees.x = -angle
		return

	if animate_lid_idle:
		var open_amount: float = sin(Time.get_ticks_msec() / 1000.0 * idle_speed) * 0.5 + 0.5
		var lid_angle: float = lerpf(idle_min_angle, idle_max_angle, open_amount)
		_lid_pivot.rotation_degrees.x = -lid_angle

func trigger_bite() -> void:
	_bite_time_left = bite_duration

func rebuild_with_seed(new_seed: int) -> void:
	variation_seed = new_seed
	_rng.seed = new_seed
	_build()

func _build() -> void:
	_clear_children()
	_prepare_variation()

	# Lower chest body
	_create_box(
		Vector3(0, 0, 0),
		Vector3(_active_width, _active_height * 0.6, _active_depth),
		_wood_color
	)

	# Metal bands
	_create_box(Vector3(-_active_width * 0.35, 1, _active_depth * 0.51), Vector3(2, _active_height * 0.6, 1), _metal_color, self, 0.45, 0.12)
	_create_box(Vector3(_active_width * 0.35, 1, _active_depth * 0.51), Vector3(2, _active_height * 0.6, 1), _metal_color, self, 0.45, 0.12)
	_create_box(Vector3(0, _active_height * 0.15, _active_depth * 0.52), Vector3(_active_width, 2, 1), _metal_color, self, 0.45, 0.12)

	# Mouth gap
	_create_box(
		Vector3(0, _active_height * 0.33, _active_depth * 0.53),
		Vector3(_active_width * 0.78, _active_height * 0.22, 1),
		Color(0.02, 0.02, 0.02)
	)

	# Hinged lid
	_create_lid()

	# Teeth, eyes, tongue
	_add_teeth()
	_add_eyes()
	_add_tongue()

func _create_lid() -> void:
	_lid_pivot = Node3D.new()
	_lid_pivot.name = "LidPivot"
	add_child(_lid_pivot)

	var hinge: Vector3 = Vector3(0, _active_height * 0.35, -_active_depth * 0.5)
	_hinge_vox = hinge
	_lid_pivot.position = _to_units_vec(_snap_vec(hinge))

	var lid_center: Vector3 = Vector3(0, _active_height * 0.55, 0)
	var local_center: Vector3 = lid_center - hinge

	_create_box(
		local_center,
		Vector3(_active_width, _active_height * 0.28, _active_depth),
		_wood_color,
		_lid_pivot
	)
	_create_box(
		local_center + Vector3(0, -_active_height * 0.08, _active_depth * 0.52),
		Vector3(_active_width, 2, 1),
		_metal_color,
		_lid_pivot,
		0.45,
		0.12
	)
	_lid_pivot.rotation_degrees.x = -idle_min_angle

func _add_teeth() -> void:
	var mouth_width: float = _active_width * 0.78
	var mouth_top: float = _active_height * 0.44
	var mouth_bottom: float = _active_height * 0.22
	var z_interior: float = _active_depth * 0.42

	var upper_count: int = _rng.randi_range(tooth_count_min, tooth_count_max)
	var lower_count: int = max(4, upper_count - _rng.randi_range(1, 2))
	var upper_local_y: float = mouth_top - _hinge_vox.y
	var upper_local_z: float = z_interior - _hinge_vox.z
	_add_tooth_row(upper_count, mouth_width, upper_local_y, upper_local_z, true, _lid_pivot)
	_add_tooth_row(lower_count, mouth_width, mouth_bottom, z_interior, false, self)

func _add_tooth_row(count: int, mouth_width: float, y: float, z: float, pointing_down: bool, parent_node: Node3D) -> void:
	var spacing: float = mouth_width / float(count + 1)
	for i in range(count):
		var x: float = -mouth_width * 0.5 + spacing * float(i + 1)
		x += _rng.randf_range(-spacing * 0.12, spacing * 0.12)
		var tooth_height: int = _rng.randi_range(3, 6)
		_create_voxel_tooth(x, y, z, tooth_height, pointing_down, parent_node)

func _create_voxel_tooth(x: float, y: float, z: float, height: int, pointing_down: bool, parent_node: Node3D) -> void:
	for row in range(height):
		var width: int = max(1, height - row)
		var yy: float = y - row if pointing_down else y + row
		_create_box(Vector3(x, yy, z), Vector3(width, 1, 1), Color(0.92, 0.90, 0.86), parent_node, 0.55, 0.0)

func _add_eyes() -> void:
	_create_box(Vector3(-_active_width * 0.18, _active_height * 0.52, _active_depth * 0.58), Vector3(3, 3, 1), _eye_color)
	_create_box(Vector3(_active_width * 0.18, _active_height * 0.52, _active_depth * 0.58), Vector3(3, 3, 1), _eye_color)
	_create_box(Vector3(-_active_width * 0.16, _active_height * 0.50, _active_depth * 0.59), Vector3(1, 1, 1), Color.BLACK)
	_create_box(Vector3(_active_width * 0.16, _active_height * 0.50, _active_depth * 0.59), Vector3(1, 1, 1), Color.BLACK)

func _add_tongue() -> void:
	_tongue_root = Node3D.new()
	_tongue_root.name = "TongueRoot"
	add_child(_tongue_root)
	_tongue_root.position = _to_units_vec(Vector3(0, _snapf(_active_height * 0.18), 0))
	_create_box(Vector3(0, 0, _active_depth * 0.62), Vector3(_active_width * 0.35, 2, 4), _tongue_color, _tongue_root, 0.85, 0.0)
	_create_box(Vector3(0, -3, _active_depth * 0.70), Vector3(_active_width * 0.25, 2, 4), _tongue_color, _tongue_root, 0.85, 0.0)

func _create_box(center_vox: Vector3, size_vox: Vector3, color: Color, parent_node: Node3D = null, roughness: float = 0.78, metallic: float = 0.02) -> MeshInstance3D:
	var mesh_instance: MeshInstance3D = MeshInstance3D.new()
	mesh_instance.name = "Part"
	mesh_instance.position = _to_units_vec(_snap_vec(center_vox))

	var box: BoxMesh = BoxMesh.new()
	box.size = _to_units_vec(_snap_size(size_vox))
	mesh_instance.mesh = box

	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	mat.metallic = metallic
	mesh_instance.material_override = mat

	(parent_node if parent_node != null else self).add_child(mesh_instance)
	return mesh_instance

func _prepare_variation() -> void:
	_active_width = width_vox
	_active_height = height_vox
	_active_depth = depth_vox

	if use_procedural_variation:
		_active_width = int(round(_rng.randf_range(24.0, 40.0)))
		_active_height = int(round(_rng.randf_range(18.0, 30.0)))
		_active_depth = int(round(_rng.randf_range(16.0, 28.0)))

	_wood_color = _pick_wood_color()
	_eye_color = _pick_eye_color()
	_metal_color = _pick_metal_color()
	_tongue_color = _pick_tongue_color()

func _pick_wood_color() -> Color:
	var palette: Array[Color] = [
		Color(0.31, 0.20, 0.11),
		Color(0.40, 0.27, 0.16),
		Color(0.46, 0.30, 0.18),
		Color(0.26, 0.16, 0.10)
	]
	return palette[_rng.randi_range(0, palette.size() - 1)]

func _pick_eye_color() -> Color:
	var palette: Array[Color] = [
		Color(0.94, 0.18, 0.10),
		Color(0.98, 0.42, 0.08),
		Color(0.90, 0.12, 0.28),
		Color(0.95, 0.70, 0.12)
	]
	return palette[_rng.randi_range(0, palette.size() - 1)]

func _pick_metal_color() -> Color:
	var palette: Array[Color] = [
		Color(0.59, 0.53, 0.46),
		Color(0.42, 0.44, 0.48),
		Color(0.61, 0.49, 0.32)
	]
	return palette[_rng.randi_range(0, palette.size() - 1)]

func _pick_tongue_color() -> Color:
	var palette: Array[Color] = [
		Color(0.75, 0.24, 0.32),
		Color(0.68, 0.18, 0.28),
		Color(0.82, 0.30, 0.35)
	]
	return palette[_rng.randi_range(0, palette.size() - 1)]

func _clear_children() -> void:
	for child in get_children():
		child.queue_free()
	_lid_pivot = null
	_tongue_root = null

func _snapf(v: float) -> float:
	var step: float = maxf(1.0, float(grid_step))
	return round(v / step) * step

func _snap_vec(v: Vector3) -> Vector3:
	return Vector3(_snapf(v.x), _snapf(v.y), _snapf(v.z))

func _snap_size(v: Vector3) -> Vector3:
	return Vector3(maxf(1.0, _snapf(v.x)), maxf(1.0, _snapf(v.y)), maxf(1.0, _snapf(v.z)))

func _to_units(v: float) -> float:
	return v * unit_scale

func _to_units_vec(v: Vector3) -> Vector3:
	return Vector3(_to_units(v.x), _to_units(v.y), _to_units(v.z))
