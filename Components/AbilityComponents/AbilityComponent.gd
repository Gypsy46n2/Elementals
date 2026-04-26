class_name AbilityComponent
extends Node

## AbilityComponent manages special maneuvers like Hide and Disengage.
## It handles a collection of AbilityAction objects.

var actor: Actor
var actions: Array[AbilityAction] = []

var is_hidden: bool:
	get:
		for action in actions:
			if "is_hidden" in action and action.is_hidden: return true
		return false
	set(v):
		execute_ability("hide", v)

var is_disengaged: bool:
	get:
		for action in actions:
			if "is_disengaged" in action and action.is_disengaged: return true
		return false
	set(v):
		execute_ability("disengage", v)

func setup(p_actor: Actor) -> void:
	actor = p_actor
	# For now, default to adding NimbleEscape if it's a goblin-related actor
	# In the future, this can be configured via exports or data.
	if actor is GoblinMinion or actor is GoblinActor:
		add_action(NimbleEscape.new(actor, self))
	elif actor is GoatActor:
		add_action(GoatCharge.new(actor, self))

func add_action(action: AbilityAction) -> void:
	actions.append(action)

func _process(delta: float) -> void:
	for action in actions:
		action.update(delta)

func execute_ability(type: String, value = null) -> void:
	if not actor or actor.is_stunned(): return
	for action in actions:
		action.execute(type, value)

func on_damage_taken() -> void:
	for action in actions:
		action.on_damage_taken()

func on_attack_performed() -> void:
	for action in actions:
		action.on_attack_performed()
