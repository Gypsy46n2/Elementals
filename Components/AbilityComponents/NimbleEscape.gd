class_name NimbleEscape
extends AbilityAction

## Nimble Escape allows Goblins (and others) to Hide and Disengage efficiently.

var is_hidden: bool = false
var is_disengaged: bool = false
var _is_hiding_intent: bool = false
var _hide_check_timer: float = 0.0
const HIDE_CHECK_INTERVAL: float = 3.0

func _init(p_actor: Actor, p_component: Node) -> void:
	super(p_actor, p_component)
	ability_name = "Nimble Escape"
	ability_description = "A versatile maneuver allowing the user to Disengage or Hide."
	ability_usage = "Tap SHIFT to Disengage (Dash away). Hold SHIFT to Hide (Stealth)."

func execute(type: String, value = null) -> void:
	match type:
		"hide":
			var active: bool = value if value is bool else !_is_hiding_intent
			_set_hide_active(active)
		"disengage":
			var direction: Vector3 = value if value is Vector3 else Vector3.ZERO
			_disengage(direction)

func update(delta: float) -> void:
	if _is_hiding_intent:
		if actor and actor.velocity.length() > 0.1:
			_hide_check_timer += delta
			if _hide_check_timer >= HIDE_CHECK_INTERVAL:
				_hide_check_timer = 0.0
				_perform_stealth_check()
		elif actor and actor.velocity.length() < 0.1:
			_update_visuals()

func on_damage_taken() -> void:
	if _is_hiding_intent:
		_set_hide_active(false)

func on_attack_performed() -> void:
	if _is_hiding_intent:
		_set_hide_active(false)

func _set_hide_active(active: bool) -> void:
	if _is_hiding_intent == active: return
	_is_hiding_intent = active
	is_hidden = active # Initially hidden
	_hide_check_timer = 0.0
	
	if actor:
		if _is_hiding_intent:
			print(actor.name, " is now HIDDEN")
			if actor.movement_component:
				actor.movement_component.speed_multiplier = 0.5
			# Initial check when hiding
			_perform_stealth_check()
		else:
			print(actor.name, " is now REVEALED")
			is_hidden = false
			if actor.movement_component:
				actor.movement_component.speed_multiplier = 1.0
			if actor._body:
				actor._body.modulate.a = 1.0
			if actor.weapon_component:
				actor.weapon_component.set_weapon_modulation(1.0)

func _disengage(custom_direction: Vector3 = Vector3.ZERO) -> void:
	print(actor.name, " uses DISENGAGE")
	is_disengaged = true
	# Invulnerability frames for a short duration
	var timer = actor.get_tree().create_timer(0.5)
	timer.timeout.connect(func(): is_disengaged = false)
	
	if actor and actor.movement_component:
		var dash_dir: Vector3 = custom_direction
		
		# If no direction provided, find nearest enemy and dash away
		if dash_dir == Vector3.ZERO:
			var arena = actor._arena_grid
			var nearest_enemy: Actor = null
			var min_dist = 100.0
			if arena:
				for a in arena.actors:
					if a == actor: continue
					if a is Actor:
						var d = actor.global_position.distance_to(a.global_position)
						if d < min_dist:
							min_dist = d
							nearest_enemy = a
			
			if nearest_enemy:
				dash_dir = (actor.global_position - nearest_enemy.global_position).normalized()
				dash_dir.y = 0
			else:
				# Fallback to current velocity or random
				dash_dir = -actor.velocity.normalized() if actor.velocity.length() > 0.1 else Vector3(randf_range(-1,1), 0, randf_range(-1,1)).normalized()
		
		actor.movement_component.apply_external_force(dash_dir * 12.0)

func _perform_stealth_check() -> void:
	if not actor or not actor._arena_grid: return
	
	var still_hidden: bool = true
	var min_margin: float = 999.0
	
	for actor_node in actor._arena_grid.actors:
		if actor_node == actor: continue
		if actor_node is Actor:
			var dex_val: float = actor.ability_scores_component.dexterity
			var wis_val: float = actor_node.ability_scores_component.wisdom
			var dc: float = 10.0 + wis_val
			
			var result: Dictionary = actor.skill_check_component.perform_check(dex_val, dc, "Stealth Check", actor_node)
			if not result.success:
				still_hidden = false
				break
			else:
				var margin: float = result.total - dc
				if margin < min_margin:
					min_margin = margin
	
	is_hidden = still_hidden
	_update_visuals(min_margin)

func _update_visuals(margin: float = 0.0) -> void:
	if not actor: return
	
	var alpha: float = 1.0
	
	if not _is_hiding_intent:
		alpha = 1.0
	elif actor.is_controlled:
		# Player is always modulated while attempting to hide
		alpha = 0.2 if is_hidden else 0.5
	else:
		# NPCs are only modulated if hidden
		if is_hidden:
			alpha = clamp(0.5 - (margin * 0.1), 0.1, 0.5)
		else:
			alpha = 1.0

	# Apply modulation to actor body recursively
	if actor._body:
		_apply_modulation_recursive(actor._body, alpha)
		
	# Apply to weapon
	if actor.weapon_component:
		actor.weapon_component.set_weapon_modulation(alpha)

func _apply_modulation_recursive(node: Node, alpha: float) -> void:
	if node is SpriteBase3D:
		node.modulate.a = alpha
	elif node is GeometryInstance3D:
		node.transparency = 1.0 - alpha
	
	for child in node.get_children():
		_apply_modulation_recursive(child, alpha)
