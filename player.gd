extends CharacterBody2D

const SPEED: float = 150.0

@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D

func _physics_process(_delta: float) -> void:
	var direction: Vector2 = Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	velocity = direction * SPEED

	if velocity.length() > 0:
		if abs(velocity.x) > abs(velocity.y):
			if velocity.x > 0:
				animated_sprite.play("walk_right")
			else:
				animated_sprite.play("walk_left")
		else:
			if velocity.y > 0:
				animated_sprite.play("walk_down")
			else:
				animated_sprite.play("walk_up")
	elif animated_sprite.animation != "attack" or not animated_sprite.is_playing():
		animated_sprite.play("idle")

	if Input.is_action_just_pressed("ui_accept"):
		animated_sprite.play("attack")

	move_and_slide()
