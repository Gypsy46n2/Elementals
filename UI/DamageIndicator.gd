class_name DamageIndicator
extends Label3D

func _ready() -> void:
	billboard = BaseMaterial3D.BILLBOARD_ENABLED
	no_depth_test = true
	render_priority = 30
	pixel_size = 0.008
	font_size = 64 # Use font_size instead of pixel_size for higher fidelity
	outline_size = 8
	modulate = Color.WHITE
	outline_modulate = Color.BLACK

func setup(amount: float, direction: Vector3) -> void:
	text = str(int(amount))
	if int(amount) <= 0:
		text = "0"
	
	if amount >= 5:
		modulate = Color.ORANGE
		
	_animate(direction)

func setup_miss(direction: Vector3) -> void:
	text = "Miss"
	modulate = Color.LIGHT_GRAY
	_animate(direction)

func _animate(direction: Vector3) -> void:
	# Initial random offset to avoid exact stacking
	position += Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), randf_range(-0.1, 0.1))
	
	var tween = create_tween()
	tween.set_parallel(true)
	
	# If direction is zero, pick a random horizontal one
	var move_dir = direction.normalized()
	if move_dir.length() < 0.1:
		var angle = randf() * TAU
		move_dir = Vector3(cos(angle), 0, sin(angle))
	
	# Move in direction + up
	var target_pos = position + move_dir * 1.5 + Vector3.UP * 1.5
	tween.tween_property(self, "position", target_pos, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.4).set_delay(0.4)
	tween.tween_property(self, "outline_modulate:a", 0.0, 0.4).set_delay(0.4)
	
	# Scale pop
	scale = Vector3.ZERO
	tween.tween_property(self, "scale", Vector3.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	tween.set_parallel(false)
	tween.tween_callback(queue_free)
