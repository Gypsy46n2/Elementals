## Singleton that manages foliage transparency based on visibility occlusion.
## Tracks "visible actors" (player character, spotted enemies) and updates
## foliage materials so they become semi-transparent when blocking view.

extends Node

## Signal emitted when a target is spotted (for visibility tracking).
signal target_spotted(enemy: Node3D)

## Signal emitted when a spotted target is lost.
signal target_lost(enemy: Node3D)

## All foliage mesh references that need transparency updates.
## Maps foliage node -> current opacity value (for lerped transitions).
var _foliage_opacity_map: Dictionary = {}

## Currently visible actors (player always + spotted enemies in ALERT/COMBAT).
var _visible_actors: Array[Node3D] = []

## Enemies that have been spotted and are currently in aggressive states.
var _spotted_enemies: Array[Node3D] = []

## Reference to the player character.
var _player: Node3D = null

## Camera being used for view calculations.
var _camera: Camera3D = null

## Lerp speed for opacity transitions (0.3 = ~3 frames to settle).
const OPACITY_LERP_SPEED: float = 0.3

## Trunk opacity when occluding actor.
const TRUNK_OCCLUDED_OPACITY: float = 0.3

## Canopy/foliage opacity when occluding actor.
const CANOPY_OCCLUDED_OPACITY: float = 0.5

## Full opacity when not occluding.
const FULL_OPACITY: float = 1.0

## Minimum opacity for lerped transitions.
const MIN_OPACITY: float = 0.1
@export var enable_debug_logs: bool = false

func _ready() -> void:
	# Register with the tree spawner to receive foliage references
	_setup_player_reference()
	_setup_enemy_detection()
	_log_debug("VisibilityManager: Ready - foliage_map size: %d" % _foliage_opacity_map.size())


func _process(delta: float) -> void:
	# Update camera reference
	var camera := get_viewport().get_camera_3d()
	if camera != _camera:
		_camera = camera
	
	# Update visible actors list
	_update_visible_actors()
	
	# Update foliage occlusion states
	_update_foliage_opacity(delta)


## Registers a foliage mesh for transparency tracking.
func register_foliage(foliage_node: Node, is_trunk: bool = false) -> void:
	if not _foliage_opacity_map.has(foliage_node):
		_foliage_opacity_map[foliage_node] = {
			"current_opacity": FULL_OPACITY,
			"target_opacity": FULL_OPACITY,
			"is_trunk": is_trunk
		}


## Unregisters a foliage mesh when the tree is destroyed.
func unregister_foliage(foliage_node: Node) -> void:
	_foliage_opacity_map.erase(foliage_node)


## Registers all foliage nodes from a HarvestableTree.
func register_tree(tree: Node3D) -> void:
	var count := 0
	# Find all CSG foliage spheres
	for child in tree.get_children():
		if child is CSGSphere3D:
			register_foliage(child, false)
			count += 1
		# Also register trunk segments as occluders
		elif child is CSGCylinder3D and child.name.begins_with("TrunkSegment"):
			register_foliage(child, true)
			count += 1
	_log_debug("VisibilityManager: Registered tree '%s' with %d foliage/trunk nodes. Total in map: %d" % [tree.name, count, _foliage_opacity_map.size()])


## Unregisters all foliage nodes from a HarvestableTree.
func unregister_tree(tree: Node3D) -> void:
	for foliage in _foliage_opacity_map.keys():
		if is_instance_valid(foliage) and foliage.get_parent() == tree:
			unregister_foliage(foliage)


func _setup_player_reference() -> void:
	# Find the player character
	var tree := get_tree()
	if not tree:
		return
	
	# First try to find current_controlled_actor from arena
	var arena = tree.get_first_node_in_group("arena")
	if arena and arena.has_method("get_current_controlled_actor"):
		_player = arena.get_current_controlled_actor()
	
	# Fallback: find any actor with is_controlled = true
	if not _player:
		for actor in tree.get_nodes_in_group("actors"):
			if actor.get("is_controlled") == true:
				_player = actor
				break


func _setup_enemy_detection() -> void:
	var tree := get_tree()
	if not tree:
		return
	
	# Listen for actor perceived/lost signals from DetectionComponents
	tree.node_added.connect(_on_node_added)
	
	# Connect to existing detection components
	for node in tree.get_nodes_in_group("actors"):
		_connect_detection_component(node)


func _on_node_added(node: Node) -> void:
	if node.has_method("get_perceived_actors"):
		_connect_detection_component(node)


func _connect_detection_component(node: Node) -> void:
	if node.has_method("get_perceived_actors"):
		if "actor_perceived" in node:
			if not node.actor_perceived.is_connected(_on_actor_perceived):
				node.actor_perceived.connect(_on_actor_perceived)
		if "actor_lost" in node:
			if not node.actor_lost.is_connected(_on_actor_lost):
				node.actor_lost.connect(_on_actor_lost)


func _on_actor_perceived(actor: Node3D) -> void:
	if not is_instance_valid(actor):
		return
	
	# Check if this actor is in an aggressive state (ALERT or COMBAT)
	if _is_enemy_in_aggressive_state(actor):
		if not _spotted_enemies.has(actor):
			_spotted_enemies.append(actor)
		target_spotted.emit(actor)


func _on_actor_lost(actor: Node3D) -> void:
	_spotted_enemies.erase(actor)
	target_lost.emit(actor)


func _is_enemy_in_aggressive_state(actor: Node3D) -> bool:
	# Check for various aggressive state indicators
	# 1. ActorAIController states
	var ai_controller = actor.get("controller")
	if ai_controller:
		var state_name = ai_controller.get_debug_state() if ai_controller.has_method("get_debug_state") else ""
		if state_name in ["ALERT", "CHARGING", "COMBAT", "ATTACK"]:
			return true
	
	# 2. GoatController states
	var goat_controller = actor.get("current_state")
	if goat_controller != null:
		# GoatController.State enum: ALERT, CHARGING indicate aggression
		return goat_controller in [1, 2]  # ALERT = 1, CHARGING = 2 (check enum values)
	
	# 3. Check state machine base state
	var sm = actor.get("state_machine")
	if sm and sm.has_method("get_base_state_name"):
		var state = sm.get_base_state_name()
		if state in ["alert", "chase", "attack", "combat", "charge", "charging"]:
			return true
	
	return false


func _update_visible_actors() -> void:
	_visible_actors.clear()
	
	# Player is always visible
	if is_instance_valid(_player):
		_visible_actors.append(_player)
	
	# Add spotted enemies in aggressive states
	for enemy in _spotted_enemies:
		if is_instance_valid(enemy) and _is_enemy_in_aggressive_state(enemy):
			if not _visible_actors.has(enemy):
				_visible_actors.append(enemy)


func _update_foliage_opacity(delta: float) -> void:
	if not is_instance_valid(_camera) or _visible_actors.is_empty():
		# No camera or visible actors - set all foliage to full opacity
		for foliage in _foliage_opacity_map.keys():
			if is_instance_valid(foliage):
				_set_target_opacity(foliage, FULL_OPACITY)
		return
	
	# Check each foliage for occlusion
	var occluded_foliage: Array[Node] = []
	
	for foliage in _foliage_opacity_map.keys():
		if not is_instance_valid(foliage):
			continue
		
		if _is_foliage_occluding_visible_actor(foliage):
			occluded_foliage.append(foliage)
			var is_trunk: bool = _foliage_opacity_map[foliage].get("is_trunk", false)
			var target_opacity := TRUNK_OCCLUDED_OPACITY if is_trunk else CANOPY_OCCLUDED_OPACITY
			_set_target_opacity(foliage, target_opacity)
		else:
			_set_target_opacity(foliage, FULL_OPACITY)
	
	# Lerp current opacity toward target
	for foliage in _foliage_opacity_map.keys():
		if not is_instance_valid(foliage):
			continue
		
		var data: Dictionary = _foliage_opacity_map[foliage]
		var current: float = data["current_opacity"]
		var target: float = data["target_opacity"]
		
		if abs(current - target) > 0.01:
			var new_opacity: float = lerp(current, target, OPACITY_LERP_SPEED)
			new_opacity = clamp(new_opacity, MIN_OPACITY, FULL_OPACITY)
			_apply_foliage_opacity(foliage, new_opacity)
			_foliage_opacity_map[foliage]["current_opacity"] = new_opacity


func _is_foliage_occluding_visible_actor(foliage: Node) -> bool:
	var foliage_pos: Vector3 = foliage.global_position
	var foliage_radius: float = _get_foliage_radius(foliage)
	
	for actor in _visible_actors:
		if not is_instance_valid(actor):
			continue
		
		var actor_pos: Vector3 = actor.global_position
		var camera_pos: Vector3 = _camera.global_position
		
		# Vector from camera to actor
		var to_actor: Vector3 = actor_pos - camera_pos
		# Vector from camera to foliage
		var to_foliage: Vector3 = foliage_pos - camera_pos
		
		# Check if foliage is between camera and actor
		var dot_actor: float = to_actor.normalized().dot(to_foliage.normalized())
		
		# Foliage must be in roughly the same direction as actor
		if dot_actor < 0.5:  # More than 60 degrees apart
			continue
		
		# Foliage must be closer to camera than actor for occlusion
		if to_foliage.length() > to_actor.length():
			continue
		
		# Check screen-space overlap using proper perspective projection
		var actor_screen: Vector2 = _camera.unproject_position(actor_pos)
		var foliage_screen_center: Vector2 = _camera.unproject_position(foliage_pos)
		
		# Calculate apparent foliage size in pixels
		var distance_to_camera: float = to_foliage.length()
		var fov_rad: float = deg_to_rad(_camera.fov)
		var screen_height: float = get_viewport().get_visible_rect().size.y
		var pixels_per_unit: float = screen_height / (2.0 * tan(fov_rad / 2.0))
		var foliage_apparent_radius_px: float = pixels_per_unit * foliage_radius / distance_to_camera
		
		# Add margin for foliage check area (3x the apparent radius)
		var foliage_rect := Rect2(
			foliage_screen_center.x - foliage_apparent_radius_px * 3.0,
			foliage_screen_center.y - foliage_apparent_radius_px * 3.0,
			foliage_apparent_radius_px * 6.0,
			foliage_apparent_radius_px * 6.0
		)
		
		# Actor radius estimate (scales with distance)
		var actor_distance: float = to_actor.length()
		var actor_radius_estimate: float = 0.6  # Approximate actor radius in world units
		var actor_apparent_radius_px: float = pixels_per_unit * actor_radius_estimate / actor_distance
		
		var actor_rect: Rect2 = Rect2(
			actor_screen.x - actor_apparent_radius_px * 1.5,
			actor_screen.y - actor_apparent_radius_px * 1.5,
			actor_apparent_radius_px * 3.0,
			actor_apparent_radius_px * 3.0
		)
		
		if foliage_rect.intersects(actor_rect):
			return true
	
	return false


func _get_foliage_radius(foliage: Node) -> float:
	if foliage is CSGSphere3D:
		return foliage.radius
	elif foliage is CSGCylinder3D:
		return foliage.radius
	return 1.0


func _get_foliage_screen_aabb(_foliage: Node, pos: Vector3, radius: float) -> Rect2:
	if not is_instance_valid(_camera):
		return Rect2()
	
	var center: Vector2 = _camera.unproject_position(pos)
	var extent: float = radius * 2.0
	
	return Rect2(
		center.x - extent,
		center.y - extent,
		extent * 2,
		extent * 2
	)


func _set_target_opacity(foliage: Node, target: float) -> void:
	if _foliage_opacity_map.has(foliage):
		_foliage_opacity_map[foliage]["target_opacity"] = target


func _apply_foliage_opacity(foliage: Node, opacity: float) -> void:
	if foliage is CSGShape3D:
		var mat := foliage.material as ShaderMaterial
		if mat:
			mat.set_shader_parameter("current_opacity", opacity)

func _log_debug(message: String) -> void:
	if enable_debug_logs:
		print(message)
