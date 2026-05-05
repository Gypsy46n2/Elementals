class_name GoatData
extends ActorData

enum HornType { NONE, SMALL, LARGE, SPIRAL }
enum BodyType { SMALL, MEDIUM, LARGE }
enum PatternType { SOLID, PIEBALD, SPOTTED }
enum Gender { BUCK, DOE }

@export_group("Identity")
@export var goat_name: String = "New Goat":
	set(v): 
		if goat_name == v: return
		goat_name = v
		stats_changed.emit()
@export var level: int = 1:
	set(v):
		if level == v: return
		level = v
		stats_changed.emit()
@export var gender: Gender = Gender.DOE:
	set(v): 
		if gender == v: return
		gender = v
		stats_changed.emit()

@export_group("Genetics")
@export var horn_type: HornType = HornType.NONE:
	set(v): 
		if horn_type == v: return
		horn_type = v
		stats_changed.emit()
@export var body_type: BodyType = BodyType.MEDIUM:
	set(v): 
		if body_type == v: return
		body_type = v
		stats_changed.emit()
@export var pattern_type: PatternType = PatternType.SOLID:
	set(v): 
		if pattern_type == v: return
		pattern_type = v
		stats_changed.emit()
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

func _init() -> void:
	strength = 1.0
	dexterity = 1.0
	constitution = 0.0
	intelligence = -4.0
	wisdom = 0.0
	charisma = -3.0

@export_group("Performance Stats")
@export var stamina_max: float = 100.0:
	set(v): 
		if stamina_max == v: return
		stamina_max = v
		stats_changed.emit()
@export var stamina_current: float = 100.0:
	set(v): 
		if stamina_current == v: return
		stamina_current = v
		stats_changed.emit()

@export_group("Lifecycle")
@export var age_days: int = 0:
	set(v): 
		if age_days == v: return
		age_days = v
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
@export var pregnancy_father: GoatData = null:
	set(v):
		if pregnancy_father == v: return
		pregnancy_father = v
		stats_changed.emit()
@export var is_exhausted: bool = false:
	set(v): 
		if is_exhausted == v: return
		is_exhausted = v
		stats_changed.emit()
@export var is_selected: bool = false:
	set(v): 
		if is_selected == v: return
		is_selected = v
		stats_changed.emit()

@export_group("Economy")
@export var gold_value: int = 50:
	set(v): 
		if gold_value == v: return
		gold_value = v
		stats_changed.emit()

## Helper to create a child from two parents (simplified genetics)
static func create_offspring(doe: GoatData, buck: GoatData) -> GoatData:
	var kid = GoatData.new()
	
	kid.goat_name = "Kid of " + doe.goat_name
	kid.gender = Gender.DOE if randf() < 0.5 else Gender.BUCK
	
	# Genetic inheritance with slight mutation
	kid.base_color = doe.base_color.lerp(buck.base_color, randf())
	kid.horn_type = doe.horn_type if randf() < 0.5 else buck.horn_type
	kid.body_type = doe.body_type if randf() < 0.5 else buck.body_type
	
	kid.strength = (doe.strength + buck.strength) * 0.5 * randf_range(0.9, 1.1)
	kid.dexterity = (doe.dexterity + buck.dexterity) * 0.5 * randf_range(0.9, 1.1)
	kid.constitution = (doe.constitution + buck.constitution) * 0.5 * randf_range(0.9, 1.1)
	kid.intelligence = (doe.intelligence + buck.intelligence) * 0.5 * randf_range(0.9, 1.1)
	kid.wisdom = (doe.wisdom + buck.wisdom) * 0.5 * randf_range(0.9, 1.1)
	kid.charisma = (doe.charisma + buck.charisma) * 0.5 * randf_range(0.9, 1.1)
	
	return kid
