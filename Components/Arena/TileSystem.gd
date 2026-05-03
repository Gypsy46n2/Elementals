class_name TileSystem
extends Node

var active_registry: Dictionary = {} # axial_coords -> HexTileData
var arena: ArenaGrid

# Optimization: Store tiles by their next check time instead of checking every frame
var _scheduled_tiles: Array[Dictionary] = [] # [{tile, check_time}, ...]
var _process_timer: Timer

func _ready() -> void:
	if not arena:
		arena = get_parent() as ArenaGrid
	
	# Create a timer that processes tiles only when needed
	_process_timer = Timer.new()
	_process_timer.timeout.connect(_on_process_timer_timeout)
	_process_timer.one_shot = true
	add_child(_process_timer)

func _on_process_timer_timeout() -> void:
	var current_time = Time.get_ticks_msec() / 1000.0
	_process_due_tiles(current_time)
	_schedule_next_process()

# Process only tiles that are due (within a small epsilon for floating point safety).
# IMPORTANT: do NOT rebuild and reassign _scheduled_tiles at the end — _process_tile
# can call _schedule_tile which appends a new entry (e.g. fire's extinguish-in-1s
# follow-up). A wholesale reassign would silently delete those new entries and
# the follow-up event would never fire.
func _process_due_tiles(current_time: float) -> void:
	var epsilon = 0.05

	# 1. Snapshot which entries are due NOW.
	var to_process: Array[Dictionary] = []
	for entry in _scheduled_tiles:
		if entry["check_time"] <= current_time + epsilon:
			to_process.append(entry)

	# 2. Remove those due entries IN PLACE so processing can append new
	# schedule entries safely.
	var i: int = _scheduled_tiles.size() - 1
	while i >= 0:
		if _scheduled_tiles[i]["check_time"] <= current_time + epsilon:
			_scheduled_tiles.remove_at(i)
		i -= 1

	# 3. Now actually run the callbacks. They may mutate _scheduled_tiles.
	for entry in to_process:
		_process_tile(entry["tile"], entry["check_time"])

# Calculate next check time based on tile type and current duration
func _get_next_check_time(tile: HexTileData, current_time: float) -> float:
	match tile.tile_type:
		TileConstants.Type.FIRE:
			# Two events: spread at 4s, extinguish at 5s
			if tile.fire_duration < 4.0:
				return current_time + (4.0 - tile.fire_duration)
			else:
				return current_time + (5.0 - tile.fire_duration)
		TileConstants.Type.MUD:
			return current_time + (5.0 - tile.mud_duration)
		TileConstants.Type.PUDDLE:
			return current_time + (5.0 - tile.puddle_duration)
	return current_time + 1.0

func _schedule_next_process() -> void:
	if _scheduled_tiles.is_empty():
		return
	
	# Sort by check time to find the nearest one
	_scheduled_tiles.sort_custom(func(a, b): return a["check_time"] < b["check_time"])
	var next_time = _scheduled_tiles[0]["check_time"]
	var current_time = Time.get_ticks_msec() / 1000.0
	var delay = max(0.0, next_time - current_time)
	
	_process_timer.start(delay)

func _process_tile(tile: HexTileData, check_time: float) -> void:
	match tile.tile_type:
		TileConstants.Type.FIRE:
			_process_fire(tile, check_time)
		TileConstants.Type.MUD:
			_process_mud(tile, check_time)
		TileConstants.Type.PUDDLE:
			_process_puddle(tile, check_time)

func _process_fire(tile: HexTileData, check_time: float) -> void:
	# Fire has two events: spread at 4s, extinguish at 5s.
	# fire_duration was never incremented anywhere, so the original
	# conditions never fired. Advance it based on which scheduled event
	# this callback represents (the schedule was set up to land exactly
	# at duration 4.0 then 5.0 via _get_next_check_time).
	if not tile.fire_spread_triggered:
		tile.fire_duration = 4.0
	else:
		tile.fire_duration = 5.0

	if not tile.fire_spread_triggered and tile.fire_duration >= 4.0:
		tile.fire_spread_triggered = true
		arena.tile_interaction.spread_fire(tile)

	if tile.fire_duration >= 5.0:
		tile.fire_duration = 0.0
		tile.fire_spread_triggered = false
		arena.set_tile_state(tile, TileConstants.State.DIRT)
		active_registry.erase(tile.axial_coords)
		_unschedule_tile(tile)
	else:
		_schedule_tile(tile)

func _process_mud(tile: HexTileData, check_time: float) -> void:
	if arena._has_adjacent_grass(tile):
		if tile.mud_duration >= 5.0:
			arena.set_tile_state(tile, TileConstants.State.GRASS)
			tile.mud_duration = 0.0
			active_registry.erase(tile.axial_coords)
		else:
			_schedule_tile(tile)
	else:
		tile.mud_duration = 0.0
		check_activeness(tile)

func _process_puddle(tile: HexTileData, check_time: float) -> void:
	var dirt_neighbor = arena._get_adjacent_dirt(tile)
	if dirt_neighbor:
		if tile.puddle_duration >= 5.0:
			arena.set_tile_state(dirt_neighbor, TileConstants.State.MUD)
			tile.puddle_duration = 0.0
			_schedule_tile(tile)
		else:
			_schedule_tile(tile)
	else:
		tile.puddle_duration = 0.0
		check_activeness(tile)

func _schedule_tile(tile: HexTileData) -> void:
	# Remove existing schedule for this tile
	_unschedule_tile(tile)
	
	var current_time = Time.get_ticks_msec() / 1000.0
	var next_check = _get_next_check_time(tile, current_time)
	_scheduled_tiles.append({"tile": tile, "check_time": next_check})
	_schedule_next_process()

func _unschedule_tile(tile: HexTileData) -> void:
	# In-place removal. Avoids both:
	#   - Array.filter() returning an untyped Array, which then crashes on
	#     assignment to typed _scheduled_tiles: Array[Dictionary].
	#   - Replacing the array reference and accidentally clobbering entries
	#     appended by other callers in the same frame.
	var i: int = _scheduled_tiles.size() - 1
	while i >= 0:
		if _scheduled_tiles[i]["tile"] == tile:
			_scheduled_tiles.remove_at(i)
		i -= 1

# Compatibility wrapper - tiles are now processed via scheduled timers, not per-frame
func process_tiles(_delta: float) -> void:
	pass
func activate_tile(tile: HexTileData) -> void:
	active_registry[tile.axial_coords] = tile
	_schedule_tile(tile)

func check_activeness(tile: HexTileData) -> void:
	var should_be_active = false
	match tile.tile_type:
		TileConstants.Type.FIRE:
			should_be_active = true
		TileConstants.Type.MUD:
			if arena._has_adjacent_grass(tile):
				should_be_active = true
		TileConstants.Type.PUDDLE:
			if arena._get_adjacent_dirt(tile):
				should_be_active = true
	
	if should_be_active:
		if not active_registry.has(tile.axial_coords):
			activate_tile(tile)
	else:
		active_registry.erase(tile.axial_coords)
		_unschedule_tile(tile)
