class_name ArmorData
extends Resource

enum ArmorType { NONE, LIGHT, MEDIUM, HEAVY, SHIELD }

@export var name: String = "Armor"
@export var type: ArmorType = ArmorType.NONE
@export var base_ac: int = 10
@export var dex_max: int = 99 ## Maximum Dexterity modifier allowed (e.g. 2 for Medium Armor)
@export var strength_requirement: int = 0 ## Minimum Strength SCORE required to avoid speed penalty
@export var stealth_disadvantage: bool = false
@export var weight: float = 0.0
@export var cost: int = 0

static func create_standard_armor(name: String) -> ArmorData:
	var a = ArmorData.new()
	a.name = name
	match name.to_lower():
		"padded":
			a.type = ArmorType.LIGHT
			a.base_ac = 11
			a.stealth_disadvantage = true
		"leather":
			a.type = ArmorType.LIGHT
			a.base_ac = 11
		"studded leather":
			a.type = ArmorType.LIGHT
			a.base_ac = 12
		"hide":
			a.type = ArmorType.MEDIUM
			a.base_ac = 12
			a.dex_max = 2
		"chain shirt":
			a.type = ArmorType.LIGHT
			a.base_ac = 13
			a.dex_max = 2
		"scale mail":
			a.type = ArmorType.MEDIUM
			a.base_ac = 14
			a.dex_max = 2
			a.stealth_disadvantage = true
		"breastplate":
			a.type = ArmorType.MEDIUM
			a.base_ac = 14
			a.dex_max = 2
		"half plate":
			a.type = ArmorType.MEDIUM
			a.base_ac = 15
			a.dex_max = 2
			a.stealth_disadvantage = true
		"ring mail":
			a.type = ArmorType.HEAVY
			a.base_ac = 14
			a.dex_max = 0
			a.stealth_disadvantage = true
		"chain mail":
			a.type = ArmorType.HEAVY
			a.base_ac = 16
			a.dex_max = 0
			a.strength_requirement = 13
			a.stealth_disadvantage = true
		"splint":
			a.type = ArmorType.HEAVY
			a.base_ac = 17
			a.dex_max = 0
			a.strength_requirement = 15
			a.stealth_disadvantage = true
		"plate":
			a.type = ArmorType.HEAVY
			a.base_ac = 18
			a.dex_max = 0
			a.strength_requirement = 15
			a.stealth_disadvantage = true
		"shield":
			a.type = ArmorType.SHIELD
			a.base_ac = 2
	return a
