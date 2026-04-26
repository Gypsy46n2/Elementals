class_name AbilityAction
extends RefCounted

## Base class for special abilities handled by the AbilityComponent.

var actor: Actor
var component: AbilityComponent

var ability_name: String = ""
var ability_description: String = ""
var ability_usage: String = ""
var ability_icon: Texture2D = null

func _init(p_actor: Actor, p_component: AbilityComponent) -> void:
	actor = p_actor
	component = p_component

func get_ability_data() -> AbilityData:
	var data = AbilityData.new()
	data.name = ability_name
	data.description = ability_description
	data.usage = ability_usage
	data.icon = ability_icon
	return data

func execute(_type: String, _value = null) -> void:
	pass

func update(_delta: float) -> void:
	pass

func on_damage_taken() -> void:
	pass

func on_attack_performed() -> void:
	pass
