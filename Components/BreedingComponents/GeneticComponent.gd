class_name GeneticComponent
extends Node

@export var goat_data: GoatData
@export var sprite: Node

func _ready() -> void:
	if goat_data:
		goat_data.stats_changed.connect(_on_stats_changed)
	_on_stats_changed()

func _on_stats_changed() -> void:
	if goat_data and sprite:
		# Use self_modulate to change the goat's color 
		# while keeping the parent node's modulate clean
		if "self_modulate" in sprite:
			sprite.self_modulate = goat_data.base_color
		elif "modulate" in sprite:
			sprite.modulate = goat_data.base_color
