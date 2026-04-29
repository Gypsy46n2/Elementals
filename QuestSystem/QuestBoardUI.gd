extends CanvasLayer

# Modal quest board UI for the Elementals/Goatlandia quest addon.
# Opens only when the in-world QuestBoard3D calls open_board().
# © 2026 Micheal Chapin

var overlay: CanvasLayer = null
var _is_rebuilding: bool = false

func _ready() -> void:
	add_to_group("quest_board_ui")
	layer = 85
	set_process_input(true)
	set_process_unhandled_input(true)
	_connect_signals()

func _connect_signals() -> void:
	if QuestEvents.quest_log_changed.is_connected(_refresh_overlay) == false:
		QuestEvents.quest_log_changed.connect(_refresh_overlay)

func open_board() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_rebuild_overlay()

func close_board() -> void:
	_close_overlay()

func _rebuild_overlay() -> void:
	if _is_rebuilding:
		return
	_is_rebuilding = true
	_close_overlay()
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	overlay = CanvasLayer.new()
	overlay.name = "QuestBoardOverlay"
	overlay.layer = 120
	get_tree().root.add_child(overlay)

	var root: Control = Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(root)

	var dim: ColorRect = ColorRect.new()
	dim.name = "Dimmer"
	dim.color = Color(0, 0, 0, 0.50)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)

	var center: CenterContainer = CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var card: PanelContainer = PanelContainer.new()
	card.name = "QuestBoardCard"
	card.custom_minimum_size = Vector2(780, 560)
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = Color(0.055, 0.06, 0.075, 0.98)
	card_style.border_color = Color(0.90, 0.68, 0.25, 0.94)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(12)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_STOP
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	card.add_child(margin)

	var main: VBoxContainer = VBoxContainer.new()
	main.name = "Main"
	main.mouse_filter = Control.MOUSE_FILTER_STOP
	main.add_theme_constant_override("separation", 8)
	margin.add_child(main)

	var header: HBoxContainer = HBoxContainer.new()
	header.name = "Header"
	header.mouse_filter = Control.MOUSE_FILTER_STOP
	header.add_theme_constant_override("separation", 8)
	main.add_child(header)

	var heading: Label = Label.new()
	heading.text = "Quest Board"
	heading.modulate = Color(1.0, 0.86, 0.32)
	heading.add_theme_font_size_override("font_size", 28)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)

	var x_button: Button = Button.new()
	x_button.text = "X"
	x_button.tooltip_text = "Close Quest Board"
	x_button.custom_minimum_size = Vector2(38, 34)
	x_button.focus_mode = Control.FOCUS_NONE
	x_button.mouse_filter = Control.MOUSE_FILTER_STOP
	x_button.pressed.connect(_close_overlay)
	header.add_child(x_button)

	_add_wrapped(main, "Pick one quest. The board asks the arena spawner to place hostile quest goblins on random valid map tiles. Kill goblins on the map. Quest-spawned goblins and existing goblins both count, then the gold reward pays automatically.", Color(0.82, 0.80, 0.72))
	_add_wrapped(main, "Current Gold: %d" % QuestState.gold, Color(0.95, 0.80, 0.35))

	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.name = "QuestScroll"
	scroll.custom_minimum_size = Vector2(728, 390)
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.mouse_filter = Control.MOUSE_FILTER_STOP
	main.add_child(scroll)

	var body: VBoxContainer = VBoxContainer.new()
	body.name = "QuestList"
	body.custom_minimum_size = Vector2(704, 0)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 10)
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.add_child(body)

	var active: Array = QuestState.get_active_quests()
	if not active.is_empty():
		_add_label(body, "Active Quest", 19, Color(0.65, 0.86, 1.0))
		for raw_active in active:
			if typeof(raw_active) == TYPE_DICTIONARY:
				_add_active_quest_card(body, raw_active as Dictionary)
		_add_wrapped(body, "Finish or abandon the active quest before taking another one.", Color(0.95, 0.74, 0.45))
	else:
		_add_label(body, "Available Bounties", 19, Color(0.65, 0.86, 1.0))
		var quests: Array = QuestDatabase.get_all_quests()
		for raw_quest in quests:
			if typeof(raw_quest) == TYPE_DICTIONARY:
				_add_available_quest_card(body, raw_quest as Dictionary)

	var footer: HBoxContainer = HBoxContainer.new()
	footer.name = "Footer"
	footer.mouse_filter = Control.MOUSE_FILTER_STOP
	footer.add_theme_constant_override("separation", 8)
	main.add_child(footer)

	var hint: Label = Label.new()
	hint.text = "Close with X, Esc, or Close. Reopen by standing near the in-world board and pressing B."
	hint.modulate = Color(0.70, 0.72, 0.78)
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)

	var close_button: Button = Button.new()
	close_button.text = "Close"
	close_button.custom_minimum_size = Vector2(110, 34)
	close_button.focus_mode = Control.FOCUS_NONE
	close_button.mouse_filter = Control.MOUSE_FILTER_STOP
	close_button.pressed.connect(_close_overlay)
	footer.add_child(close_button)

	_is_rebuilding = false

func _input(event: InputEvent) -> void:
	if _should_close_from_escape(event):
		_close_overlay()
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if _should_close_from_escape(event):
		_close_overlay()
		get_viewport().set_input_as_handled()

func _should_close_from_escape(event: InputEvent) -> bool:
	if overlay == null or not is_instance_valid(overlay):
		return false
	if event is InputEventKey:
		var key_event: InputEventKey = event as InputEventKey
		if key_event.pressed and not key_event.echo and key_event.keycode == KEY_ESCAPE:
			return true
	if event.is_action_pressed("ui_cancel"):
		return true
	return false

func _add_available_quest_card(parent: Control, quest: Dictionary) -> void:
	var card: PanelContainer = _make_card(parent)
	var box: VBoxContainer = card.get_node("Margin/Body") as VBoxContainer
	var quest_id: String = String(quest.get("id", ""))
	_add_label(box, String(quest.get("title", quest_id)), 18, Color(1.0, 0.86, 0.36))
	_add_wrapped(box, String(quest.get("description", "")), Color(0.80, 0.80, 0.74))
	_add_wrapped(box, _objective_preview(quest), Color(0.72, 0.88, 1.0))
	_add_wrapped(box, "Reward: %d gold" % int(quest.get("reward_gold", 0)), Color(0.72, 0.95, 0.42))
	var accept: Button = Button.new()
	accept.text = "Accept + Spawn Goblins"
	accept.focus_mode = Control.FOCUS_NONE
	accept.mouse_filter = Control.MOUSE_FILTER_STOP
	accept.pressed.connect(func() -> void:
		if QuestState.accept_quest(quest_id):
			_close_overlay()
	)
	box.add_child(accept)

func _add_active_quest_card(parent: Control, quest: Dictionary) -> void:
	var card: PanelContainer = _make_card(parent)
	var box: VBoxContainer = card.get_node("Margin/Body") as VBoxContainer
	var quest_id: String = String(quest.get("id", ""))
	_add_label(box, String(quest.get("title", quest_id)), 18, Color(1.0, 0.86, 0.36))
	var lines: Array[String] = QuestState.get_objective_lines(quest_id)
	for line in lines:
		_add_wrapped(box, String(line), Color(0.72, 0.88, 1.0))
	_add_wrapped(box, "Reward on completion: %d gold" % int(quest.get("reward_gold", 0)), Color(0.72, 0.95, 0.42))
	var abandon: Button = Button.new()
	abandon.text = "Abandon Active Quest"
	abandon.focus_mode = Control.FOCUS_NONE
	abandon.mouse_filter = Control.MOUSE_FILTER_STOP
	abandon.pressed.connect(func() -> void:
		QuestState.abandon_active_quest()
		_close_overlay()
	)
	box.add_child(abandon)

func _make_card(parent: Control) -> PanelContainer:
	var card: PanelContainer = PanelContainer.new()
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	var card_style: StyleBoxFlat = StyleBoxFlat.new()
	card_style.bg_color = Color(0.08, 0.085, 0.11, 0.94)
	card_style.border_color = Color(0.46, 0.36, 0.18, 0.88)
	card_style.set_border_width_all(1)
	card_style.set_corner_radius_all(8)
	card.add_theme_stylebox_override("panel", card_style)
	parent.add_child(card)
	var margin: MarginContainer = MarginContainer.new()
	margin.name = "Margin"
	margin.mouse_filter = Control.MOUSE_FILTER_STOP
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	card.add_child(margin)
	var box: VBoxContainer = VBoxContainer.new()
	box.name = "Body"
	box.mouse_filter = Control.MOUSE_FILTER_STOP
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)
	return card

func _objective_preview(quest: Dictionary) -> String:
	var parts: Array[String] = []
	var objectives_value: Variant = quest.get("objectives", [])
	var objectives: Array = (objectives_value as Array) if typeof(objectives_value) == TYPE_ARRAY else []
	for raw_obj in objectives:
		if typeof(raw_obj) != TYPE_DICTIONARY:
			continue
		var obj: Dictionary = raw_obj as Dictionary
		parts.append("%s: 0/%d" % [String(obj.get("label", obj.get("target", "Objective"))), int(obj.get("required", 1))])
	var joined: String = ""
	for part in parts:
		if not joined.is_empty():
			joined += ", "
		joined += String(part)
	return "Objectives: " + joined

func _add_label(parent: Control, text: String, size: int, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)

func _add_wrapped(parent: Control, text: String, color: Color) -> void:
	var label: Label = Label.new()
	label.text = text
	label.modulate = color
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)

func is_open() -> bool:
	return overlay != null and is_instance_valid(overlay)

func _refresh_overlay() -> void:
	if overlay != null and is_instance_valid(overlay):
		call_deferred("_rebuild_overlay")

func _close_overlay() -> void:
	if overlay != null and is_instance_valid(overlay):
		overlay.queue_free()
		Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	overlay = null
	_is_rebuilding = false
