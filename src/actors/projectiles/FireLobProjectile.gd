class_name FireLobProjectile
extends LobProjectile

func _init() -> void:
	element_type = "fire"
	sprite_base_modulate = Color.WHITE
	sprite_texture = preload("res://assets/generated/fire_particle_1774823455.png")
	wave_speed = 0.6
	wave_amplitude = 0.8
	wave_vertical_oscillation = 0.4
	wave_fwd_spacing = 0.3
