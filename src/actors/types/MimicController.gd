class_name MimicController
extends ActorAIController

const CreatureMorphComponentScript = preload("res://Components/ActorComponents/CreatureMorphComponent.gd")
const SkillCopyComponentScript = preload("res://Components/ActorComponents/SkillCopyComponent.gd")

func _ready() -> void:
	super._ready()
	call_deferred("_setup_mimic_features")

func _setup_mimic_features() -> void:
	if not actor:
		return
	var morph_component: Node = actor.get_node_or_null("CreatureMorphComponent")
	if morph_component == null:
		morph_component = CreatureMorphComponentScript.new()
		morph_component.name = "CreatureMorphComponent"
		actor.add_child(morph_component)
	if morph_component.has_method("setup"):
		morph_component.call("setup", actor)

	var skill_copy_component: Node = actor.get_node_or_null("SkillCopyComponent")
	if skill_copy_component == null:
		skill_copy_component = SkillCopyComponentScript.new()
		skill_copy_component.name = "SkillCopyComponent"
		actor.add_child(skill_copy_component)
	if skill_copy_component.has_method("setup"):
		skill_copy_component.call("setup", actor)
