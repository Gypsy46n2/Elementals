extends ScrollContainer

@onready var grid_container: GridContainer = %GridContainer
const WEAPON_CARD = preload("res://UI/WeaponCard.tscn")

func _ready() -> void:
	# Small delay to ensure EquipmentManager is initialized
	call_deferred("_populate_weapons")

func _populate_weapons() -> void:
	# Clear existing
	for child in grid_container.get_children():
		child.queue_free()
	
	var wl = get_node_or_null("/root/ItemsAutoload")
	if wl:
		for weapon in wl.weapons:
			var card = WEAPON_CARD.instantiate()
			grid_container.add_child(card)
			card.setup(weapon)
