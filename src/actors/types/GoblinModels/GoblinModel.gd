class_name GoblinModel
extends Node3D

enum ArmorSkin { NONE, LEATHER, CHAIN }

const SKIN_COLORS: Dictionary = {
	ArmorSkin.NONE: Color(0.2, 0.6, 0.2, 1.0),
	ArmorSkin.LEATHER: Color(0.6, 0.4, 0.2, 1.0),
	ArmorSkin.CHAIN: Color(0.548, 0.548, 0.548, 1.0),
}

var armor_skin: ArmorSkin = ArmorSkin.NONE:
	set(value):
		armor_skin = value
		_apply_skin()

func _ready() -> void:
	var body: CSGSphere3D = get_node_or_null("CSGCombiner3D/Body") as CSGSphere3D
	if body and body.material is ShaderMaterial:
		body.material = body.material.duplicate()
	_apply_skin()

func set_armor_skin(skin: ArmorSkin) -> void:
	armor_skin = skin

func _apply_skin() -> void:
	var color: Color = SKIN_COLORS[armor_skin]
	var body: CSGSphere3D = get_node_or_null("CSGCombiner3D/Body") as CSGSphere3D
	if body and body.material is ShaderMaterial:
		var mat: ShaderMaterial = body.material as ShaderMaterial
		mat.set_shader_parameter("albedo", color)
