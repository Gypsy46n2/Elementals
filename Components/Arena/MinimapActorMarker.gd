## Simple colored dot marker for actors on the arena minimap.
class_name MinimapActorMarker
extends Control

var marker_color: Color = Color.WHITE

func _ready() -> void:
	custom_minimum_size = Vector2(8, 8)
	size = Vector2(8, 8)

func _draw() -> void:
	var center: Vector2 = size * 0.5
	var radius: float = mini(size.x, size.y) * 0.5 - 1.0
	draw_circle(center, radius, marker_color)
