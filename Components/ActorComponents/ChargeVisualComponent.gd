class_name ChargeVisualComponent
extends Node3D

## Manages multiple sprites representing "charges" of a projectile.
## Animates them in a wave pattern.

@export var sprite_texture: Texture2D
@export var sprite_pixel_size: float = 0.03
@export var sprite_base_modulate: Color = Color.WHITE

@export_group("Wave Animation")
@export var wave_speed: float = 0.4
@export var wave_amplitude: float = 1.0
@export var wave_vertical_oscillation: float = 0.3
@export var wave_up_multiplier: float = 1.0
@export var wave_fwd_spacing: float = 0.5
@export var wave_time_scale: float = 0.3

var _sprites: Array[Sprite3D] = []
var _random_offsets: Array[float] = []
var _rotation_angle: float = 0.0

func setup(count: int) -> void:
	# Clear existing sprites
	for s in _sprites:
		if is_instance_valid(s):
			s.queue_free()
	_sprites.clear()
	_random_offsets.clear()
	
	for i in range(count):
		var sprite = Sprite3D.new()
		sprite.texture = sprite_texture
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = sprite_pixel_size
		sprite.modulate = sprite_base_modulate
		add_child(sprite)
		_sprites.append(sprite)
		_random_offsets.append(randf() * TAU)

func update_visuals(remaining_charges: int, direction: Vector3, delta: float) -> void:
	_rotation_angle += delta * 15.0
	
	var active_count = remaining_charges
	if active_count <= 0:
		for s in _sprites:
			s.visible = false
		return
		
	# Calculate a horizontal vector perpendicular to movement
	var side_vec = Vector3(-direction.z, 0, direction.x).normalized()
	if side_vec.length_squared() < 0.01:
		side_vec = Vector3.RIGHT
		
	for i in range(_sprites.size()):
		var sprite = _sprites[i]
		if i < active_count:
			sprite.visible = true
			sprite.pixel_size = sprite_pixel_size
			
			# Use rotation angle to calculate a wave phase for each sprite
			var phase = (_rotation_angle * wave_time_scale) + (float(i) * 0.8) + _random_offsets[i]
			
			# Sine wave side-to-side offset
			var side_offset = sin(phase * wave_speed) * wave_amplitude
			# Vertical oscillation with configurable multiplier
			var up_offset = cos(phase * (wave_speed * wave_up_multiplier)) * wave_vertical_oscillation
			# Spread out along the path (behind the projectile head)
			var fwd_offset = -float(i) * wave_fwd_spacing
			
			# Position relative to node origin
			sprite.position = (side_vec * side_offset) + (Vector3.UP * up_offset) + (direction * fwd_offset)
			
			# Fade out the ones further back
			var alpha = 1.0 - (float(i) / active_count) * 0.4
			sprite.modulate.a = alpha * sprite_base_modulate.a
		else:
			sprite.visible = false
