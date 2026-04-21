class_name WaterProjectile
extends WaveProjectile

const TEXTURE = preload("res://assets/generated/magic_water_drop_frame_0_1774826822.png")

func _init() -> void:
	sprite_texture = TEXTURE
	wave_amplitude = 1.0
	wave_vertical_oscillation = 0.3
	wave_fwd_spacing = 0.5
	wave_time_scale = 0.3
	wave_up_multiplier = 1.2
	sprite_base_modulate = Color.WHITE
