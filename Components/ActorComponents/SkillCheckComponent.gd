class_name SkillCheckComponent
extends Node

## Component responsible for performing skill checks and attack rolls.
## Decouples the dice rolling and success logic from individual actions.

var _owner_actor: Node

func setup(p_actor: Node) -> void:
	_owner_actor = p_actor

## Performs a standard d20 skill check.
## Returns a Dictionary with: success (bool), roll (float), total (float), is_critical (bool)
func perform_check(stat_value: float, difficulty: float, check_name: String = "Check", opponent: Node = null) -> Dictionary:
	var d20: int = randi() % 20 + 1
	var total: float = d20 + stat_value
	
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
			
		var stat_str: String = str(stat_value) if stat_value != int(stat_value) else str(int(stat_value))
		var total_str: String = str(result.total) if result.total != int(result.total) else str(int(result.total))
		var dc_str: String = str(difficulty) if difficulty != int(difficulty) else str(int(difficulty))

		print("[%s]%s %s Roll: %d + %s = %s (vs DC %s) | %s" % [
			_owner_actor.name, vs_text, check_name, result.roll, stat_str, total_str, dc_str, 
			"SUCCESS" if result.success else "FAILURE"
		])
	
	return result
