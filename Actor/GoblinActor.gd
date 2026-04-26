class_name GoblinActor
extends Actor

## Goblin Actor (legacy name support)
## This file exists to resolve a broken dependency in the scene loader.

func _init() -> void:
	element_type = "goblin"
	is_playable = false
	is_friendly = false

func _create_decision_component() -> ActorDecisionComponent:
	return GoblinDecisionComponent.new()
