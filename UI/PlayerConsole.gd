extends CanvasLayer

@onready var weapon_list: VBoxContainer = $Control/VBoxContainer/HBoxContainer/ListPanel/ScrollContainer/WeaponList
@onready var scroll_container: ScrollContainer = $Control/VBoxContainer/HBoxContainer/ListPanel/ScrollContainer
@onready var weapon_card: WeaponCard = $Control/VBoxContainer/HBoxContainer/CardContainer/CardsHBox/WeaponCard
@onready var ability_card: AbilityCard = get_node_or_null("Control/VBoxContainer/HBoxContainer/CardContainer/CardsHBox/AbilityCard")
@onready var actor_card: ActorCard = get_node_or_null("ActorCardContainer/ActorCard")
@onready var list_panel: PanelContainer = $Control/VBoxContainer/HBoxContainer/ListPanel
@onready var debug_list_toggle: CheckBox = $Control/VBoxContainer/DebugListToggle

var current_index: int = -1
var labels: Array[Label] = []

func _ready() -> void:
	# Wait for ItemsAutoload to be ready
	await get_tree().process_frame
	
	_populate_list()
	
	ItemsAutoload.weapon_selected.connect(_on_weapon_selected)
	ItemsAutoload.ability_selected.connect(_on_ability_selected)
	ItemsAutoload.actor_selected.connect(_on_actor_selected)
	
	debug_list_toggle.toggled.connect(_on_debug_toggled)
	list_panel.visible = debug_list_toggle.button_pressed
	
	if ItemsAutoload.selected_weapon:
		_on_weapon_selected(ItemsAutoload.selected_weapon)
	else:
		if ItemsAutoload.weapons.size() > 0:
			ItemsAutoload.set_selected_weapon(ItemsAutoload.weapons[0])
			
	if ItemsAutoload.selected_ability:
		_on_ability_selected(ItemsAutoload.selected_ability)
		
	if ItemsAutoload.selected_actor:
		_on_actor_selected(ItemsAutoload.selected_actor)

func _on_debug_toggled(p_pressed: bool) -> void:
	list_panel.visible = p_pressed

func _populate_list() -> void:
	for child in weapon_list.get_children():
		child.queue_free()
	
	labels.clear()
	
	for i in range(ItemsAutoload.weapons.size()):
		var weapon = ItemsAutoload.weapons[i]
		var label = Label.new()
		label.text = "  " + weapon.name # Indent slightly
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.custom_minimum_size.y = 28
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		
		# Add a visual style for the selection
		label.add_theme_font_size_override("font_size", 14)
		
		weapon_list.add_child(label)
		labels.append(label)
		
		# Allow clicking on list
		label.gui_input.connect(func(event: InputEvent):
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				ItemsAutoload.set_selected_weapon(weapon)
		)

func _input(event: InputEvent) -> void:
	if ItemsAutoload.weapons.is_empty(): return
	
	if event is InputEventKey and event.pressed and not event.is_echo():
		if event.keycode == KEY_E:
			_cycle(1)
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_Q:
			_cycle(-1)
			get_viewport().set_input_as_handled()

func _cycle(direction: int) -> void:
	if ItemsAutoload.weapons.is_empty(): return
	
	var next_index = (current_index + direction) % ItemsAutoload.weapons.size()
	if next_index < 0:
		next_index = ItemsAutoload.weapons.size() - 1
	
	ItemsAutoload.set_selected_weapon(ItemsAutoload.weapons[next_index])

func _on_weapon_selected(weapon: WeaponData) -> void:
	current_index = ItemsAutoload.weapons.find(weapon)
	
	# Update highlights
	for i in range(labels.size()):
		if i == current_index:
			labels[i].modulate = Color.YELLOW
			# Use call_deferred to ensure position is updated if needed
			call_deferred("_scroll_to_label", labels[i])
		else:
			labels[i].modulate = Color.WHITE
	
	# Update the card
	weapon_card.weapon_data = weapon
	weapon_card.visible = true

func _on_ability_selected(ability: AbilityData) -> void:
	if ability_card:
		if ability:
			ability_card.setup(ability)
			ability_card.visible = true
		else:
			ability_card.visible = false

func _on_actor_selected(actor: Actor) -> void:
	if actor_card:
		if actor:
			actor_card.set_actor(actor)
			actor_card.visible = true
		else:
			actor_card.visible = false

func _scroll_to_label(label: Label) -> void:
	if not is_instance_valid(label): return
	var scroll_pos = label.position.y
	var scroll_height = scroll_container.get_v_scroll_bar().page
	
	if scroll_pos < scroll_container.scroll_vertical:
		scroll_container.scroll_vertical = int(scroll_pos)
	elif scroll_pos + label.size.y > scroll_container.scroll_vertical + scroll_height:
		scroll_container.scroll_vertical = int(scroll_pos + label.size.y - scroll_height)
