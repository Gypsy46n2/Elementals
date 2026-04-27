class_name RedirectAttack
extends AbilityAction

## Redirect Attack: Triggered when a creature the goblin can see makes an attack roll against it.
## Response: The goblin chooses a Small or Medium ally within 5 feet (3.0m).
## The goblin and that ally swap places, and the ally becomes the target of the attack instead.

const MAX_SWAP_DISTANCE: float = 10.0 # 5 feet is ~3m, but grid math can be fuzzy, using 4.0 to be safe
const INDICATOR_TEXTURE_PATH: String = "res://assets/generated/red_exclamation_mark_frame_0_1777252117.png"

func _init(p_actor: Actor, p_component: Node) -> void:
	super(p_actor, p_component)
	ability_name = "Redirect Attack"
	ability_description = "Swap places with a nearby small/medium ally when attacked."

func on_targeted_by_attack(attacker: Actor) -> Actor:
	if not actor or not attacker: 
		return actor
	
	var valid_allies: Array[Actor] = _get_valid_allies()
	if valid_allies.is_empty():
		return actor
	
	# For now, we just pick the first one (as per original logic)
	var chosen_ally: Actor = valid_allies[0]
	
	_show_indicators(valid_allies)
	_perform_swap(chosen_ally)
	
	_log_swap(attacker, chosen_ally)
	
	return chosen_ally

func _get_valid_allies() -> Array[Actor]:
	var result: Array[Actor] = []
	if not actor or not actor._arena_grid:
		return result
		
	for other in actor._arena_grid.actors:
		var other_actor := other as Actor
		if not other_actor or other_actor == actor:
			continue
		
		if not actor.is_ally(other_actor):
			continue
		
		# Size check: Small or Medium
		if other_actor.actor_size == Actor.Size.LARGE:
			continue
			
		var dist: float = actor.global_position.distance_to(other_actor.global_position)
		if dist <= MAX_SWAP_DISTANCE:
			result.append(other_actor)
			
	return result

func _show_indicators(targets: Array[Actor]) -> void:
	var tex: Texture2D = load(INDICATOR_TEXTURE_PATH) as Texture2D
	if not tex:
		return
		
	for target in targets:
		_create_indicator(target, tex)

func _create_indicator(target: Actor, tex: Texture2D) -> void:
	var sprite := Sprite3D.new()
	sprite.texture = tex
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.pixel_size = 0.01
	sprite.fixed_size = true
	
	target.add_child(sprite)
	sprite.position = Vector3(0, 1.8, 0)
	
	var tween := sprite.create_tween()
	tween.tween_property(sprite, "scale", Vector3(1.2, 1.2, 1.2), 0.1)
	tween.tween_property(sprite, "scale", Vector3(1.0, 1.0, 1.0), 0.1)
	tween.tween_interval(0.6)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.tween_callback(sprite.queue_free)

func _perform_swap(ally: Actor) -> void:
	var actor_pos: Vector3 = actor.global_position
	var ally_pos: Vector3 = ally.global_position
	var nudge: Vector3 = Vector3(0, 0.5, 0) # Small lift to prevent floor clipping
	
	_show_swap_effect(actor_pos)
	_show_swap_effect(ally_pos)
	
	_play_swoosh()
	
	# Stop movements
	_stop_actor(actor)
	_stop_actor(ally)
	
	# Swap positions
	actor.global_position = ally_pos + nudge
	ally.global_position = actor_pos + nudge
	
	# Reset AI targets
	_reset_ai_target(actor)
	_reset_ai_target(ally)
	
	actor.force_update_transform()
	ally.force_update_transform()

func _stop_actor(a: Actor) -> void:
	a.velocity = Vector3.ZERO
	if a.movement_component:
		a.movement_component.stop()

func _reset_ai_target(a: Actor) -> void:
	if a.controller is ActorAIController:
		a.controller._movement_target = a.global_position

func _play_swoosh() -> void:
	var swoosh: AudioStreamPlayer3D = actor.get_node_or_null("SwooshPlayer")
	if swoosh:
		swoosh.play()

func _show_swap_effect(_pos: Vector3) -> void:
	# Placeholder for future visual effects
	# Could trigger particles or a flash here
	pass

func _log_swap(attacker: Actor, ally: Actor) -> void:
	var actor_n: String = _get_clean_name(actor)
	var ally_n: String = _get_clean_name(ally)
	var attacker_n: String = _get_clean_name(attacker)
	
	print("[%s] switched places with [%s] after being attacked by [%s]" % [actor_n, ally_n, attacker_n])

func _get_clean_name(n: Node) -> String:
	return n.name.trim_prefix("@").split("@")[0]
