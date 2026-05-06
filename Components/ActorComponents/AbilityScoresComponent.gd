class_name AbilityScoresComponent
extends Node

## Component that manages ability scores for an actor.
## Used to determine various combat and physical capabilities.
## Default baseline is 0.

@export_group("Ability Scores")
@export var strength: float = 0
@export var dexterity: float = 0
@export var constitution: float = 0
@export var intelligence: float = 0
@export var wisdom: float = 0
@export var charisma: float = 0

## Emitted when any ability score changes. Used by components that cache score-dependent values.
signal scores_changed

func set_strength(value: float) -> void:
	strength = value
	scores_changed.emit()
func set_dexterity(value: float) -> void:
	dexterity = value
	scores_changed.emit()
func set_constitution(value: float) -> void:
	constitution = value
	scores_changed.emit()
func set_intelligence(value: float) -> void:
	intelligence = value
	scores_changed.emit()
func set_wisdom(value: float) -> void:
	wisdom = value
	scores_changed.emit()
func set_charisma(value: float) -> void:
	charisma = value
	scores_changed.emit()

## Returns the effective score for an ability (Score = 10 + Modifier * 2).
## This is used for requirement checks like Heavy Armor strength requirements.
func get_score(modifier_value: float) -> int:
	return int(10 + (modifier_value * 2))

func get_strength_score() -> int:
	return get_score(strength)

func get_dexterity_score() -> int:
	return get_score(dexterity)

func setup(_p_actor: Node) -> void:
	# Any initialization logic can go here.
	pass
