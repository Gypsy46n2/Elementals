class_name WeaponData
extends Resource

signal ammo_changed(current: int, max: int)

@export var name: String = ""
@export var cost: String = ""
@export var damage: String = ""
@export var damage_type: String = ""
@export var weight: float = 0.0
@export var notes: String = ""
@export_file("*.tscn") var projectile_scene_path: String = ""
@export var icon: Texture2D

@export_group("Combat Stats")
@export var is_ranged: bool = false
@export var range_min: int = 0
@export var range_max: int = 0
@export var is_finesse: bool = false
@export var is_light: bool = false
@export var is_two_handed: bool = false
@export var is_versatile: bool = false
@export var versatile_damage: String = ""
@export var is_thrown: bool = false
@export var is_loading: bool = false
@export var is_heavy: bool = false
@export var reach: float = 2.0
@export var cone_width: float = 90.0
@export var cooldown: float = 0.6
@export var max_ammo: int = -1 # -1 means infinite
var _current_ammo: int = -1

@export var current_ammo: int:
	get: return _current_ammo
	set(v):
		_current_ammo = v
		ammo_changed.emit(_current_ammo, max_ammo)

func _init(p_name: String = "", p_cost: String = "", p_damage: String = "", p_type: String = "", p_weight: float = 0.0, p_notes: String = "", p_proj_path: String = "") -> void:
	name = p_name
	cost = p_cost
	damage = p_damage
	damage_type = p_type
	weight = p_weight
	notes = p_notes
	projectile_scene_path = p_proj_path
	
	_parse_notes()
	current_ammo = max_ammo

func _parse_notes() -> void:
	var n = notes.to_lower()
	is_light = "light" in n
	is_finesse = "finesse" in n
	is_thrown = "thrown" in n
	is_two_handed = "two-handed" in n
	is_versatile = "versatile" in n
	is_loading = "loading" in n
	is_heavy = "heavy" in n
	
	if "reach " in n:
		var reach_start = n.find("reach ")
		var sub = n.substr(reach_start + 6)
		var end = sub.find(",")
		if end == -1: end = sub.find(" ")
		if end == -1: end = sub.length()
		reach = float(sub.substr(0, end))
	elif "reach" in n:
		reach = 3.5
	
	if "cone " in n:
		var cone_start = n.find("cone ")
		var sub = n.substr(cone_start + 5)
		var end = sub.find(",")
		if end == -1: end = sub.find(" ")
		if end == -1: end = sub.length()
		cone_width = float(sub.substr(0, end))
	elif is_light:
		cooldown = 0.4
		cone_width = 110.0
	elif is_heavy:
		cooldown = 0.9
		cone_width = 70.0
	
	if "range" in n:
		# If it's a thrown melee weapon, we don't set it as ranged primarily
		if not is_thrown:
			is_ranged = true
		
		# Simple regex-ish parsing for (range X/Y)
		var start = n.find("range ")
		if start != -1:
			var sub = n.substr(start + 6)
			var end = sub.find(")")
			if end != -1:
				var range_str = sub.substr(0, end)
				var parts = range_str.split("/")
				if parts.size() >= 2:
					range_min = int(parts[0])
					range_max = int(parts[1])
	
	if "ammo " in n:
		var ammo_start = n.find("ammo ")
		var sub = n.substr(ammo_start + 5)
		var end = sub.find(",")
		if end == -1: end = sub.find(" ")
		if end == -1: end = sub.length()
		max_ammo = int(sub.substr(0, end))
	elif is_ranged:
		max_ammo = 20
	elif is_thrown:
		max_ammo = 5
	else:
		max_ammo = -1
	
	if is_versatile:
		var v_start = n.find("versatile (")
		if v_start != -1:
			var sub = n.substr(v_start + 11)
			var v_end = sub.find(")")
			if v_end != -1:
				versatile_damage = sub.substr(0, v_end)

func roll_damage(is_versatile_hit: bool = false) -> int:
	var dmg_str = versatile_damage if (is_versatile_hit and versatile_damage != "") else damage
	if dmg_str == "" or dmg_str == "-" or dmg_str == "—": return 1
	
	if not "d" in dmg_str:
		return int(dmg_str)
	
	var parts = dmg_str.split("d")
	if parts.size() < 2: return 1
	
	var num_dice = int(parts[0])
	var dice_size = int(parts[1])
	
	var total = 0
	for i in range(num_dice):
		total += randi() % dice_size + 1
	return total
