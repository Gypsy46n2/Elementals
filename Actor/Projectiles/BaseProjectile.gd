class_name BaseProjectile
extends Area3D
	
	# --- Signals ---
signal expired
	
	# --- Constants ---
const GRAVITY = 9.8
const FALL_Y_THRESHOLD = -20.0 # Safety net
	
	# --- Exported Properties ---
@export_group("Movement")
@export var speed: float = 14.0
@export var lifetime: float = 5.0
@export var max_range: float = 45.0
	
@export_group("Combat")
@export var element_type: String = "none"
@export var charge_capacity: int = 5
	
	# --- Internal State ---
var caster: Node3D = null
var source_weapon_data: WeaponData = null
var remaining_charges: int = 0

var _arena: ArenaGrid
var _start_position: Vector3
var _direction: Vector3 = Vector3.FORWARD
var _elapsed: float = 0.0
var _affected_tiles: Dictionary = {}

var _is_stuck: bool = false
var _is_falling: bool = false
var _fall_velocity: float = 0.0
var _host_actor: Actor = null

# --- Node References ---
var damage_component: DamageComponent
@onready var tile_ray: RayCast3D = $TileRay
var _proximity_area: Area3D
var _interaction_label: Label3D
var _actor_in_range: Actor = null

	# --- Initialization ---
	
func _ready() -> void:
	_setup_interaction_nodes()
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func initialize(arena: ArenaGrid, p_caster: Node3D, p_caster_position: Vector3, _effect_range: float, direction: Vector3, velocity: float, max_charges: int, projectile_lifetime: float, projectile_max_range: float = 45.0) -> void:
	_arena = arena
	caster = p_caster
	_start_position = global_transform.origin
	_direction = direction.normalized()
	
	# Rotate to face direction
	if _direction.length_squared() > 0.001:
		var up_vec = Vector3.UP
		if abs(_direction.dot(Vector3.UP)) > 0.98:
			up_vec = Vector3.RIGHT
		look_at(global_transform.origin + _direction, up_vec)
	
	speed = velocity
	charge_capacity = max_charges
	remaining_charges = max_charges
	lifetime = projectile_lifetime
	max_range = projectile_max_range
	_elapsed = 0.0
	_affected_tiles.clear()
	
	# Damage setup
	_setup_damage_component()
	
	if tile_ray:
		tile_ray.target_position = Vector3(0, -3.0, 0)

func _setup_damage_component() -> void:
	if damage_component:
		damage_component.queue_free()
	
	damage_component = DamageComponent.new()
	damage_component.damage_amount = float(remaining_charges)
	damage_component.element_type = element_type
	add_child(damage_component)

# --- Interaction Logic ---

func _setup_interaction_nodes() -> void:
	# Proximity for pickup
	_proximity_area = Area3D.new()
	_proximity_area.collision_layer = 0
	_proximity_area.collision_mask = 2 # Actors
	var shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 1.2
	shape.shape = sphere
	_proximity_area.add_child(shape)
	add_child(_proximity_area)
	_proximity_area.body_entered.connect(_on_proximity_entered)
	_proximity_area.body_exited.connect(_on_proximity_exited)
	_proximity_area.monitoring = false # Disabled until stuck
	
	# Label
	_interaction_label = Label3D.new()
	_interaction_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_interaction_label.no_depth_test = true
	_interaction_label.render_priority = 10
	_interaction_label.text = ""
	_interaction_label.font_size = 48
	_interaction_label.outline_size = 12
	_interaction_label.position.y = 0.6
	_interaction_label.visible = false
	add_child(_interaction_label)

func _on_proximity_entered(body: Node3D) -> void:
	if body is Actor and body.is_controlled:
		_actor_in_range = body
		_update_interaction_label()

func _on_proximity_exited(body: Node3D) -> void:
	if body == _actor_in_range:
		_actor_in_range = null
		_interaction_label.visible = false

func _update_interaction_label() -> void:
	if not _actor_in_range: return
	var item_name = source_weapon_data.name if source_weapon_data else "item"
	_interaction_label.text = "Press 'F' to pickup " + item_name
	_interaction_label.visible = true

func _input(event: InputEvent) -> void:
	if not _is_stuck or _is_falling: return
	if not _actor_in_range: return
	
	if event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_F):
		_pick_up(_actor_in_range)

func _pick_up(actor: Actor) -> void:
	# Deal \"ripping out\" damage to host if alive
	if is_instance_valid(_host_actor) and _host_actor.is_inside_tree():
		var pull_damage: int = randi_range(2, 5)
		print("[Projectile] Dealing ", pull_damage, " pull-out damage to ", _host_actor.name)
		_host_actor.take_damage(float(pull_damage), "normal", -_direction)

	
	if source_weapon_data:
		actor.add_weapon_ammo(source_weapon_data, remaining_charges)
		if actor.has_method("apply_pickup_penalty"):
			actor.apply_pickup_penalty()
		
	queue_free()
	
	# --- Physics & Movement ---
	
func _physics_process(delta: float) -> void:
	if _is_stuck:
		if _is_falling:
			_process_falling(delta)
		return

	_elapsed += delta
	if _elapsed >= lifetime or remaining_charges <= 0:
		_stick()
		return
	
	if global_transform.origin.distance_to(_start_position) >= max_range:
		_stick()
		return
		
	_move_projectile(delta)
	_apply_effect_to_tiles()

func _move_projectile(delta: float) -> void:
	global_translate(_direction * speed * delta)

func _process_falling(delta: float) -> void:
	_fall_velocity += GRAVITY * delta
	global_position.y -= _fall_velocity * delta
	
	# Ground check
	var ground_y = 0.0
	if _arena:
		var tile = _arena.get_tile_data_at_world_position(global_position)
		if tile:
			ground_y = (float(tile.height_level) * _arena.height_step) + _arena.global_position.y
	
	if global_position.y <= ground_y:
		global_position.y = ground_y
		_is_falling = false
		_fall_velocity = 0.0
	
	if global_position.y < FALL_Y_THRESHOLD:
		queue_free()

	# --- Collision & Sticking ---
	
func _on_body_entered(body: Node3D) -> void:
	if _is_stuck or body == caster:
		return
	
	if body is Actor:
		_handle_actor_hit(body)
	elif body.has_method("take_damage") or DamageComponent.find_health_component(body):
		_handle_general_hit(body)
	else:
		_stick()

func _handle_actor_hit(actor: Actor) -> void:
	if actor.element_type != element_type:
		if damage_component:
			damage_component.damage_amount = float(remaining_charges)
			damage_component.deal_damage(actor, _direction)
		else:
			actor.take_damage(float(remaining_charges), "normal", _direction)
	_stick(actor)

func _handle_general_hit(body: Node3D) -> void:
	if damage_component:
		damage_component.damage_amount = float(remaining_charges)
		damage_component.deal_damage(body, _direction)
	_stick()

func _stick(target: Node3D = null) -> void:
	if _is_stuck: return
	
	# Only stick if we are a retrievable weapon
	if not source_weapon_data:
		queue_free()
		return
		
	_is_stuck = true
	
	# Proximity enable
	if _proximity_area:
		_proximity_area.monitoring = true
	
	# Forward nudge into target
	global_translate(_direction * 0.15)
	
	if target is Actor:
		_host_actor = target
		# Detach from world, attach to actor
		var current_global_pos = global_position
		var current_global_rot = global_rotation
		
		# We must use call_deferred for reparenting in collision callbacks
		_reparent_to_host.call_deferred(target, current_global_pos, current_global_rot)
		
		if not GameEvents.actor_died.is_connected(_on_host_died):
			GameEvents.actor_died.connect(_on_host_died)
	
	# Cleanup damage component
	if damage_component:
		damage_component.queue_free()
		damage_component = null

func _reparent_to_host(host: Node3D, pos: Vector3, rot: Vector3) -> void:
	if not is_instance_valid(host) or not host.is_inside_tree(): return
	reparent(host)
	global_position = pos
	global_rotation = rot

func _on_host_died(dead_actor: Node3D) -> void:
	if dead_actor == _host_actor:
		# Save world position before host teleports/removes
		var world_pos = global_position
		var world_rot = global_rotation
		
		_host_actor = null
		_is_falling = true
		_fall_velocity = 0.0
		
		# Detach immediately from the dying parent's transform space
		# This prevents teleporting if the actor moves in the same frame
		top_level = true 
		global_position = world_pos
		global_rotation = world_rot
		
		# Reparent back to world/arena deferred
		var arena = dead_actor.get_parent()
		if arena:
			_reparent_to_world.call_deferred(arena, world_pos, world_rot)

func _reparent_to_world(new_parent: Node, pos: Vector3, rot: Vector3) -> void:
	if not is_inside_tree(): return
	top_level = false
	reparent(new_parent)
	global_position = pos
	global_rotation = rot

# --- Environmental Interaction ---

func _apply_effect_to_tiles() -> void:
	if not _arena or remaining_charges <= 0: return
		
	var tile := _arena.get_tile_data_at_world_position(global_position)
	if not tile: return

	if tile.current_state == TileConstants.State.STONE:
		_stick()
		return
		
	var tid = tile.get_instance_id()
	if _affected_tiles.has(tid): return
			
	if _do_projectile_effect(tile):
		remaining_tiles_effect_consumed()
		_affected_tiles[tid] = true

func remaining_tiles_effect_consumed() -> void:
	remaining_charges -= 1

func _do_projectile_effect(tile: HexTileData) -> bool:
	var tile_handled = _arena.apply_element_to_tile(tile, element_type)
	if tile.feature:
		DamageComponent.apply_element(tile.feature, element_type, _direction)
	return tile_handled

func _get_tile_below() -> HexTileData:
	if not _arena: return null
	return _arena.get_tile_data_at_world_position(global_transform.origin)
