class_name SkillCheckComponent
extends Node

## Component responsible for performing skill checks and attack rolls.
## Decouples the dice rolling and success logic from individual actions.

var _owner_actor: Node

func setup(p_actor: Node) -> void:
	_owner_actor = p_actor

## Performs a standard d20 skill check.
## Returns a Dictionary with: success (bool), roll (int), total (float), is_critical (bool)
func perform_check(stat_value: float, difficulty: int, check_name: String = "Check") -> Dictionary:
	var d20: int = randi() % 20 + 1
	var total: float = d20 + stat_value
	
	# Natural 20 is typically an automatic success in these systems
	var success: bool = (d20 == 20) or (total >= difficulty)
	
	var result = {
		"success": success,
		"roll": d20,
		"total": total,
		"is_critical": d20 == 20
	}
	
	if _owner_actor:
		print("[%s] %s Roll: %d + %.1f = %.1f (vs DC %d) | %s" % [
			_owner_actor.name, check_name, result.roll, stat_value, result.total, difficulty, 
			"SUCCESS" if result.success else "FAILURE"
		])
	
	return result
