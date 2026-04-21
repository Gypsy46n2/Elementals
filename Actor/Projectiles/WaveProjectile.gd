class_name WaveProjectile
extends BaseProjectile

@export_group("Wave Visuals")
@export var sprite_texture: Texture2D
@export var sprite_pixel_size: float = 0.03
@export var wave_speed: float = 0.4
@export var wave_amplitude: float = 1.0
@export var wave_vertical_oscillation: float = 0.3
@export var wave_up_multiplier: float = 1.0
@export var wave_fwd_spacing: float = 0.5
@export var wave_time_scale: float = 0.3
@export var sprite_base_modulate: Color = Color.WHITE

var visual_component: ChargeVisualComponent

func initialize(arena: ArenaGrid, caster_position: Vector3, effect_range: float, direction: Vector3, velocity: float, max_charges: int, projectile_lifetime: float, projectile_max_range: float = 45.0) -> void:
	# Call super.initialize first to set remaining_charges
	super.initialize(arena, caster_position, effect_range, direction, velocity, max_charges, projectile_lifetime, projectile_max_range)
	
	# Hide the default sphere if it exists
	var visual = get_node_or_null("ProjectileVisual")
	if visual:
		visual.visible = false
	
	_setup_visual_component(max_charges)

func _setup_visual_component(count: int) -> void:
	if not visual_component:
		visual_component = ChargeVisualComponent.new()
		add_child(visual_component)
	
	# Sync properties
	visual_component.sprite_texture = sprite_texture
	visual_component.sprite_pixel_size = sprite_pixel_size
	visual_component.sprite_base_modulate = sprite_base_modulate
	visual_component.wave_speed = wave_speed
	visual_component.wave_amplitude = wave_amplitude
	visual_component.wave_vertical_oscillation = wave_vertical_oscillation
	visual_component.wave_up_multiplier = wave_up_multiplier
	visual_component.wave_fwd_spacing = wave_fwd_spacing
	visual_component.wave_time_scale = wave_time_scale
	
	visual_component.setup(count)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_visuals(delta)

func _update_visuals(delta: float) -> void:
	if visual_component:
		visual_component.update_visuals(remaining_charges, _direction, delta)
