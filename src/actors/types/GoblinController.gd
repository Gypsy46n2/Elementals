class_name GoblinController
extends ActorAIController

## Specialized controller for Goblins.
## Goblins use Nimble Escape to hide or disengage.

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if actor and not is_controlled:
		_update_nimble_escape()

func _update_nimble_escape() -> void:
	# Goblin logic: If an enemy is nearby, maybe disengage.
	# If far away, maybe hide.
	
	if not actor._arena_grid: return
	
	var nearest_enemy: Node3D = _find_nearest_enemy()
	
	if nearest_enemy:
		var min_dist: float = actor.global_position.distance_to(nearest_enemy.global_position)
		if min_dist < 4.0:
			# Too close! Disengage.
			if actor.ability_component:
				actor.ability_component.execute_ability("disengage")
		elif min_dist > 8.0 and actor.ability_component and not actor.ability_component.is_hidden:
			# Far enough to hide.
			actor.ability_component.execute_ability("hide")

func _handle_ai_logic(delta: float) -> void:
	# Standard AI movement logic from parent
	super._handle_ai_logic(delta)
