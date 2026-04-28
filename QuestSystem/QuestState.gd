extends Node

const SAVE_PATH := "user://elementals_quest_state.json"

var active_quests: Dictionary = {}
var completed_quests: Dictionary = {}
var gold: int = 0

func _ready() -> void:
	load_state()
	QuestEvents.gold_changed.emit(gold)
	if has_node("/root/GameEvents"):
		GameEvents.gold_changed.emit(gold)

func can_accept_quest(quest_id: String) -> bool:
	if active_quests.size() > 0:
		return false
	var quest: Dictionary = QuestDatabase.get_quest(quest_id)
	if quest.is_empty():
		return false
	if completed_quests.has(quest_id) and not bool(quest.get("repeatable", false)):
		return false
	return true

func accept_quest(quest_id: String) -> bool:
	if not can_accept_quest(quest_id):
		QuestEvents.message("Finish your current quest before accepting another one.")
		return false
	var quest: Dictionary = QuestDatabase.get_quest(quest_id)
	if quest.is_empty():
		QuestEvents.message("Quest not found: %s" % quest_id)
		return false

	var objectives: Array = []
	for raw_obj in QuestDatabase.get_objectives(quest_id):
		if typeof(raw_obj) != TYPE_DICTIONARY:
			continue
		var obj: Dictionary = (raw_obj as Dictionary).duplicate(true)
		obj["current"] = 0
		obj["complete"] = false
		objectives.append(obj)

	active_quests[quest_id] = {
		"id": quest_id,
		"started_at": int(Time.get_unix_time_from_system()),
		"objectives": objectives
	}
	save_state()
	QuestEvents.quest_accepted.emit(quest_id)
	QuestEvents.quest_spawn_requested.emit(quest_id)
	QuestEvents.quest_log_changed.emit()
	QuestEvents.message("Quest accepted: %s" % String(quest.get("title", quest_id)))
	return true

func abandon_active_quest() -> void:
	if active_quests.is_empty():
		return
	var abandoned_ids: Array[String] = get_active_quest_ids()
	active_quests.clear()
	save_state()
	for quest_id in abandoned_ids:
		QuestEvents.quest_failed.emit(quest_id)
	QuestEvents.quest_log_changed.emit()
	QuestEvents.message("Quest abandoned.")

func fail_active_quest(reason: String = "Quest failed.") -> void:
	if active_quests.is_empty():
		return
	var failed_ids: Array[String] = get_active_quest_ids()
	active_quests.clear()
	save_state()
	for quest_id in failed_ids:
		QuestEvents.quest_failed.emit(quest_id)
	QuestEvents.quest_log_changed.emit()
	QuestEvents.message(reason)

func notify_kill(target_id: String, amount: int = 1) -> bool:
	return notify_event("kill", target_id, amount)


func _target_matches(objective_target: String, event_target: String) -> bool:
	var clean_objective: String = objective_target.to_lower().strip_edges()
	var clean_event: String = event_target.to_lower().strip_edges()
	if clean_objective.is_empty() or clean_event.is_empty():
		return false
	if clean_objective == clean_event:
		return true
	if _strip_quest_prefix(clean_objective) == clean_event:
		return true
	if clean_objective == _strip_quest_prefix(clean_event):
		return true
	if clean_objective == "goblins" and clean_event == "goblin":
		return true
	if clean_objective == "goblin" and clean_event == "goblins":
		return true
	return false

func _strip_quest_prefix(value: String) -> String:
	var clean_value: String = value.to_lower().strip_edges()
	if clean_value.begins_with("quest_"):
		return clean_value.substr(6)
	return clean_value

# Returns true when at least one active objective changed.
# This gives the spawn manager a clean fallback path when actor metadata is missing.
# © 2026 Micheal Chapin
func notify_event(event_type: String, target_id: String, amount: int = 1) -> bool:
	if amount <= 0 or active_quests.is_empty():
		return false
	var clean_type: String = event_type.to_lower().strip_edges()
	var clean_target: String = target_id.strip_edges()
	if clean_type.is_empty() or clean_target.is_empty():
		return false
	var changed: bool = false
	var quests_to_complete: Array[String] = []

	for quest_key in active_quests.keys():
		var quest_id: String = String(quest_key)
		var entry_value: Variant = active_quests.get(quest_id, {})
		if typeof(entry_value) != TYPE_DICTIONARY:
			continue
		var entry: Dictionary = entry_value as Dictionary
		var objectives_value: Variant = entry.get("objectives", [])
		var objectives: Array = (objectives_value as Array) if typeof(objectives_value) == TYPE_ARRAY else []
		var quest_changed: bool = false

		for i in range(objectives.size()):
			var objective_value: Variant = objectives[i]
			if typeof(objective_value) != TYPE_DICTIONARY:
				continue
			var obj: Dictionary = objective_value as Dictionary
			if bool(obj.get("complete", false)):
				continue
			if String(obj.get("type", "")).to_lower().strip_edges() != clean_type:
				continue
			var objective_target: String = String(obj.get("target", "")).strip_edges()
			if not _target_matches(objective_target, clean_target):
				continue

			var required: int = maxi(1, int(obj.get("required", 1)))
			var current: int = clampi(int(obj.get("current", 0)) + amount, 0, required)
			obj["current"] = current
			obj["complete"] = current >= required
			objectives[i] = obj
			quest_changed = true
			changed = true
			QuestEvents.quest_progressed.emit(quest_id, i, current, required)
			QuestEvents.message("%s: %d/%d" % [String(obj.get("label", clean_target)), current, required])

		if quest_changed:
			entry["objectives"] = objectives
			active_quests[quest_id] = entry
			if is_ready_to_complete(quest_id):
				quests_to_complete.append(quest_id)

	for quest_id in quests_to_complete:
		complete_quest(quest_id)

	if changed:
		save_state()
		QuestEvents.quest_log_changed.emit()
	return changed

func is_ready_to_complete(quest_id: String) -> bool:
	if not active_quests.has(quest_id):
		return false
	var entry_value: Variant = active_quests.get(quest_id, {})
	if typeof(entry_value) != TYPE_DICTIONARY:
		return false
	var entry: Dictionary = entry_value as Dictionary
	var objectives_value: Variant = entry.get("objectives", [])
	var objectives: Array = (objectives_value as Array) if typeof(objectives_value) == TYPE_ARRAY else []
	if objectives.is_empty():
		return true
	for raw_obj in objectives:
		if typeof(raw_obj) != TYPE_DICTIONARY:
			continue
		var obj: Dictionary = raw_obj as Dictionary
		if not bool(obj.get("complete", false)):
			return false
	return true

func complete_quest(quest_id: String) -> bool:
	if not is_ready_to_complete(quest_id):
		return false
	var quest: Dictionary = QuestDatabase.get_quest(quest_id)
	if quest.is_empty():
		return false
	var reward_gold: int = int(quest.get("reward_gold", 0))
	add_gold(reward_gold)
	active_quests.erase(quest_id)
	var times: int = 0
	if completed_quests.has(quest_id) and typeof(completed_quests[quest_id]) == TYPE_DICTIONARY:
		var completed_entry: Dictionary = completed_quests[quest_id] as Dictionary
		times = int(completed_entry.get("times_completed", 0))
	completed_quests[quest_id] = {
		"completed_at": int(Time.get_unix_time_from_system()),
		"times_completed": times + 1
	}
	save_state()
	QuestEvents.quest_completed.emit(quest_id, reward_gold)
	QuestEvents.quest_log_changed.emit()
	QuestEvents.message("Quest complete! You earned %d gold." % reward_gold)
	return true

func add_gold(amount: int) -> void:
	if amount <= 0:
		return
	gold += amount
	save_state()
	QuestEvents.gold_changed.emit(gold)
	if has_node("/root/GameEvents"):
		GameEvents.gold_changed.emit(gold)

func get_active_quest_ids() -> Array[String]:
	var ids: Array[String] = []
	for quest_key in active_quests.keys():
		ids.append(String(quest_key))
	return ids

func get_active_quests() -> Array:
	var result: Array = []
	for quest_key in active_quests.keys():
		var quest_id: String = String(quest_key)
		var quest: Dictionary = QuestDatabase.get_quest(quest_id)
		if quest.is_empty():
			continue
		var progress_value: Variant = active_quests.get(quest_id, {})
		if typeof(progress_value) == TYPE_DICTIONARY:
			quest["progress"] = (progress_value as Dictionary).duplicate(true)
		result.append(quest)
	return result

func get_objective_lines(quest_id: String) -> Array[String]:
	var lines: Array[String] = []
	if not active_quests.has(quest_id):
		return lines
	var entry_value: Variant = active_quests.get(quest_id, {})
	if typeof(entry_value) != TYPE_DICTIONARY:
		return lines
	var entry: Dictionary = entry_value as Dictionary
	var objectives_value: Variant = entry.get("objectives", [])
	var objectives: Array = (objectives_value as Array) if typeof(objectives_value) == TYPE_ARRAY else []
	for raw_obj in objectives:
		if typeof(raw_obj) != TYPE_DICTIONARY:
			continue
		var obj: Dictionary = raw_obj as Dictionary
		var label: String = String(obj.get("label", obj.get("target", "Objective")))
		var current: int = int(obj.get("current", 0))
		var required: int = maxi(1, int(obj.get("required", 1)))
		var mark: String = "✓" if current >= required else "•"
		lines.append("%s %s (%d/%d)" % [mark, label, current, required])
	return lines

func save_state() -> void:
	var data: Dictionary = {
		"active_quests": active_quests,
		"completed_quests": completed_quests,
		"gold": gold
	}
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))

func load_state() -> void:
	active_quests.clear()
	completed_quests.clear()
	gold = 0
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file: FileAccess = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var data: Dictionary = parsed as Dictionary
	var active_value: Variant = data.get("active_quests", {})
	var completed_value: Variant = data.get("completed_quests", {})
	active_quests = (active_value as Dictionary) if typeof(active_value) == TYPE_DICTIONARY else {}
	completed_quests = (completed_value as Dictionary) if typeof(completed_value) == TYPE_DICTIONARY else {}
	gold = int(data.get("gold", 0))

func reset_all_quest_data() -> void:
	active_quests.clear()
	completed_quests.clear()
	gold = 0
	save_state()
	QuestEvents.gold_changed.emit(gold)
	QuestEvents.quest_log_changed.emit()
	QuestEvents.message("Quest data reset.")
