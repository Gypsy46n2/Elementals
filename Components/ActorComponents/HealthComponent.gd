class_name HealthComponent
extends Node3D

## A unified health management component with built-in 3D UI.

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

var _hp_bar_node: ProgressBar
var _hp_viewport: SubViewport
var _hp_sprite: Sprite3D

func _ready() -> void:
	_setup_hp_bar()

func set_max_health(v: float) -> void:
	max_health = v
	if is_node_ready():
		if _hp_bar_node:
			_hp_bar_node.max_value = max_health
		# Use the setter directly to clamp current health if needed
		current_health = min(current_health, max_health)

func set_current_health(v: float) -> void:
	var old = current_health
	current_health = clamp(v, 0, max_health)
	if old != current_health:
		health_changed.emit(current_health, max_health)
		_update_hp_bar()
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

func _setup_hp_bar() -> void:
	# Create a SubViewport for the UI
	_hp_viewport = SubViewport.new()
	_hp_viewport.size = bar_size
	_hp_viewport.transparent_bg = true
	_hp_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(_hp_viewport)
	
	# Create the ProgressBar
	_hp_bar_node = ProgressBar.new()
	_hp_bar_node.size = bar_size
	_hp_bar_node.max_value = max_health
	_hp_bar_node.value = current_health
	_hp_bar_node.show_percentage = false
	
	# Style the ProgressBar
	var sb_fg = StyleBoxFlat.new()
	sb_fg.bg_color = bar_color
	sb_fg.set_border_width_all(2)
	sb_fg.border_color = Color.BLACK
	
	var sb_bg = StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.1, 0.1, 0.1, 1.0)
	
	_hp_bar_node.add_theme_stylebox_override("fill", sb_fg)
	_hp_bar_node.add_theme_stylebox_override("background", sb_bg)
	_hp_viewport.add_child(_hp_bar_node)
	
	# Create the Sprite3D to display it
	_hp_sprite = Sprite3D.new()
	_hp_sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_hp_sprite.no_depth_test = true
	_hp_sprite.render_priority = 10
	_hp_sprite.texture = _hp_viewport.get_texture()
	_hp_sprite.position = bar_offset
	_hp_sprite.pixel_size = 0.015
	add_child(_hp_sprite)
	
	_update_hp_bar()

func _update_hp_bar() -> void:
	if _hp_bar_node:
		_hp_bar_node.value = current_health
	
	if _hp_viewport:
		_hp_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	
	if _hp_sprite:
		_hp_sprite.visible = bar_visible_always or (current_health < max_health and current_health > 0)

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
