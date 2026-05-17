class_name SkillCopyComponent
extends Node

signal copied(donor: Node3D, ability_names: Array)
signal restored()

var actor: Actor
var _copied_actions: Array[AbilityAction] = []
var _copied_names: Array[StringName] = []

func setup(p_actor: Actor) -> void:
	actor = p_actor

func has_copies() -> bool:
	return _copied_actions.size() > 0

func get_copied_names() -> Array[StringName]:
	return _copied_names.duplicate()

func copy_from(donor: Node3D, limit: int) -> Array[StringName]:
	var copied_this_call: Array[StringName] = []
	if not is_instance_valid(actor) or not is_instance_valid(donor):
		return copied_this_call
	if limit <= 0:
		return copied_this_call
	var donor_ability_value: Variant = donor.get("ability_component")
	if not (donor_ability_value is Node):
		return copied_this_call
	var donor_ability: Node = donor_ability_value as Node
	if donor_ability == null:
		return copied_this_call
	if actor.ability_component == null:
		return copied_this_call

	var existing_names: Dictionary = {}
	for action in actor.ability_component.actions:
		if action is AbilityAction:
			existing_names[StringName((action as AbilityAction).ability_name)] = true

	for donor_action in donor_ability.actions:
		if copied_this_call.size() >= limit:
			break
		if not (donor_action is AbilityAction):
			continue
		var typed_action: AbilityAction = donor_action as AbilityAction
		var key: StringName = StringName(typed_action.ability_name)
		if key.is_empty() or existing_names.has(key):
			continue

		var source_script: Script = typed_action.get_script()
		if source_script == null:
			continue
		var cloned_variant: Variant = source_script.new(actor, actor.ability_component)
		if not (cloned_variant is AbilityAction):
			continue
		var cloned_action: AbilityAction = cloned_variant as AbilityAction
		actor.ability_component.add_action(cloned_action)
		_copied_actions.append(cloned_action)
		_copied_names.append(key)
		copied_this_call.append(key)
		existing_names[key] = true

	if copied_this_call.size() > 0:
		copied.emit(donor, copied_this_call)
	return copied_this_call

func restore() -> void:
	if _copied_actions.is_empty():
		return
	if not is_instance_valid(actor) or actor.ability_component == null:
		_copied_actions.clear()
		_copied_names.clear()
		return

	var actions: Array[AbilityAction] = actor.ability_component.actions
	for action in _copied_actions:
		actions.erase(action)

	_copied_actions.clear()
	_copied_names.clear()
	restored.emit()
