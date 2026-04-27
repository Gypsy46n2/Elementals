class_name ArmorClassComponent
extends Node

## Component that calculates the Armor Class (AC) for an actor.
## Handles different armor types, shields, and penalties according to D&D-like rules.

# For compatibility with existing scripts
enum ArmorType { NONE, LIGHT, MEDIUM, HEAVY }

@export_group("Armor Settings")
@export var armor_type: ArmorType = ArmorType.NONE:
	set(v):
		armor_type = v
		refresh()
@export var armor_value: int = 10: ## Base AC for None (usually 10), or Armor Value for others (e.g., 11 for Leather)
	set(v):
		armor_value = v
		refresh()
@export var has_shield: bool = false:
	set(v):
		has_shield = v
		refresh()

@export_group("Detailed Equipment")
## When set, this overrides the legacy armor_type and armor_value settings.
@export var equipped_armor: ArmorData:
	set(v):
		equipped_armor = v
		refresh()
## When set, this overrides the legacy has_shield setting.
@export var equipped_shield: ArmorData:
	set(v):
		equipped_shield = v
		refresh()

@export_group("Proficiency")
## Types of armor the actor is proficient with.
@export var proficiencies: Array[ArmorData.ArmorType] = [ArmorData.ArmorType.NONE]

var _actor: Node

func setup(p_actor: Node) -> void:
	_actor = p_actor
	refresh()

## Returns the current AC based on armor, shield, and dexterity.
func calculate_ac() -> int:
	var dex_mod: int = 0
	if _actor and "ability_scores_component" in _actor and _actor.ability_scores_component:
		dex_mod = int(_actor.ability_scores_component.dexterity)
	
	var base_ac: int = 10
	var dex_max: int = 99
	var is_heavy: bool = false
	
	if equipped_armor:
		base_ac = equipped_armor.base_ac
		dex_max = equipped_armor.dex_max
		is_heavy = equipped_armor.type == ArmorData.ArmorType.HEAVY
	else:
		# Use legacy properties
		base_ac = armor_value if armor_type != ArmorType.NONE else 10
		match armor_type:
			ArmorType.NONE, ArmorType.LIGHT: dex_max = 99
			ArmorType.MEDIUM: dex_max = 2
			ArmorType.HEAVY: 
				dex_max = 0
				is_heavy = true
	
	var final_ac: int = base_ac
	if is_heavy:
		# Heavy armor doesn't let you add your Dexterity modifier to your Armor Class,
		# but it also doesn't penalize you if your Dexterity modifier is negative.
		final_ac = base_ac
	else:
		final_ac = base_ac + clampi(dex_mod, -99, dex_max)
	
	# Handle Shield
	if equipped_shield and equipped_shield.type == ArmorData.ArmorType.SHIELD:
		final_ac += equipped_shield.base_ac
	elif has_shield:
		final_ac += 2
		
	return final_ac

## Checks if the wearer has disadvantage on Stealth.
func has_stealth_disadvantage() -> bool:
	if equipped_armor:
		return equipped_armor.stealth_disadvantage
	
	# Legacy fallback: Heavy armor usually gives disadvantage.
	if armor_type == ArmorType.HEAVY:
		return true
	
	return false

## Checks if the wearer meets the strength requirement for their armor.
func meets_strength_requirement() -> bool:
	if equipped_armor:
		if equipped_armor.strength_requirement > 0:
			if _actor and "ability_scores_component" in _actor and _actor.ability_scores_component:
				var str_score = _actor.ability_scores_component.get_strength_score()
				return str_score >= equipped_armor.strength_requirement
	
	return true

## Checks if the actor is proficient with their equipped armor and shield.
func is_proficient() -> bool:
	var current_armor_type = ArmorData.ArmorType.NONE
	if equipped_armor:
		current_armor_type = equipped_armor.type
	else:
		# Map legacy enum to ArmorData enum
		match armor_type:
			ArmorType.LIGHT: current_armor_type = ArmorData.ArmorType.LIGHT
			ArmorType.MEDIUM: current_armor_type = ArmorData.ArmorType.MEDIUM
			ArmorType.HEAVY: current_armor_type = ArmorData.ArmorType.HEAVY
	
	if not current_armor_type in proficiencies:
		return false
		
	if (equipped_shield or has_shield) and not ArmorData.ArmorType.SHIELD in proficiencies:
		return false
		
	return true

## Recalculates AC and updates related actor components.
func refresh() -> void:
	if not _actor: return
	
	# Recalculate and update the actor's armor_class property.
	if "armor_class" in _actor:
		_actor.armor_class = calculate_ac()
	
	# Update Speed Penalty on MovementComponent
	if "movement_component" in _actor and _actor.movement_component:
		if not meets_strength_requirement():
			# Reducing speed by approx 10ft (1/3 of standard 30ft)
			_actor.movement_component.armor_speed_multiplier = 0.7
		else:
			_actor.movement_component.armor_speed_multiplier = 1.0
