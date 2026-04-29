## Draws a yellow exclamation-mark-in-circle icon for the minimap.
class_name MinimapQuestMarker
extends Control

var _tween: Tween

func _ready() -> void:
	custom_minimum_size = Vector2(20, 20)
	size = Vector2(20, 20)
	_pulsate()

func _pulsate() -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween().set_loops().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_property(self, "scale", Vector2(1.15, 1.15), 0.6)
	_tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.6)

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = mini(size.x, size.y) * 0.5 - 1.0

	# Yellow circle background
	draw_circle(center, radius, Color(0.95, 0.78, 0.10, 0.95))
	# Dark outline
	draw_arc(center, radius, 0.0, TAU, 32, Color(0.15, 0.10, 0.02, 0.9), 2.0)

	# Exclamation mark body
	var bar_width: float = radius * 0.22
	var bar_height: float = radius * 0.55
	var bar_top: Vector2 = center + Vector2(-bar_width * 0.5, -radius * 0.35)
	draw_rect(Rect2(bar_top, Vector2(bar_width, bar_height)), Color(0.12, 0.08, 0.01, 0.95), true)

	# Exclamation mark dot
	var dot_radius: float = radius * 0.16
	var dot_center: Vector2 = center + Vector2(0.0, radius * 0.45)
	draw_circle(dot_center, dot_radius, Color(0.12, 0.08, 0.01, 0.95))
