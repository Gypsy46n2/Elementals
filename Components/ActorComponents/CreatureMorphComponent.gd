class_name CreatureMorphComponent
extends Node

signal morphed(target: Node3D)
signal reverted()
signal object_form_changed(active: bool)

var actor: Actor
var is_morphed: bool = false
var is_object_form: bool = false

var _original_body: Node3D = null
var _morphed_body: Node3D = null
var _current_morph_target_type: StringName = &""
var _original_body_scale: Vector3 = Vector3.ONE
var _object_form_speed_backup: float = 1.0

func setup(p_actor: Actor) -> void:
	actor = p_actor
	if actor:
		_original_body = actor.get_node_or_null("Body")
		if _original_body:
			_original_body_scale = _original_body.scale

func morph_into(target: Node3D) -> StringName:
	if not is_instance_valid(actor) or not is_instance_valid(target):
		return &""
	if target == actor:
		return &""
	if is_object_form:
		exit_object_form()

	var target_body: Node3D = target.get_node_or_null("Body")
	if target_body == null:
		return &""

	if is_morphed:
		revert()

	_morphed_body = target_body.duplicate()
	_morphed_body.name = "MimicMorphedBody"

	if _original_body:
		_original_body.visible = false
		_morphed_body.transform = _original_body.transform
	actor.add_child(_morphed_body)
	_set_visual_body(_morphed_body)

	_current_morph_target_type = _resolve_target_type(target)
	actor.set_meta("mimic_morph_type", String(_current_morph_target_type))
	is_morphed = true
	morphed.emit(target)
	return _current_morph_target_type

func revert() -> void:
	if not is_morphed:
		return

	if is_instance_valid(_morphed_body):
		_morphed_body.queue_free()
	_morphed_body = null

	if is_instance_valid(_original_body):
		_original_body.visible = true
		_set_visual_body(_original_body)

	_current_morph_target_type = &""
	if actor:
		actor.set_meta("mimic_morph_type", "")
	is_morphed = false
	reverted.emit()

func get_current_morph_type() -> StringName:
	return _current_morph_target_type

func enter_object_form() -> bool:
	if not is_instance_valid(actor):
		return false
	if is_object_form:
		return true
	if _original_body == null:
		_original_body = actor.get_node_or_null("Body")
	if _original_body == null:
		return false

	if is_morphed:
		revert()

	_original_body.visible = true
	_set_visual_body(_original_body)
	_original_body_scale = _original_body.scale
	_original_body.scale = Vector3(
		_original_body_scale.x * 1.35,
		maxf(0.35, _original_body_scale.y * 0.55),
		_original_body_scale.z * 1.35
	)
	_apply_object_form_speed(0.18)
	actor.set_meta("mimic_object_form", true)
	actor.set_meta("mimic_false_appearance", true)
	is_object_form = true
	object_form_changed.emit(true)
	return true

func exit_object_form() -> bool:
	if not is_instance_valid(actor):
		return false
	if not is_object_form:
		return false

	if is_instance_valid(_original_body):
		_original_body.scale = _original_body_scale
		_original_body.visible = true
		_set_visual_body(_original_body)

	if actor.movement_component:
		actor.movement_component.speed_multiplier = _object_form_speed_backup
	actor.remove_meta("mimic_object_form")
	actor.remove_meta("mimic_false_appearance")
	is_object_form = false
	object_form_changed.emit(false)
	return true

func force_true_form() -> void:
	revert()
	exit_object_form()

func _set_visual_body(new_body: Node3D) -> void:
	if not actor or not actor.visual_component or new_body == null:
		return
	actor._body = new_body
	actor.visual_component.body = new_body
	actor.visual_component.body_sprite = null
	actor.visual_component.body_model = null
	if new_body is SpriteBase3D:
		actor.visual_component.body_sprite = new_body as SpriteBase3D
	else:
		actor.visual_component.body_model = new_body
		actor.visual_component.initial_model_scale = new_body.scale

func _resolve_target_type(target: Node3D) -> StringName:
	var data_value: Variant = target.get("_data")
	if data_value is ActorData:
		return StringName((data_value as ActorData).get_actor_type())
	if "element_type" in target:
		return StringName(String(target.element_type).to_lower().strip_edges())
	return StringName(target.name.to_lower().strip_edges())

func _apply_object_form_speed(multiplier: float) -> void:
	if actor == null or actor.movement_component == null:
		return
	_object_form_speed_backup = actor.movement_component.speed_multiplier
	actor.movement_component.speed_multiplier = minf(actor.movement_component.speed_multiplier, multiplier)
