class_name DebugComponent
extends Node

static var debug_enabled: bool = false

var _debug_label: Label3D
var _actor: Node3D # Usually an Actor

func setup(actor: Node3D) -> void:
	_actor = actor
	_setup_debug_label()

func _setup_debug_label() -> void:
	_debug_label = Label3D.new()
	_debug_label.pixel_size = 0.005
	_debug_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_debug_label.no_depth_test = true
	_debug_label.render_priority = 20
	_debug_label.position = Vector3(0, 2.5, 0) # Above HP bar
	_debug_label.outline_render_priority = 19
	_debug_label.modulate = Color.YELLOW
	_actor.add_child(_debug_label)

func _process(_delta: float) -> void:
	if _actor:
		var debug_state = "Unknown"
		if "controller" in _actor and _actor.controller and _actor.controller.has_method("get_debug_state"):
			debug_state = _actor.controller.get_debug_state()
		
		var is_stunned = false
		if _actor.has_method("is_stunned"):
			is_stunned = _actor.is_stunned()
			
		update_debug_label(debug_state, is_stunned)

func update_debug_label(state_text: String, is_stunned: bool) -> void:
	if not _debug_label: return
	
	_debug_label.visible = debug_enabled
	if not debug_enabled: return
	
	var text = state_text
	if is_stunned:
		text += " (STUNNED)"
	
	_debug_label.text = text

var _debug_line: MeshInstance3D
var _debug_line_material: StandardMaterial3D

func setup_debug_line() -> void:
	_debug_line = MeshInstance3D.new()
	_debug_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	
	_debug_line_material = StandardMaterial3D.new()
	_debug_line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_debug_line_material.vertex_color_use_as_albedo = true
	_debug_line_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	
	_debug_line.mesh = ImmediateMesh.new()
	_actor.add_child(_debug_line)

func update_debug_line(to_local_pos: Vector3, color: Color) -> void:
	if not _debug_line:
		setup_debug_line()
	
	_debug_line.visible = debug_enabled
	if not debug_enabled:
		return
	
	var mesh := _debug_line.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, _debug_line_material)
	mesh.surface_set_color(color)
	mesh.surface_add_vertex(Vector3.ZERO)
	mesh.surface_add_vertex(to_local_pos)
	mesh.surface_end()

func clear_debug_line() -> void:
	if _debug_line and _debug_line.mesh is ImmediateMesh:
		(_debug_line.mesh as ImmediateMesh).clear_surfaces()
