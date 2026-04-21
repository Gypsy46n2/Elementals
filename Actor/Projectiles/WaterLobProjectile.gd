class_name WaterLobProjectile
extends LobProjectile

func _init() -> void:
	element_type = "water"
	sprite_base_modulate = Color.WHITE
	sprite_texture = preload("res://assets/generated/magic_water_drop_frame_0_1774826822.png")
	wave_speed = 0.5
	wave_amplitude = 1.0
	wave_vertical_oscillation = 0.3
	wave_fwd_spacing = 0.4
