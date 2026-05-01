class_name UIStyle

const COLOR_BG_MAIN := Color(0.055, 0.06, 0.075, 0.98)
const COLOR_BORDER_MAIN := Color(0.90, 0.68, 0.25, 0.94)
const COLOR_BG_CARD := Color(0.08, 0.085, 0.11, 0.94)
const COLOR_BORDER_CARD := Color(0.46, 0.36, 0.18, 0.88)
const COLOR_TEXT_GOLD := Color(1.0, 0.86, 0.32)
const COLOR_TEXT_BLUE := Color(0.65, 0.86, 1.0)
const COLOR_TEXT_CREAM := Color(0.82, 0.80, 0.72)

static func make_main_panel_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_MAIN
	style.border_color = COLOR_BORDER_MAIN
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	return style

static func make_card_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_CARD
	style.border_color = COLOR_BORDER_CARD
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style

static func make_button_normal_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_CARD
	style.border_color = COLOR_BORDER_CARD
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	return style

static func make_button_hover_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.105, 0.13, 0.96)
	style.border_color = COLOR_BORDER_MAIN
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style

static func make_button_pressed_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = COLOR_BG_MAIN
	style.border_color = COLOR_BORDER_MAIN
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style

static func apply_button_theme(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", make_button_normal_style())
	btn.add_theme_stylebox_override("hover", make_button_hover_style())
	btn.add_theme_stylebox_override("pressed", make_button_pressed_style())
	btn.add_theme_color_override("font_color", COLOR_TEXT_CREAM)
	btn.add_theme_color_override("font_hover_color", COLOR_TEXT_GOLD)
	btn.add_theme_color_override("font_pressed_color", COLOR_TEXT_GOLD)
