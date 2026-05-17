class_name MimicShapechange
extends AbilityAction

const TARGET_PICK_RADIUS: float = 2.1
const DEFAULT_PICK_RADIUS: float = 4.5
const COPIED_SKILL_LIMIT: int = 1
const COOLDOWN: float = 0.45

const CreatureMorphComponentScript = preload("res://Components/ActorComponents/CreatureMorphComponent.gd")
const SkillCopyComponentScript = preload("res://Components/ActorComponents/SkillCopyComponent.gd")

var _cooldown_left: float = 0.0

func _init(p_actor: Actor, p_component: Node) -> void:
	super(p_actor, p_component)
	ability_name = "Transmorph"
	ability_description = "Transform into a chosen nearby creature, or shift into object form when no target is selected."
	ability_usage = "Press R while aiming at a creature to copy it. Press R with no target to toggle object form or revert."

func can_execute(type: String) -> bool:
	return type == "ability_r" and _cooldown_left <= 0.0 and actor != null and not actor.is_dead

func execute(type: String, value = null) -> void:
	if not can_execute(type):
		return

	var morph_component: Node = _get_or_create_morph_component()
	var skill_copy_component: Node = _get_or_create_skill_copy_component()
	if morph_component == null:
		return

	var has_target_pos: bool = value is Vector3
	var target_pos: Vector3 = value if has_target_pos else actor.global_position
	var target: Actor = _find_target_for_position(target_pos, TARGET_PICK_RADIUS if has_target_pos else DEFAULT_PICK_RADIUS)

	if target != null:
		if bool(morph_component.get("is_object_form")):
			morph_component.call("exit_object_form")
		var morphed_type: StringName = StringName(morph_component.call("morph_into", target))
		if morphed_type != &"":
			if skill_copy_component != null:
				skill_copy_component.call("restore")
				skill_copy_component.call("copy_from", target, COPIED_SKILL_LIMIT)
			_emit_message("%s transformed into %s." % [actor.name, target.name])
		else:
			_emit_message("Shapechange failed: invalid target.")
		_cooldown_left = COOLDOWN
		return

	if bool(morph_component.get("is_morphed")):
		morph_component.call("revert")
		if skill_copy_component != null:
			skill_copy_component.call("restore")
		_emit_message("%s returned to true form." % actor.name)
	else:
		if bool(morph_component.get("is_object_form")):
			morph_component.call("exit_object_form")
			_emit_message("%s ended False Appearance." % actor.name)
		else:
			var entered: bool = bool(morph_component.call("enter_object_form"))
			if entered:
				_emit_message("%s took object form (False Appearance)." % actor.name)
			else:
				_emit_message("Shapechange failed: no valid body to mimic.")

	_cooldown_left = COOLDOWN

func update(delta: float) -> void:
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(0.0, _cooldown_left - delta)

func _find_target_for_position(world_position: Vector3, max_distance: float) -> Actor:
	if actor == null:
		return null
	var arena_value: Variant = actor.get("_arena_grid")
	if not (arena_value is ArenaGrid):
		return null
	var arena: ArenaGrid = arena_value as ArenaGrid

	var nearest: Actor = null
	var nearest_dist_sq: float = max_distance * max_distance

	for node in arena.actors:
		if not is_instance_valid(node) or not (node is Actor):
			continue
		var candidate: Actor = node as Actor
		if candidate == actor or candidate.is_dead:
			continue
		var candidate_type: String = String(candidate.element_type).to_lower().strip_edges()
		if candidate_type in ["mimic", "scarecrow"]:
			continue
		var delta: Vector3 = candidate.global_position - world_position
		var dist_sq: float = delta.x * delta.x + delta.y * delta.y + delta.z * delta.z
		if dist_sq > nearest_dist_sq:
			continue
		nearest = candidate
		nearest_dist_sq = dist_sq

	return nearest

func _get_or_create_morph_component() -> Node:
	if actor == null:
		return null
	var morph_component: Node = actor.get_node_or_null("CreatureMorphComponent")
	if morph_component == null:
		morph_component = CreatureMorphComponentScript.new()
		morph_component.name = "CreatureMorphComponent"
		actor.add_child(morph_component)
	if morph_component.has_method("setup"):
		morph_component.call("setup", actor)
	return morph_component

func _get_or_create_skill_copy_component() -> Node:
	if actor == null:
		return null
	var skill_copy_component: Node = actor.get_node_or_null("SkillCopyComponent")
	if skill_copy_component == null:
		skill_copy_component = SkillCopyComponentScript.new()
		skill_copy_component.name = "SkillCopyComponent"
		actor.add_child(skill_copy_component)
	if skill_copy_component.has_method("setup"):
		skill_copy_component.call("setup", actor)
	return skill_copy_component

func _emit_message(text: String) -> void:
	print("[Mimic] ", text)
	if actor and actor.get_node_or_null("/root/QuestEvents"):
		QuestEvents.message(text)
