class_name WeaponCard
extends DisplayCardBase

signal equipped(weapon: WeaponData)

@onready var name_label: Label = $VBoxContainer/NameLabel
@onready var icon_rect: TextureRect = $VBoxContainer/IconRect
@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var equip_button: Button = $VBoxContainer/EquipButton
@onready var ammo_label: Label = %AmmoLabel
@onready var ammo_container: MarginContainer = %AmmoContainer

var weapon_data: WeaponData:
	get:
		return data_resource as WeaponData
	set(v):
		setup(v)

func setup(p_data: Resource) -> void:
	super.setup(p_data)

func _ready() -> void:
	super._ready()
	_update_ui()
	equip_button.pressed.connect(_on_equip_pressed)

func _process(_delta: float) -> void:
	if not visible or not weapon_data: return
	_update_ammo_display()

func _update_ammo_display() -> void:
	if not weapon_data: return
	
	if weapon_data.max_ammo <= 0:
		ammo_container.visible = false
		return
	
	ammo_container.visible = true
	ammo_label.text = str(weapon_data.current_ammo) + "/" + str(weapon_data.max_ammo)

func _update_ui() -> void:
	if not weapon_data or not is_node_ready(): return
	_update_ammo_display()
	name_label.text = weapon_data.name
	if weapon_data.icon:
		icon_rect.texture = weapon_data.icon
	else:
		# Use a default icon or placeholder
		icon_rect.texture = null
		icon_rect.modulate = Color(0.5, 0.5, 0.5)
	
	var stats = "Cost: %s\nDamage: %s (%s)\nWeight: %.2f lbs" % [
		weapon_data.cost, weapon_data.damage, weapon_data.damage_type, weapon_data.weight
	]
	if weapon_data.notes and weapon_data.notes != "-" and weapon_data.notes != "—":
		stats += "\n\n%s" % weapon_data.notes
	
	stats_label.text = stats
	
	# Visual feedback if equipped
	var wl = get_node_or_null("/root/ItemsAutoload")
	if wl and wl.selected_weapon == weapon_data:
		equip_button.text = "Equipped"
		equip_button.disabled = true
	else:
		equip_button.text = "Equip"
		equip_button.disabled = false
	
	update_visual_state()

func _is_selected() -> bool:
	var wl = get_node_or_null("/root/ItemsAutoload")
	return wl and wl.selected_weapon == weapon_data

func _on_equip_pressed() -> void:
	var wl = get_node_or_null("/root/ItemsAutoload")
	if not wl or wl.selected_weapon == weapon_data: return
	
	wl.set_selected_weapon(weapon_data)
	equipped.emit(weapon_data)
	
	# Find other cards in parent and update them
	if get_parent():
		for child in get_parent().get_children():
			if child.has_method("_update_ui"):
				child._update_ui()

func _handle_selection() -> void:
	_on_equip_pressed()
	super._handle_selection()
