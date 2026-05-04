class_name QuestTrackerHUD
extends Control

@onready var panel: PanelContainer = $QuestTrackerPanel
@onready var title_label: Label = $QuestTrackerPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var objective_label: Label = $QuestTrackerPanel/MarginContainer/VBoxContainer/ObjectiveLabel
@onready var gold_label: Label = $QuestTrackerPanel/MarginContainer/VBoxContainer/GoldLabel
@onready var message_label: Label = $QuestTrackerPanel/MarginContainer/VBoxContainer/MessageLabel
@onready var message_timer: Timer = $MessageTimer

func _ready() -> void:
	# Styling applied at runtime
	if panel:
		panel.add_theme_stylebox_override("panel", UIStyle.make_main_panel_style())
	
	if message_timer:
		message_timer.timeout.connect(func() -> void: if message_label: message_label.text = "")
	
	_connect_signals()
	_update_all()

func _connect_signals() -> void:
	if QuestEvents.quest_log_changed.is_connected(_update_all) == false:
		QuestEvents.quest_log_changed.connect(_update_all)
	if QuestEvents.quest_message.is_connected(_show_message) == false:
		QuestEvents.quest_message.connect(_show_message)
	if QuestEvents.gold_changed.is_connected(_on_gold_changed) == false:
		QuestEvents.gold_changed.connect(_on_gold_changed)

func _update_all() -> void:
	if not gold_label: return
	
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
	if gold_label:
		gold_label.text = "Gold: %d" % new_gold

func _show_message(text: String) -> void:
	if message_label:
		message_label.text = text
	if message_timer:
		message_timer.start()
