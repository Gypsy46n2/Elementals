extends Node

# Lightweight signals used by the modular quest/spawn system.
# © 2026 Micheal Chapin

signal quest_log_changed
signal quest_message(text: String)
signal quest_accepted(quest_id: String)
signal quest_spawn_requested(quest_id: String)
signal quest_progressed(quest_id: String, objective_index: int, current: int, required: int)
signal quest_ready_to_complete(quest_id: String)
signal quest_completed(quest_id: String, reward_gold: int)
signal quest_failed(quest_id: String)
signal camps_designated
signal gold_changed(new_gold: int)

func message(text: String) -> void:
	quest_message.emit(text)
