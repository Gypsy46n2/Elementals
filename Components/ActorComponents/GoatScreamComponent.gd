class_name GoatScreamComponent
extends Node

## Handles goat screaming mechanics including visuals, cooldowns, and social responses.

const SCREAM_TEXTURE = preload("res://assets/generated/scream_bubble_frame_0_1774821924.png")
const MAX_CONCURRENT_RESPONSES: int = 2
static var _pending_responses_count: int = 0

var actor: GoatActor
var scream_cooldown: float = 2.0
var _scream_timer: float = 0.0

func setup(p_actor: GoatActor, p_cooldown: float = 2.0) -> void:
	actor = p_actor
	scream_cooldown = p_cooldown

func update(delta: float) -> void:
	if _scream_timer > 0:
		_scream_timer -= delta

func can_scream() -> bool:
	return _scream_timer <= 0

func try_scream() -> bool:
	if _scream_timer > 0:
		return false
	_scream()
	return true

func _scream() -> void:
	_scream_timer = scream_cooldown
	var player: AudioStreamPlayer3D = actor.get_node_or_null("ScreamPlayer")
	if player and player.stream:
		player.play()
	_show_scream_visual()
	actor.screamed.emit(actor.global_position)

func try_respond_to_scream(pos: Vector3) -> void:
	if _scream_timer > 0 or _pending_responses_count >= MAX_CONCURRENT_RESPONSES:
		return
	if pos.distance_to(actor.global_position) >= 15.0 or randf() >= 0.25:
		return

	_pending_responses_count += 1
	var timer := actor.get_tree().create_timer(randf_range(0.3, 1.2))
	timer.timeout.connect(func() -> void:
		_pending_responses_count -= 1
		if not is_instance_valid(actor):
			return
		var is_charging := false
		var ability_comp = actor.get("ability_component")
		if ability_comp:
			for action in ability_comp.actions:
				if action is GoatCharge and action.is_charging:
					is_charging = true
					break
		if not is_charging and not actor.is_stunned():
			try_scream()
	)

func _show_scream_visual() -> void:
	var sprite := Sprite3D.new()
	if SCREAM_TEXTURE:
		sprite.texture = SCREAM_TEXTURE
		sprite.pixel_size = 0.04
	else:
		_show_scream_text()
		return

	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.position = Vector3(0, 1.8, 0.1)
	sprite.modulate = Color.WHITE
	actor.add_child(sprite)

	sprite.scale = Vector3.ZERO
	var tween := actor.create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector3.ONE * 1.2, 0.15)
	for i in range(4):
		var shake_offset := Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), 0)
		tween.tween_property(sprite, "position", Vector3(0, 0.8, 0.1) + shake_offset, 0.05)
	tween.tween_property(sprite, "position", Vector3(0, 0.8, 0.1), 0.05)
	tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "position:y", 1.1, 0.4).set_delay(0.2)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.4).set_delay(0.2)
	tween.tween_callback(sprite.queue_free)

func _show_scream_text() -> void:
	var label := Label3D.new()
	label.text = "BAAAAAA!"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 0.75, 0)
	label.modulate = Color.WHITE
	label.outline_modulate = Color.BLACK
	actor.add_child(label)
	var tween := actor.create_tween()
	tween.tween_property(label, "position:y", 1.25, 0.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)
