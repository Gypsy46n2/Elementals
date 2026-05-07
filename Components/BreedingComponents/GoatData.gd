class_name GoatData
extends ActorData

enum HornType { NONE, SMALL, LARGE, SPIRAL }
enum BodyType { SMALL, MEDIUM, LARGE }
enum PatternType { SOLID, PIEBALD, SPOTTED }

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

## Creates offspring from this actor and a partner
func create_offspring(partner: ActorData) -> ActorData:
	var kid = GoatData.new()
	
	# Use reflection for goat-specific fields
	kid.goat_name = "Kid of " + (goat_name if "goat_name" in self else "Unknown")
	kid.gender = ActorData.Gender.FEMALE if randf() < 0.5 else ActorData.Gender.MALE
	
	# Genetic inheritance with slight mutation
	kid.base_color = base_color.lerp(partner.base_color, randf())
	kid.horn_type = horn_type if randf() < 0.5 else partner.horn_type
	kid.body_type = body_type if randf() < 0.5 else partner.body_type
	
	kid.strength = (strength + partner.strength) * 0.5 * randf_range(0.9, 1.1)
	kid.dexterity = (dexterity + partner.dexterity) * 0.5 * randf_range(0.9, 1.1)
	kid.constitution = (constitution + partner.constitution) * 0.5 * randf_range(0.9, 1.1)
	kid.intelligence = (intelligence + partner.intelligence) * 0.5 * randf_range(0.9, 1.1)
	kid.wisdom = (wisdom + partner.wisdom) * 0.5 * randf_range(0.9, 1.1)
	kid.charisma = (charisma + partner.charisma) * 0.5 * randf_range(0.9, 1.1)
	
	return kid
