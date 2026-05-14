extends Node

signal selection_changed(item_name: String, index: int)
signal selection_index_changed(index: int)

## Items available for cycling
@export var items: Array[String] = []

## Current selection index
var current_index: int = 0:
	set(v):
		current_index = clampi(v, 0, max(0, items.size() - 1))

## Whether cycling is allowed (disabled if only 1 item)
var cycling_enabled: bool:
	get:
		return items.size() > 1

## Get the currently selected item name
func get_current() -> String:
	if items.is_empty() or current_index < 0 or current_index >= items.size():
		return ""
	return items[current_index]

## Cycle forward (increment index)
func cycle_forward() -> bool:
	if not cycling_enabled:
		return false
	
	var previous = current_index
	current_index = wrapi(current_index + 1, 0, items.size())
	
	if current_index != previous:
		_emit_changes()
		return true
	return false

## Cycle backward (decrement index)
func cycle_backward() -> bool:
	if not cycling_enabled:
		return false
	
	var previous = current_index
	current_index = wrapi(current_index - 1, 0, items.size())
	
	if current_index != previous:
		_emit_changes()
		return true
	return false

## Set to a specific index
func set_index(p_index: int) -> bool:
	var clamped = clampi(p_index, 0, max(0, items.size() - 1))
	if clamped == current_index:
		return false
	
	current_index = clamped
	_emit_changes()
	return true

## Set items and optionally reset index
func set_items(p_items: Array, p_reset_index: bool = true) -> void:
	items = Array(p_items, TYPE_STRING, "", null)
	if p_reset_index:
		current_index = 0

func _emit_changes() -> void:
	selection_changed.emit(get_current(), current_index)
	selection_index_changed.emit(current_index)


# ==================== STATIONARY HOLDER FOR CHARACTER SELECT CARD ====================

class StationaryCycler:
	## Holds cycle state for one category (weapons, abilities, armor)
	## Used when you want state without a full node (for CharacterSelectCard)
	
	var items: Array[String] = []
	var current_index: int = 0
	
	var cycling_enabled: bool:
		get:
			return items.size() > 1
	
	func get_current() -> String:
		if items.is_empty() or current_index < 0 or current_index >= items.size():
			return ""
		return items[current_index]
	
	func cycle_forward() -> bool:
		if not cycling_enabled:
			return false
		current_index = wrapi(current_index + 1, 0, items.size())
		return true
	
	func cycle_backward() -> bool:
		if not cycling_enabled:
			return false
		current_index = wrapi(current_index - 1, 0, items.size())
		return true
	
	func set_index(p_index: int) -> void:
		current_index = clampi(p_index, 0, max(0, items.size() - 1))
	
	func set_items(p_items: Array) -> void:
		items = Array(p_items, TYPE_STRING, "", null)
		current_index = clampi(current_index, 0, max(0, items.size() - 1))