class_name PlayerInputComponent
extends Node

## PlayerInputComponent handles mouse and keyboard input for the Arena.
## It translates user events into actions performed by the currently controlled actor.

var arena: ArenaGrid

var current_target_index: int = 0
var current_controlled_actor: Actor:
	set(value):
		if is_instance_valid(current_controlled_actor):
			current_controlled_actor.is_controlled = false
		
		current_controlled_actor = value
		
		if current_controlled_actor:
			current_controlled_actor.is_controlled = true
			if arena and arena.ui_component:
				arena.ui_component.update_for_actor(current_controlled_actor)

var _ability_pressed: bool = false
var _ability_press_time: int = 0
var _hide_triggered: bool = false
const HOLD_THRESHOLD_MS: int = 300

# Camera cache for _get_mouse_3d_position optimization
var _cached_camera: Camera3D
var _camera_cache_time: float = 0.0
const CAMERA_CACHE_INTERVAL: float = 0.5  # Refresh every 500ms

## Initializes the component with a reference to the ArenaGrid.
func setup(p_arena: ArenaGrid) -> void:
	arena = p_arena

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	# Initial mouse state for the arena
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

## Processes mouse and keyboard input for actor actions.
func _unhandled_input(event: InputEvent) -> void:
	if not arena or not current_controlled_actor:
		return
		
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if current_controlled_actor.weapon_component:
				current_controlled_actor.weapon_component.launch_projectile_at(_get_mouse_3d_position())
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			if current_controlled_actor.weapon_component:
				current_controlled_actor.weapon_component.secondary_attack_at(_get_mouse_3d_position())
	
	if event is InputEventKey:
		if event.pressed:
			if event.keycode == KEY_E:
				current_controlled_actor.cycle_attack_pattern()
			elif event.keycode == KEY_Q:
				current_controlled_actor.prev_attack_pattern()
			elif event.keycode == KEY_T:
				if current_controlled_actor.weapon_component:
					current_controlled_actor.weapon_component.throw_weapon_at(_get_mouse_3d_position())
			elif event.keycode == KEY_SHIFT:
				_ability_pressed = true
				_ability_press_time = Time.get_ticks_msec()
			elif event.keycode == KEY_R:
				if current_controlled_actor and current_controlled_actor.ability_component:
					current_controlled_actor.ability_component.execute_ability("ability_r")
		else: # Key Released
			if event.keycode == KEY_SHIFT:
				_ability_pressed = false
				if _hide_triggered:
					if current_controlled_actor and current_controlled_actor.ability_component:
						current_controlled_actor.ability_component.execute_ability("hide", false)
					_hide_triggered = false
				else:
					var hold_duration: int = Time.get_ticks_msec() - _ability_press_time
					if hold_duration < HOLD_THRESHOLD_MS: # Tap
						if current_controlled_actor and current_controlled_actor.ability_component:
							var mouse_pos = _get_mouse_3d_position()
							var dash_dir = (current_controlled_actor.global_position - mouse_pos).normalized()
							if dash_dir.length() < 0.1:
								dash_dir = -current_controlled_actor.global_transform.basis.z
							dash_dir.y = 0
							current_controlled_actor.ability_component.execute_ability("disengage", dash_dir)

func _process(_delta: float) -> void:
	if _ability_pressed and not _hide_triggered:
		var hold_duration: int = Time.get_ticks_msec() - _ability_press_time
		if hold_duration >= HOLD_THRESHOLD_MS: # Hold
			if current_controlled_actor and current_controlled_actor.ability_component:
				current_controlled_actor.ability_component.execute_ability("hide", true)
			_hide_triggered = true

## Selects the first available playable actor to be controlled.
func select_initial_actor() -> void:
	var idx = _find_playable_actor(0, 1)
	if idx != -1:
		current_target_index = idx
		update_camera_target()

## Updates the camera to follow the currently selected actor and updates UI.
func update_camera_target() -> void:
	if not arena or arena.actors.is_empty():
		return
		
	var target = arena.actors[current_target_index % arena.actors.size()]
	if not is_instance_valid(target):
		return
		
	var _camera_follower = arena.get_node_or_null("Camera3D")
	if _camera_follower and _camera_follower is CameraFollower:
		_camera_follower.set_target(target)
		if target is GoatActor:
			_camera_follower.max_zoom = 10.0
		else:
			_camera_follower.max_zoom = 80.0
	
	current_controlled_actor = target as Actor

## Switches control to the next playable actor.
func next_actor() -> void:
	var next_idx = _find_playable_actor(current_target_index + 1, 1)
	if next_idx != -1:
		current_target_index = next_idx
		update_camera_target()

## Switches control to the previous playable actor.
func previous_actor() -> void:
	var prev_idx = _find_playable_actor(current_target_index - 1, -1)
	if prev_idx != -1:
		current_target_index = prev_idx
		update_camera_target()

## Searches for a playable actor in the actors array.
func _find_playable_actor(start_index: int, step: int) -> int:
	if not arena or arena.actors.is_empty():
		return -1
		
	var n = arena.actors.size()
	for i in range(n):
		# Correct wrapping for negative step
		var idx = (start_index + i * step) % n
		if idx < 0:
			idx += n
		
		var a = arena.actors[idx]
		if is_instance_valid(a) and a is Actor and a.is_playable:
			return idx
	return -1

## Uses a raycast from the mouse position to find the world-space coordinate.
## Camera is cached and refreshed periodically to avoid repeated get_camera_3d() calls.
func _get_mouse_3d_position() -> Vector3:
	# Refresh camera cache periodically
	_camera_cache_time -= get_process_delta_time()
	if _camera_cache_time <= 0.0 or not is_instance_valid(_cached_camera):
		_cached_camera = get_viewport().get_camera_3d()
		_camera_cache_time = CAMERA_CACHE_INTERVAL
	
	if not _cached_camera:
		return Vector3.ZERO
	
	var mouse_pos = _cached_camera.get_viewport().get_mouse_position()
	
	var ray_origin = _cached_camera.project_ray_origin(mouse_pos)
	var ray_direction = _cached_camera.project_ray_normal(mouse_pos)
	
	var space_state = arena.get_world_3d().direct_space_state
	var query = PhysicsRayQueryParameters3D.create(ray_origin, ray_origin + ray_direction * 1000.0)
	var result = space_state.intersect_ray(query)
	
	if not result.is_empty():
		return result.position
	
	if abs(ray_direction.y) < 1e-6:
		return Vector3.ZERO
	
	var t = -ray_origin.y / ray_direction.y
	return ray_origin + ray_direction * t
