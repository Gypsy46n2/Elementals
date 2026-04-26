class_name AbilityCard
extends DisplayCardBase

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var icon_rect: TextureRect = $VBoxContainer/IconRect
@onready var description_label: Label = $VBoxContainer/DescriptionLabel
@onready var usage_label: Label = $VBoxContainer/UsageLabel

func _update_ui() -> void:
	if not data_resource or not is_node_ready(): return
	
	var ability: AbilityData = data_resource as AbilityData
	if not ability: return
	
	name_label.text = ability.name
	if ability.icon:
		icon_rect.texture = ability.icon
		icon_rect.modulate = Color.WHITE
	else:
		icon_rect.texture = null
		icon_rect.modulate = Color(0.5, 0.5, 0.5)
	
	description_label.text = ability.description
	usage_label.text = "Usage: " + ability.usage
	
	update_visual_state()

func _is_selected() -> bool:
	# For now, let's assume we don't have an AbilityManager yet
	# but we can implement it similarly to Weapons later
	return false

func _handle_selection() -> void:
	# Call a manager if it exists
	if has_node("/root/AbilityManager"):
		var am = get_node("/root/AbilityManager")
		if am.has_method("select_ability"):
			am.select_ability(data_resource)
	
	super._handle_selection()
