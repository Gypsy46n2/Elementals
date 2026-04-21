extends Control

@onready var goat_data: GoatData = $Goat/GeneticComponent.goat_data
@onready var red_slider: HSlider = $VBoxContainer/R/RedSlider
@onready var green_slider: HSlider = $VBoxContainer/G/GreenSlider
@onready var blue_slider: HSlider = $VBoxContainer/B/BlueSlider

func _ready() -> void:
	red_slider.value_changed.connect(_on_slider_value_changed)
	green_slider.value_changed.connect(_on_slider_value_changed)
	blue_slider.value_changed.connect(_on_slider_value_changed)
	
	# Initial update
	var color = goat_data.base_color
	red_slider.value = color.r
	green_slider.value = color.g
	blue_slider.value = color.b

func _on_slider_value_changed(_value: float) -> void:
	goat_data.base_color = Color(red_slider.value, green_slider.value, blue_slider.value)
