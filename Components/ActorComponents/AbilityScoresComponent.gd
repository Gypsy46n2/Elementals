class_name AbilityScoresComponent
extends Node

## Component that manages ability scores for an actor.
## Used to determine various combat and physical capabilities.

@export_group("Ability Scores")
@export var strength: float = 1.0
@export var dexterity: float = 1.0
@export var constitution: float = 1.0
@export var intelligence: float = 1.0
@export var wisdom: float = 1.0
@export var charisma: float = 1.0

func setup(_p_actor: Node) -> void:
	# Any initialization logic can go here.
	pass
