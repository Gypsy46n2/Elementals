class_name HealthComponent
extends Node3D

## A unified health management component.
## Health bars are pooled via HealthBarPool singleton for efficiency.

signal health_changed(current: float, max: float)
signal health_depleted()
signal damage_received(amount: float, type: String)

@export_group("Stats")
@export var max_health: float = 10.0: set = set_max_health
@export var current_health: float = 10.0: set = set_current_health
@export var armor_class: int = 10

@export_group("Visuals")
@export var bar_color: Color = Color.GREEN
@export var bar_offset: Vector3 = Vector3(0, 1.5, 0)
@export var bar_visible_always: bool = false
@export var bar_size: Vector2 = Vector2(128, 16)

# Reference to the pooled health bar (if this actor has one)
var _pooled_bar: bool = false

func _ready() -> void:
	# Register with health bar pool if this actor needs visual health display
	if bar_visible_always or needs_health_bar():
		_register_with_pool()

func _enter_tree() -> void:
	# Re-register if we get added to a new scene
	if bar_visible_always or needs_health_bar():
		call_deferred("_register_with_pool")

func _exit_tree() -> void:
	# Unregister from pool when removed
	_unregister_from_pool()

func set_max_health(v: float) -> void:
	max_health = v
	if is_node_ready():
		# Use the setter directly to clamp current health if needed
		current_health = mini(current_health, max_health)
		_notify_pool()

func set_current_health(v: float) -> void:
	var old := current_health
	current_health = clampf(v, 0.0, max_health)
	if old != current_health:
		health_changed.emit(current_health, max_health)
		_notify_pool()
		if current_health <= 0:
			health_depleted.emit()

## Rolls hit dice and sets both max and current health to the result.
func roll_max_health(die_count: int, die_sides: int, rng: RandomNumberGenerator = null) -> float:
	var total: int = 0
	if rng:
		for i in range(die_count):
			total += rng.randi_range(1, die_sides)
	else:
		var fallback_rng := RandomNumberGenerator.new()
		fallback_rng.randomize()
		for i in range(die_count):
			total += fallback_rng.randi_range(1, die_sides)
	var result: float = float(total)
	max_health = result
	current_health = result
	return result

func needs_health_bar() -> bool:
	return true  # Override in subclasses to disable bars for certain actors

func _register_with_pool() -> void:
	if _pooled_bar:
		return
	var pool := HealthBarPool.get_instance()
	if pool:
		pool.show_bar(self, current_health, max_health, bar_color, bar_offset, bar_visible_always)
		_pooled_bar = true

func _unregister_from_pool() -> void:
	if not _pooled_bar:
		return
	var pool := HealthBarPool.get_instance()
	if pool:
		pool.hide_bar(self)
	_pooled_bar = false

func _notify_pool() -> void:
	if not _pooled_bar:
		return
	var pool := HealthBarPool.get_instance()
	if pool:
		pool.show_bar(self, current_health, max_health, bar_color, bar_offset, bar_visible_always)

func take_damage(amount: float, type: String = "normal", direction: Vector3 = Vector3.ZERO) -> void:
	current_health -= amount
	damage_received.emit(amount, type)
	_show_damage_indicator(amount, direction)

func show_miss(direction: Vector3 = Vector3.ZERO) -> void:
	var indicator = DamageIndicator.new()
	var parent = get_parent()
	if parent:
		var grand_parent = parent.get_parent()
		if grand_parent:
			grand_parent.add_child(indicator)
			indicator.global_position = parent.global_position + Vector3(0, 1.5, 0)
		else:
			parent.add_child(indicator)
			indicator.position = Vector3(0, 1.5, 0)
	else:
		add_child(indicator)
		indicator.position = Vector3(0, 1.5, 0)
	
	if indicator.has_method("setup_miss"):
		indicator.setup_miss(direction)
	else:
		indicator.setup(0, direction)

func _show_damage_indicator(amount: float, direction: Vector3) -> void:
	var indicator = DamageIndicator.new()
	var parent = get_parent()
	if parent:
		# If our parent is the Actor, we might want to add it to the Actor's parent (the Arena)
		var grand_parent = parent.get_parent()
		if grand_parent:
			grand_parent.add_child(indicator)
			indicator.global_position = parent.global_position + Vector3(0, 1.5, 0)
		else:
			parent.add_child(indicator)
			indicator.position = Vector3(0, 1.5, 0)
	else:
		add_child(indicator)
		indicator.position = Vector3(0, 1.5, 0)
	
	indicator.setup(amount, direction)

func heal(amount: float) -> void:
	current_health += amount

func reset() -> void:
	current_health = max_health

func is_dead() -> bool:
	return current_health <= 0.0
