class_name FireProjectile
extends WaveProjectile

const TEXTURE = preload("res://assets/generated/fire_particle_1774823455.png")

func _init() -> void:
	sprite_texture = TEXTURE
	wave_amplitude = 0.8
	wave_vertical_oscillation = 0.2
	wave_fwd_spacing = 0.4
	wave_time_scale = 0.25
	wave_up_multiplier = 0.5
	sprite_base_modulate = Color(1.4, 1.4, 1.4, 1.0)
