class_name SaveComponent
extends Node

const SAVE_PATH = "user://herd_save.tres"
var _save_pending: bool = false

func save_game(herd: Array[ActorData], gold: int, current_day: int) -> void:
	if _save_pending:
		return
	
	_save_pending = true
	# Use a Callable to pass multiple arguments to call_deferred correctly
	_perform_save_deferred.call_deferred(herd, gold, current_day)

func _perform_save_deferred(herd: Array[ActorData], gold: int, current_day: int) -> void:
	_save_pending = false
	var save = GoatSaveData.new()
	save.herd = herd
	save.gold = gold
	save.current_day = current_day
	var err = ResourceSaver.save(save, SAVE_PATH)
	if err != OK:
		print("Error saving herd: ", err)

func load_game() -> GoatSaveData:
	if not FileAccess.file_exists(SAVE_PATH):
		return null
	
	# Check if file is empty or too small to be valid
	var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		push_warning("Could not open save file for reading: " + str(FileAccess.get_open_error()))
		return null
	var file_size = file.get_length()
	file.close()
	if file_size < 10:  # Minimum size for a valid .tres file
		push_warning("Save file is too small or empty, skipping load")
		return null
	
	var save = ResourceLoader.load(SAVE_PATH, "", ResourceLoader.CACHE_MODE_IGNORE)
	if save is GoatSaveData:
		# Convert legacy GoatData entries to ActorData for generic handling
		var converted_herd: Array[ActorData] = []
		for actor in save.herd:
			if actor is ActorData:
				converted_herd.append(actor)
		save.herd = converted_herd
		return save
	push_warning("Save file is corrupted or invalid format")
	return null
