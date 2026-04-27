class_name GoatCard
extends DisplayCardBase

# signal selected(goat: GoatData) # Base class already has selected signal

@onready var renderer: GoatRenderer = $VBoxContainer/GoatRenderer
@onready var name_edit: LineEdit = $VBoxContainer/TopRow/NameEdit
@onready var stats_label: Label = $VBoxContainer/StatsLabel
@onready var arena_checkbox: CheckBox = $VBoxContainer/ArenaCheckBox

var goat_data: GoatData:
	get:
		return data_resource as GoatData
	set(v):
		setup(v)

func setup(p_data: Resource) -> void:
	if goat_data:
		if goat_data.stats_changed.is_connected(_update_ui):
			goat_data.stats_changed.disconnect(_update_ui)
	
	super.setup(p_data)
	
	if goat_data:
		goat_data.stats_changed.connect(_update_ui)

func _ready() -> void:
	super._ready()
	_update_ui()
	arena_checkbox.toggled.connect(_on_arena_toggled)
	
	if name_edit:
		name_edit.text_submitted.connect(_on_name_submitted)
		name_edit.focus_exited.connect(_on_name_focus_exited)

func _update_ui() -> void:
	if not goat_data or not is_node_ready(): return
	renderer.goat_data = goat_data
	
	if not name_edit.has_focus():
		name_edit.text = goat_data.goat_name
	
	var gender_str = "Doe" if goat_data.gender == GoatData.Gender.DOE else "Buck"
	var stats_text = "%s - Lvl: %d - Age: %d" % [gender_str, goat_data.level, goat_data.age_days]
	
	if goat_data.is_pregnant:
		stats_text += "\n[Pregnant]"
	if goat_data.is_exhausted:
		stats_text += "\n[Exhausted]"
		
	stats_text += "\nSTR: %.1f | DEX: %.1f | CON: %.1f" % [
		goat_data.strength, goat_data.dexterity, goat_data.constitution
	]
	stats_text += "\nINT: %.1f | WIS: %.1f | CHA: %.1f" % [
		goat_data.intelligence, goat_data.wisdom, goat_data.charisma
	]
	
	stats_label.text = stats_text
	
	# Small optimization: prevent toggled signal during manual update if possible
	# but the guard in _on_arena_toggled handles it too
	arena_checkbox.set_pressed_no_signal(goat_data.is_selected)
	arena_checkbox.disabled = goat_data.is_exhausted and not goat_data.is_selected
	
	update_visual_state()

func _is_selected() -> bool:
	return goat_data and goat_data.is_selected

func update_visual_state() -> void:
	if not goat_data: return
	
	if goat_data.is_selected:
		modulate = highlight_color
	else:
		modulate = Color(0.7, 0.7, 0.7) if goat_data.is_exhausted else base_color

func _on_arena_toggled(pressed: bool) -> void:
	if not goat_data: return
	if pressed != goat_data.is_selected:
		_toggle_arena_selection()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		# Check if we clicked on the LineEdit or CheckBox (they handle themselves)
		if name_edit.get_global_rect().has_point(event.global_position):
			return
		if arena_checkbox.get_global_rect().has_point(event.global_position):
			return
			
		_handle_selection()
		accept_event()

func _handle_selection() -> void:
	# Toggle ONLY Breeding state (Arena is handled by the checkbox)
	super._handle_selection()

func _toggle_arena_selection() -> void:
	GoatManager.toggle_selection(goat_data)
	# No need to manually update UI here as GoatManager emits herd_updated
	# which causes Ranch to refresh all cards.

func _on_name_submitted(new_text: String) -> void:
	if goat_data:
		goat_data.goat_name = new_text
	name_edit.release_focus()

func _on_name_focus_exited() -> void:
	if goat_data:
		goat_data.goat_name = name_edit.text
