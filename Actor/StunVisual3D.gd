class_name StunVisual3D
extends Node3D

const BIRD_TEXTURE = preload("res://assets/generated/stun_bird_frame_0_1774946935.png")
const STAR_TEXTURE = preload("res://assets/generated/stun_star_frame_0_1774946936.png")

@export var radius: float = 1.0
@export var rotation_speed: float = 6.0
@export var bob_amplitude: float = 0.3
@export var bob_speed: float = 5.0

var _time: float = 0.0

func _ready() -> void:
	for i in range(6):
		var sprite = Sprite3D.new()
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.06
		sprite.texture = BIRD_TEXTURE if i % 2 == 0 else STAR_TEXTURE
		sprite.no_depth_test = true # Make it visible through the head if it clips
		sprite.render_priority = 10
		
		# Arrange in an oval
		var angle = (float(i) / 6.0) * TAU
		# Slight oval shape for better 3D look
		sprite.position = Vector3(cos(angle) * radius, 0, sin(angle) * (radius * 0.4))
		
		# Set metadata for individual bobbing
		sprite.set_meta("phase_offset", angle)
		
		add_child(sprite)

func _process(delta: float) -> void:
	_time += delta
	
	# Rotate the entire visual
	rotate_y(rotation_speed * delta)
	
	# Individual bobbing
	for child in get_children():
		if child is Sprite3D:
			var phase = _time * bob_speed + child.get_meta("phase_offset")
			child.position.y = sin(phase) * bob_amplitude
