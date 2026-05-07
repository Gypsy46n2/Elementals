class_name GeneticComponent
extends Node

@export var actor_data: ActorData
@export var sprite: Node

func _ready() -> void:
	if actor_data:
		actor_data.stats_changed.connect(_on_stats_changed)
	_on_stats_changed()

func _on_stats_changed() -> void:
	if actor_data and sprite:
		# Use self_modulate to change the actor's color 
		# while keeping the parent node's modulate clean
		if "self_modulate" in sprite:
			sprite.self_modulate = actor_data.base_color
		elif "modulate" in sprite:
			sprite.modulate = actor_data.base_color
