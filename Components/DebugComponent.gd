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
