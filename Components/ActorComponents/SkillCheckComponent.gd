class_name SkillCheckComponent
extends Node

## Component responsible for performing skill checks and attack rolls.
## Decouples the dice rolling and success logic from individual actions.

var _owner_actor: Node

func setup(p_actor: Node) -> void:
	_owner_actor = p_actor

## Performs a standard d20 skill check.
## Optional params allow detailed logging: stat_value (e.g. WIS), distance_mod, tiles
## Returns a Dictionary with: success (bool), roll (float), total (float), is_critical (bool)
func perform_check(total_mod: float, difficulty: float, check_name: String = "Check", opponent: Node = null, stat_value: float = 0.0, distance_mod: float = 0.0, tiles: int = 0) -> Dictionary:
	var d20: int = randi() % 20 + 1
	var total: float = d20 + stat_value + distance_mod
	
	# Natural 20 is typically an automatic success in these systems
	var success: bool = (d20 == 20) or (total >= difficulty)
	
	var result: Dictionary = {
		"success": success,
		"roll": d20,
		"total": total,
		"is_critical": d20 == 20
	}
	
	if _owner_actor:
		var vs_text: String = ""
		if opponent:
			vs_text = " vs [%s]" % opponent.name
		
		var dist_sign: String = "+" if distance_mod >= 0 else ""
		var dist_bonus_str: String = dist_sign + str(int(distance_mod))
		
		print("[%s]%s %s: d20=%d + WIS=%d + Dist=%s (%d tiles) = %d vs DC %d | %s" % [
			_owner_actor.name,
			vs_text,
			check_name,
			d20,
			int(stat_value),
			dist_bonus_str,
			tiles,
			int(total),
			int(difficulty),
			"SUCCESS" if success else "FAILURE"
		])
	
	return result