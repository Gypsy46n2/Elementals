class_name GoblinActor
extends Actor

## Goblin Actor (legacy name support)
## This file exists to resolve a broken dependency in the scene loader.

func _init() -> void:
	element_type = "goblin"
	is_playable = false

func _ready() -> void:
	super._ready()
	faction_component.setup(FactionComponent.Faction.GOBLINS)
