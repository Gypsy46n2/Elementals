class_name GoblinDecisionComponent
extends ActorDecisionComponent

## Specialized decision component for Goblins.
## Goblins use Nimble Escape to hide or disengage.

var _nimble_escape_timer: float = 0.0
const NIMBLE_ESCAPE_COOLDOWN: float = 4.0

func _ready() -> void:
	super._ready()
	_nimble_escape_timer = randf_range(0, NIMBLE_ESCAPE_COOLDOWN)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	
	if actor and not is_controlled:
		_update_nimble_escape(delta)

func _update_nimble_escape(delta: float) -> void:
	if _nimble_escape_timer > 0:
		_nimble_escape_timer -= delta
		return
	
	# Goblin logic: If an enemy is nearby, maybe disengage.
	# If far away, maybe hide.
	
	var arena = actor._arena_grid
	if not arena: return
	
	var nearest_enemy: Actor = null
	var min_dist = 100.0
	
	for a in arena.actors:
		if a == actor: continue
		if a is Actor:
			var d = actor.global_position.distance_to(a.global_position)
			if d < min_dist:
				min_dist = d
				nearest_enemy = a
	
	if nearest_enemy:
		if min_dist < 4.0:
			# Too close! Disengage.
			if actor.has_method("take_nimble_escape_action"):
				actor.take_nimble_escape_action("disengage")
				_nimble_escape_timer = NIMBLE_ESCAPE_COOLDOWN
		elif min_dist > 8.0 and not (actor as GoblinMinion).is_hidden:
			# Far enough to hide.
			if actor.has_method("take_nimble_escape_action"):
				actor.take_nimble_escape_action("hide")
				_nimble_escape_timer = NIMBLE_ESCAPE_COOLDOWN

func _handle_ai_logic(delta: float) -> void:
	# Standard AI movement logic from parent
	super._handle_ai_logic(delta)
	
	# Goblins also attack if they have daggers
	if not is_controlled and actor:
		_check_for_attack()

func _check_for_attack() -> void:
	if actor.is_stunned(): return
	
	var arena = actor._arena_grid
	if not arena: return
	
	# Try to find a target (Friendlies)
	var target: Actor = null
	for a in arena.actors:
		if a == actor: continue
		if a is Actor and a.is_friendly:
			target = a
			break
	
	if target:
		var d = actor.global_position.distance_to(target.global_position)
		if d < 12.0:
			# Aim at target
			actor.launch_projectile_at(target.global_position)
