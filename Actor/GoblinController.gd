class_name GoblinController
extends ActorAIController

## Specialized controller for Goblins.
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
		if not is_instance_valid(a): continue
		if a == actor: continue
		if a is Actor and actor.is_enemy(a):
			var d = actor.global_position.distance_to(a.global_position)
			if d < min_dist:
				min_dist = d
				nearest_enemy = a
	
	if nearest_enemy:
		if min_dist < 4.0:
			# Too close! Disengage.
			if actor.ability_component:
				actor.ability_component.execute_ability("disengage")
				_nimble_escape_timer = NIMBLE_ESCAPE_COOLDOWN
		elif min_dist > 8.0 and actor.ability_component and not actor.ability_component.is_hidden:
			# Far enough to hide.
			if actor.ability_component:
				actor.ability_component.execute_ability("hide")
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
	
	# Try to find a target (Enemies)
	var target: Actor = null
	for a in arena.actors:
		if not is_instance_valid(a): continue
		if a == actor: continue
		if a is Actor and actor.is_enemy(a):
			target = a
			break
	
	if target:
		var d = actor.global_position.distance_to(target.global_position)
		var attack_distance: float = 12.0
		var should_throw: bool = false
		if actor.weapon_component and actor.weapon_component.weapon_data:
			var wd: WeaponData = actor.weapon_component.weapon_data
			if not wd.is_ranged and not wd.is_thrown:
				attack_distance = wd.reach * 2.0
			elif wd.is_thrown:
				if actor.weapon_component.current_ammo > 1:
					should_throw = true
				else:
					attack_distance = wd.reach * 2.0
		
		if d <= attack_distance:
			# Aim at target
			if actor.weapon_component:
				if should_throw:
					actor.weapon_component.throw_weapon_at(target.global_position)
				else:
					actor.weapon_component.launch_projectile_at(target.global_position)
