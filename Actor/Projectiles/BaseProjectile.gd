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
var _effect_range: float = 0.0
var _direction: Vector3 = Vector3.FORWARD
var remaining_charges: int = 0
var _elapsed: float = 0.0
var _affected_tiles: Dictionary = {}

var damage_component: DamageComponent

func initialize(arena: ArenaGrid, caster_position: Vector3, effect_range: float, direction: Vector3, velocity: float, max_charges: int, projectile_lifetime: float, projectile_max_range: float = 45.0) -> void:
	_arena = arena
	_caster_position = caster_position
	_start_position = global_transform.origin
	_effect_range = effect_range
	_direction = direction.normalized()
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
	if body is Actor:
		if body.element_type != element_type:
			if damage_component:
				damage_component.damage_amount = float(remaining_charges)
				damage_component.deal_damage(body)
			else:
				# Fallback
				if body.has_method("hit_by_projectile"):
					body.hit_by_projectile(self)
				else:
					body.take_damage(remaining_charges)
			queue_free()
	elif body.has_method("take_damage") or DamageComponent.find_health_component(body):
		if damage_component:
			damage_component.damage_amount = float(remaining_charges)
			damage_component.deal_damage(body)
		queue_free()

func _physics_process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= lifetime or remaining_charges <= 0:
		queue_free()
		return
	
	if global_transform.origin.distance_to(_start_position) >= max_range:
		queue_free()
		return
		
	translate(_direction * speed * delta)
	_apply_effect_to_tiles()

func _apply_effect_to_tiles() -> void:
	if not _arena or remaining_charges <= 0:
		return
		
	var tile_below := _get_tile_below()
	
	if not tile_below:
		return

	if tile_below.current_state == TileConstants.State.STONE:
		queue_free()
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
