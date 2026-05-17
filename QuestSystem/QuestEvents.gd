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

func notify_log_changed() -> void:
	quest_log_changed.emit()

func notify_quest_accepted(quest_id: String) -> void:
	quest_accepted.emit(quest_id)

func notify_spawn_requested(quest_id: String) -> void:
	quest_spawn_requested.emit(quest_id)

func notify_progressed(quest_id: String, objective_index: int, current: int, required: int) -> void:
	quest_progressed.emit(quest_id, objective_index, current, required)

func notify_ready_to_complete(quest_id: String) -> void:
	quest_ready_to_complete.emit(quest_id)

func notify_quest_completed(quest_id: String, reward_gold: int) -> void:
	quest_completed.emit(quest_id, reward_gold)

func notify_quest_failed(quest_id: String) -> void:
	quest_failed.emit(quest_id)

func notify_camps_designated() -> void:
	camps_designated.emit()

func notify_gold_changed(new_gold: int) -> void:
	gold_changed.emit(new_gold)
