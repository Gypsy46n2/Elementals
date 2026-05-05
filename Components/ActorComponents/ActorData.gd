class_name ActorData
extends Resource

## Base resource for actor data, holding standard ability scores and common attributes.
## Used to drive actor stats and visual variations.

signal stats_changed

@export_group("Ability Scores")
@export var strength: float = 1.0:
	set(v):
		if strength == v: return
		strength = v
		stats_changed.emit()

@export var dexterity: float = 1.0:
	set(v):
		if dexterity == v: return
		dexterity = v
		stats_changed.emit()

@export var constitution: float = 1.0:
	set(v):
		if constitution == v: return
		constitution = v
		stats_changed.emit()

@export var intelligence: float = 1.0:
	set(v):
		if intelligence == v: return
		intelligence = v
		stats_changed.emit()

@export var wisdom: float = 1.0:
	set(v):
		if wisdom == v: return
		wisdom = v
		stats_changed.emit()

@export var charisma: float = 1.0:
	set(v):
		if charisma == v: return
		charisma = v
		stats_changed.emit()
