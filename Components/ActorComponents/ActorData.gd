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

@export_group("Breeding")
enum Gender { MALE, FEMALE }
@export var gender: Gender = Gender.FEMALE:
	set(v):
		if gender == v: return
		gender = v
		stats_changed.emit()
@export var is_pregnant: bool = false:
	set(v):
		if is_pregnant == v: return
		is_pregnant = v
		stats_changed.emit()
@export var pregnancy_timer: int = 0:
	set(v):
		if pregnancy_timer == v: return
		pregnancy_timer = v
		stats_changed.emit()
@export var pregnancy_father: ActorData = null:
	set(v):
		if pregnancy_father == v: return
		pregnancy_father = v
		stats_changed.emit()
@export var is_exhausted: bool = false:
	set(v):
		if is_exhausted == v: return
		is_exhausted = v
		stats_changed.emit()

@export_group("Visual")
@export var base_color: Color = Color.WHITE:
	set(v):
		if base_color == v: return
		base_color = v
		stats_changed.emit()
@export var pattern_color: Color = Color.GRAY:
	set(v):
		if pattern_color == v: return
		pattern_color = v
		stats_changed.emit()

## Override in subclasses to create offspring with proper genetic mixing
func create_offspring(_partner: ActorData) -> ActorData:
	push_error("ActorData.create_offspring() must be overridden by subclass")
	return null

## Returns the type identifier for this actor (e.g., "GoatData", "GoblinData")
func get_actor_type() -> String:
	var script = get_script()
	if script:
		return script.get_global_name()
	return "ActorData"
