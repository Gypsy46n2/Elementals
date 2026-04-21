extends Control

var color: Color = Color.WHITE
var mana_value: float = 1.0 # 0.0 to 1.0
var _last_mana_value: float = -1.0

var attack_pattern: int = 0: # Actor.AttackPattern
	set(value):
		attack_pattern = value
		queue_redraw()

func _draw() -> void:
	var center = size / 2.0
	var radius = 20.0
	var thickness = 3.0
	
	# Draw crosshair based on attack pattern
	var line_len = 8.0
	var gap = 4.0
	
	if attack_pattern == 0: # SINGLE
		# Horizontal lines
		draw_line(center + Vector2(-gap - line_len, 0), center + Vector2(-gap, 0), color, thickness)
		draw_line(center + Vector2(gap, 0), center + Vector2(gap + line_len, 0), color, thickness)
		# Vertical lines
		draw_line(center + Vector2(0, -gap - line_len), center + Vector2(0, -gap), color, thickness)
		draw_line(center + Vector2(0, gap), center + Vector2(0, gap + line_len), color, thickness)
		# Draw center dot
		draw_rect(Rect2(center - Vector2(1, 1), Vector2(2, 2)), color)
		
	elif attack_pattern == 1: # SPREAD
		# 3 radiating dots
		for angle in [-20, 0, 20]:
			var dir = Vector2.UP.rotated(deg_to_rad(angle))
			draw_circle(center + dir * (gap + line_len), 2.0, color)
		# Center small circle
		draw_arc(center, gap, 0, TAU, 16, color, thickness, true)
		
	elif attack_pattern == 2: # LOB
		# A landing zone circle
		draw_arc(center, line_len, 0, TAU, 16, color, thickness, true)
		# Small arrow pointing down
		draw_line(center + Vector2(0, -gap), center + Vector2(0, gap), color, thickness)
		draw_line(center + Vector2(-2, 0), center + Vector2(0, gap), color, thickness)
		draw_line(center + Vector2(2, 0), center + Vector2(0, gap), color, thickness)
	
	# Draw circular mana bar
	var start_angle = -PI / 2.0
	var end_angle = start_angle + (mana_value * TAU)
	
	# Background circle (dimmed)
	var bg_color = color
	bg_color.a = 0.2
	draw_arc(center, radius, 0, TAU, 32, bg_color, thickness, true)
	
	# Mana arc
	if mana_value > 0:
		draw_arc(center, radius, start_angle, end_angle, 32, color, thickness, true)

func _process(_delta: float) -> void:
	if not is_equal_approx(mana_value, _last_mana_value):
		queue_redraw()
		_last_mana_value = mana_value
	
	position = get_viewport().get_mouse_position() - size / 2.0
