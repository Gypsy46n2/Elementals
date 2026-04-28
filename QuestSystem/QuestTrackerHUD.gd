extends CanvasLayer

var panel: PanelContainer
var title_label: Label
var objective_label: Label
var gold_label: Label
var message_label: Label
var message_timer: Timer

func _ready() -> void:
	layer = 80
	_build_ui()
	_connect_signals()
	_update_all()

func _connect_signals() -> void:
	if QuestEvents.quest_log_changed.is_connected(_update_all) == false:
		QuestEvents.quest_log_changed.connect(_update_all)
	if QuestEvents.quest_message.is_connected(_show_message) == false:
		QuestEvents.quest_message.connect(_show_message)
	if QuestEvents.gold_changed.is_connected(_on_gold_changed) == false:
		QuestEvents.gold_changed.connect(_on_gold_changed)

func _build_ui() -> void:
	panel = PanelContainer.new()
	panel.name = "QuestTrackerPanel"
	panel.position = Vector2(18, 155)
	panel.custom_minimum_size = Vector2(360, 130)
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.045, 0.06, 0.82)
	sb.border_color = Color(0.90, 0.68, 0.25, 0.85)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(10)
	panel.add_theme_stylebox_override("panel", sb)
	add_child(panel)

	var margin: MarginContainer = MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	margin.add_child(box)

	title_label = Label.new()
	title_label.text = "Quest Tracker"
	title_label.add_theme_font_size_override("font_size", 16)
	box.add_child(title_label)

	objective_label = Label.new()
	objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	objective_label.text = "No active quest."
	box.add_child(objective_label)

	gold_label = Label.new()
	gold_label.text = "Gold: 0"
	gold_label.add_theme_font_size_override("font_size", 15)
	box.add_child(gold_label)

	message_label = Label.new()
	message_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message_label.modulate = Color(1.0, 0.88, 0.45)
	message_label.text = ""
	box.add_child(message_label)

	message_timer = Timer.new()
	message_timer.one_shot = true
	message_timer.wait_time = 4.0
	message_timer.timeout.connect(func() -> void: message_label.text = "")
	add_child(message_timer)

func _update_all() -> void:
	gold_label.text = "Gold: %d" % QuestState.gold
	var active: Array = QuestState.get_active_quests()
	if active.is_empty():
		title_label.text = "Quest Tracker"
		objective_label.text = "No active quest. Open the Quest Board."
		return
	var quest: Dictionary = active[0] as Dictionary
	var quest_id: String = String(quest.get("id", ""))
	title_label.text = String(quest.get("title", quest_id))
	var lines: Array[String] = QuestState.get_objective_lines(quest_id)
	var joined: String = ""
	for line in lines:
		if not joined.is_empty():
			joined += "\n"
		joined += String(line)
	objective_label.text = joined

func _on_gold_changed(new_gold: int) -> void:
	gold_label.text = "Gold: %d" % new_gold

func _show_message(text: String) -> void:
	message_label.text = text
	message_timer.start()
