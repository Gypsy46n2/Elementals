class_name BaseProjectile
extends Area3D

@export var speed: float = 14.0
@export var lifetime: float = 5.0
@export var max_range: float = 45.0
@export var charge_capacity: int = 5

@onready var tile_ray: RayCast3D = $TileRay

@export var element_type: String = "none"
var _arena: ArenaGrid
var _start_position: Vector3
var _caster_position: Vector3
var caster: Node3D = null
var _effect_range: float = 0.0
var _direction: Vector3 = Vector3.FORWARD
var remaining_charges: int = 0
var _elapsed: float = 0.0
var _affected_tiles: Dictionary = {}

var damage_component: DamageComponent
var _is_stuck: bool = false
var _death_timer: float = 0.0
var source_weapon_data: WeaponData = null

var _host_actor: Actor = null
var _is_falling: bool = false
var _fall_velocity: float = 0.0

var _proximity_area: Area3D
var _interaction_label: Label3D
var _actor_in_range: Actor = null

func _ready() -> void:
	_setup_interaction_nodes()

func _setup_interaction_nodes() -> void:
	_proximity_area = Area3D.new()
	_proximity_area.collision_layer = 0
	_proximity_area.collision_mask = 3 # Mask 1 | 2 to catch most things including actors
	var shape = CollisionShape3D.new()
	var sphere = SphereShape3D.new()
	sphere.radius = 1.0
	shape.shape = sphere
	_proximity_area.add_child(shape)
	add_child(_proximity_area)
	_proximity_area.body_entered.connect(_on_proximity_entered)
	_proximity_area.body_exited.connect(_on_proximity_exited)
	_proximity_area.monitoring = false
	
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
	
	var item_name = "item"
	if source_weapon_data:
		item_name = source_weapon_data.name
	
	_interaction_label.text = "Press 'F' to pickup " + item_name
	_interaction_label.visible = true

func _input(event: InputEvent) -> void:
	if _actor_in_range and (event.is_action_pressed("ui_accept") or (event is InputEventKey and event.pressed and event.keycode == KEY_F)):
		if _is_stuck and not _is_falling:
			_pick_up(_actor_in_range)

func initialize(arena: ArenaGrid, p_caster: Node3D, p_caster_position: Vector3, effect_range: float, direction: Vector3, velocity: float, max_charges: int, projectile_lifetime: float, projectile_max_range: float = 45.0) -> void:
	_arena = arena
	caster = p_caster
	_caster_position = p_caster_position
	_start_position = global_transform.origin
	_effect_range = effect_range
	_direction = direction.normalized()
	
	# Rotate to face the direction of travel
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
	
	damage_component = DamageComponent.new()
	damage_component.damage_amount = float(remaining_charges)
	damage_component.element_type = element_type
	add_child(damage_component)
	
	if tile_ray:
		tile_ray.target_position = Vector3(0, -3.0, 0)
	
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if body == caster and not _is_stuck:
		return
	
	if _is_stuck:
		# Pickup is now handled by _proximity_area and input
		return

	if body is Actor:
		if body.element_type != element_type:
			if damage_component:
				damage_component.damage_amount = float(remaining_charges)
				damage_component.deal_damage(body, _direction)
			else:
				# Fallback
				if body.has_method("hit_by_projectile"):
					body.hit_by_projectile(self)
				else:
					body.take_damage(remaining_charges, "normal", _direction)
		_stick(body) # Don't queue_free, just stick for later pickup
	elif body.has_method("take_damage") or DamageComponent.find_health_component(body):
		if damage_component:
			damage_component.damage_amount = float(remaining_charges)
			damage_component.deal_damage(body, _direction)
		_stick()
	else:
		# Hit a wall or static obstacle
		_stick()

func _pick_up(actor: Actor) -> void:
	if _host_actor:
		# If the projectile is pulled out of someone, it deals damage
		var pull_damage: int = randi_range(1, 4)
		_host_actor.take_damage(float(pull_damage), "normal", -_direction)
		print(_host_actor.name, " took pull-out damage: ", pull_damage)

	if source_weapon_data:
		actor.add_weapon_ammo(source_weapon_data, remaining_charges)
		if actor.has_method("apply_pickup_penalty"):
			actor.apply_pickup_penalty()
		queue_free()

func _stick(target: Node3D = null) -> void:
	if _is_stuck:
		return
	
	# Only stick if we are a weapon that can be picked up
	if not source_weapon_data:
		queue_free()
		return
		
	_is_stuck = true
	_death_timer = -1.0 # Infinite
	
	# Enable interaction
	if _proximity_area:
		_proximity_area.monitoring = true
	
	# Small offset forward
	global_translate(_direction * 0.1)
	
	if target and target is Actor:
		_host_actor = target
		print("Projectile stuck to host: ", _host_actor.name)
		var current_global_transform = global_transform
		if is_inside_tree():
			reparent(_host_actor)
		global_transform = current_global_transform
		
		if not GameEvents.actor_died.is_connected(_on_host_died):
			GameEvents.actor_died.connect(_on_host_died)
	else:
		print("Projectile stuck to ground/wall")
	
	# Disable damage component if any
	if damage_component:
		damage_component.queue_free()
		damage_component = null

func _on_host_died(dead_actor: Node3D) -> void:
	if dead_actor == _host_actor:
		_host_actor = null
		_is_falling = true
		_fall_velocity = 0.0
		
		# Reparent back to the arena/parent of actor
		var current_global_transform = global_transform
		var parent = dead_actor.get_parent()
		if parent:
			reparent(parent)
		else:
			# Fallback to current scene root if no parent
			var scene = get_tree().current_scene
			if scene:
				reparent(scene)
		
		global_transform = current_global_transform

func _physics_process(delta: float) -> void:
	if _is_stuck:
		if _is_falling:
			_fall_velocity += 9.8 * delta
			global_position.y -= _fall_velocity * delta
			
			# Check if we hit the ground
			var ground_y = 0.0
			var tile = _get_tile_below()
			if tile:
				ground_y = float(tile.height_level) * 1.0 # 1.0 is default height_step
				if _arena:
					ground_y = (float(tile.height_level) * _arena.height_step) + _arena.global_position.y
			
			if global_position.y <= ground_y:
				global_position.y = ground_y
				_is_falling = false
				_fall_velocity = 0.0
		return

	_elapsed += delta
	if _elapsed >= lifetime or remaining_charges <= 0:
		_on_expire()
		return
	
	if global_transform.origin.distance_to(_start_position) >= max_range:
		_on_expire()
		return
		
	_move_projectile(delta)
	_apply_effect_to_tiles()

func _move_projectile(delta: float) -> void:
	global_translate(_direction * speed * delta)

func _on_expire() -> void:
	_stick()

func _apply_effect_to_tiles() -> void:
	if not _arena or remaining_charges <= 0:
		return
		
	var tile_below := _get_tile_below()
	
	if not tile_below:
		return

	if tile_below.current_state == TileConstants.State.STONE:
		_stick()
		return
		
	var tid = tile_below.get_instance_id()
	if _affected_tiles.has(tid):
		return
			
	if _do_projectile_effect(tile_below):
		remaining_charges -= 1
		_affected_tiles[tid] = true

func _do_projectile_effect(tile: HexTileData) -> bool:
	if not tile: return false
	
	# Apply to the tile itself (via ArenaGrid)
	var tile_handled = _arena.apply_element_to_tile(tile, element_type)
	
	# If there's a feature on the tile, apply element to it as a Node
	if tile.feature:
		DamageComponent.apply_element(tile.feature, element_type, _direction)
		
	return tile_handled

func _get_tile_below() -> HexTileData:
	if not _arena: return null
	return _arena.get_tile_data_at_world_position(global_transform.origin)
