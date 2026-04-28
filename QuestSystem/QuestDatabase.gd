extends Node

const QUEST_DATA_PATH := "res://QuestSystem/quests.json"

var quests: Dictionary = {}
var quest_order: Array[String] = []

func _ready() -> void:
	load_quests()

func load_quests() -> void:
	quests.clear()
	quest_order.clear()
	if not FileAccess.file_exists(QUEST_DATA_PATH):
		push_warning("Quest data not found: %s" % QUEST_DATA_PATH)
		return
	var file: FileAccess = FileAccess.open(QUEST_DATA_PATH, FileAccess.READ)
	if file == null:
		push_warning("Unable to open quest data: %s" % QUEST_DATA_PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Quest data must be a JSON dictionary with a quests array.")
		return
	var data: Dictionary = parsed as Dictionary
	var list: Array = data.get("quests", []) if typeof(data.get("quests", [])) == TYPE_ARRAY else []
	for raw_quest in list:
		if typeof(raw_quest) != TYPE_DICTIONARY:
			continue
		var quest: Dictionary = raw_quest as Dictionary
		var quest_id: String = String(quest.get("id", "")).strip_edges()
		if quest_id.is_empty():
			continue
		quests[quest_id] = quest.duplicate(true)
		quest_order.append(quest_id)

func get_quest(quest_id: String) -> Dictionary:
	if not quests.has(quest_id):
		return {}
	return (quests[quest_id] as Dictionary).duplicate(true)

func get_all_quests() -> Array:
	var result: Array = []
	for quest_id in quest_order:
		result.append(get_quest(quest_id))
	return result

func get_reward_gold(quest_id: String) -> int:
	var quest: Dictionary = get_quest(quest_id)
	return int(quest.get("reward_gold", 0))

func get_objectives(quest_id: String) -> Array:
	var quest: Dictionary = get_quest(quest_id)
	var objectives: Array = quest.get("objectives", []) if typeof(quest.get("objectives", [])) == TYPE_ARRAY else []
	return objectives.duplicate(true)

func get_spawns(quest_id: String) -> Array:
	var quest: Dictionary = get_quest(quest_id)
	var spawns: Array = quest.get("spawns", []) if typeof(quest.get("spawns", [])) == TYPE_ARRAY else []
	return spawns.duplicate(true)
