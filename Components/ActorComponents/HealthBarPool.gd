class_name HealthBarPool
extends Node

## Singleton that pools SubViewport health bars for efficiency.
## Only renders bars for actors that need them and are visible.

const POOL_SIZE: int = 32
const BAR_SIZE: Vector2 = Vector2(128, 16)

static var _instance: HealthBarPool

var _pool: Array[BarInstance] = []
var _active_bars: Dictionary = {}  # actor_path -> BarInstance
var _camera: Camera3D

class BarInstance:
	var viewport: SubViewport
	var progress_bar: ProgressBar
	var sprite: Sprite3D
	var actor: Node3D
	var offset: Vector3
	var color: Color
	var always_visible: bool
	var in_use: bool = false

static func get_instance() -> HealthBarPool:
	if _instance == null:
		_instance = Engine.get_main_loop().root.find_child("HealthBarPool", true, false) as HealthBarPool
	return _instance

func _ready() -> void:
	if _instance == null:
		_instance = self
	_initialize_pool()

func _initialize_pool() -> void:
	for i in range(POOL_SIZE):
		var bar := _create_bar_instance()
		_pool.append(bar)

func _create_bar_instance() -> BarInstance:
	var bar := BarInstance.new()
	
	# Create SubViewport
	bar.viewport = SubViewport.new()
	bar.viewport.size = BAR_SIZE
	bar.viewport.transparent_bg = true
	bar.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	bar.viewport.disable_3d = true
	add_child(bar.viewport)
	
	# Create ProgressBar
	bar.progress_bar = ProgressBar.new()
	bar.progress_bar.size = BAR_SIZE
	bar.progress_bar.show_percentage = false
	
	# Style the ProgressBar
	var sb_fg := StyleBoxFlat.new()
	sb_fg.bg_color = Color.GREEN
	sb_fg.set_border_width_all(2)
	sb_fg.border_color = Color.BLACK
	
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.1, 0.1, 0.1, 1.0)
	
	bar.progress_bar.add_theme_stylebox_override("fill", sb_fg)
	bar.progress_bar.add_theme_stylebox_override("background", sb_bg)
	bar.viewport.add_child(bar.progress_bar)
	
	# Create Sprite3D (starts hidden)
	bar.sprite = Sprite3D.new()
	bar.sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bar.sprite.no_depth_test = true
	bar.sprite.render_priority = 10
	bar.sprite.texture = bar.viewport.get_texture()
	bar.sprite.pixel_size = 0.015
	bar.sprite.visible = false
	add_child(bar.sprite)
	
	return bar

func _get_available_bar() -> BarInstance:
	for bar in _pool:
		if not bar.in_use:
			bar.in_use = true
			return bar
	return null

func set_camera(camera: Camera3D) -> void:
	_camera = camera

func show_bar(actor: Node3D, current_health: float, max_health: float, 
		color: Color, offset: Vector3, always_visible: bool) -> void:
	var actor_path := actor.get_path()
	
	# If already showing for this actor, update it
	if _active_bars.has(actor_path):
		_update_bar(_active_bars[actor_path], current_health, max_health, color, always_visible)
		return
	
	# Check if visible and should show
	if not _should_show_bar(actor, current_health, max_health, always_visible):
		return
	
	# Get an available bar from pool
	var bar := _get_available_bar()
	if not bar:
		# Pool exhausted - try to reclaim from off-screen actors
		_reclaim_off_screen_bars()
		bar = _get_available_bar()
	
	if not bar:
		push_warning("HealthBarPool: No available bars in pool!")
		return
	
	# Configure the bar
	bar.actor = actor
	bar.offset = offset
	bar.sprite.visible = true
	
	# Update visuals
	_update_bar(bar, current_health, max_health, color, always_visible)
	
	_active_bars[actor_path] = bar

func _update_bar(bar: BarInstance, current_health: float, max_health: float, 
		color: Color, always_visible: bool) -> void:
	bar.progress_bar.max_value = max_health
	bar.progress_bar.value = current_health
	
	# Update fill color
	var sb_fg := bar.progress_bar.get_theme_stylebox("fill") as StyleBoxFlat
	if sb_fg:
		sb_fg.bg_color = color
	
	# Visibility: show if always_visible OR (damaged AND not dead)
	var should_show := always_visible or (current_health < max_health and current_health > 0)
	bar.sprite.visible = should_show
	
	# Trigger a render if visible
	if should_show and bar.viewport.render_target_update_mode == SubViewport.UPDATE_DISABLED:
		bar.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

func hide_bar(actor: Node3D) -> void:
	var actor_path := actor.get_path()
	if _active_bars.has(actor_path):
		var bar: BarInstance = _active_bars[actor_path]
		_release_bar(bar)
		_active_bars.erase(actor_path)

func _release_bar(bar: BarInstance) -> void:
	bar.in_use = false
	bar.actor = null
	bar.sprite.visible = false
	bar.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED

func update_bar_position(actor: Node3D) -> void:
	var actor_path := actor.get_path()
	if not _active_bars.has(actor_path):
		return
	
	var bar: BarInstance = _active_bars[actor_path]
	if bar.actor and is_instance_valid(bar.actor):
		bar.sprite.global_position = bar.actor.global_position + bar.offset

func _should_show_bar(actor: Node3D, current_health: float, max_health: float, always_visible: bool) -> bool:
	# Always show if configured that way
	if always_visible:
		return true
	
	# Only show if damaged and not dead
	if current_health >= max_health or current_health <= 0:
		return false
	
	# Check if in view of camera
	if _camera and not _is_in_view(actor):
		return false
	
	return true

func _is_in_view(actor: Node3D) -> bool:
	if not _camera or not is_instance_valid(actor):
		return true  # Default to visible if no camera
	
	var from: Vector3 = _camera.global_position
	var to: Vector3 = actor.global_position
	var dir: Vector3 = to - from
	
	var space_state := actor.get_world_3d().direct_space_state
	if space_state:
		var query := PhysicsRayQueryParameters3D.create(from, to)
		query.exclude.append(actor.get_rid())
		var result: Dictionary = space_state.intersect_ray(query)
		# If no hit, actor is visible (or occluders aren't set up)
		return result.is_empty()
	
	return true

func _reclaim_off_screen_bars() -> void:
	var to_reclaim: Array[BarInstance] = []
	
	for bar in _active_bars.values():
		if bar.actor and is_instance_valid(bar.actor):
			if not _is_in_view(bar.actor):
				to_reclaim.append(bar)
	
	for bar in to_reclaim:
		_release_bar(bar)
		# Find and remove from active
		for path in _active_bars.keys():
			if _active_bars[path] == bar:
				_active_bars.erase(path)
				break

func hide_all_bars() -> void:
	for bar in _active_bars.values():
		_release_bar(bar)
	_active_bars.clear()

func update_pool() -> void:
	"""Called each frame to update positions and cull off-screen bars."""
	if not _camera:
		return
	
	# Update positions for all active bars
	var to_hide: Array = []
	
	for actor_path in _active_bars.keys():
		var bar: BarInstance = _active_bars[actor_path]
		if not bar.actor or not is_instance_valid(bar.actor):
			to_hide.append(actor_path)
			continue
		
		# Update sprite position
		bar.sprite.global_position = bar.actor.global_position + bar.offset
		
		# Check if should still be visible
		var should_show := bar.sprite.visible
		if should_show and not _is_in_view(bar.actor):
			bar.sprite.visible = false
			bar.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
		elif not should_show and _is_in_view(bar.actor):
			# Re-check visibility based on health
			bar.viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	# Clean up invalid actors
	for actor_path in to_hide:
		var bar: BarInstance = _active_bars.get(actor_path)
		if bar:
			_release_bar(bar)
		_active_bars.erase(actor_path)
