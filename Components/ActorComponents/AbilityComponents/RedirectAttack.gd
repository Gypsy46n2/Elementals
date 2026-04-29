class_name RedirectAttack
extends AbilityAction

## Redirect Attack: Triggered when a creature the goblin can see makes an attack roll against it.
## Response: the goblin chooses a nearby Small/Medium ally, safely swaps places with it,
## and the ally becomes the new target. © 2026 Micheal Chapin

const MAX_SWAP_DISTANCE: float = 4.0
const SAFE_Y_OFFSET: float = 0.05
const REDIRECT_COOLDOWN_MSEC: int = 450
const INDICATOR_TEXTURE_PATH: String = "res://assets/generated/red_exclamation_mark_frame_0_1777252117.png"

var _last_redirect_msec: int = -100000

func _init(p_actor: Actor, p_component: Node) -> void:
	super(p_actor, p_component)
	ability_name = "Redirect Attack"
	ability_description = "Swap places with a nearby small/medium ally when attacked."

func on_targeted_by_attack(attacker: Actor) -> Actor:
	if not is_instance_valid(actor):
		return actor
	if actor.is_dead:
		return actor
	if not _is_safe_vector(actor.global_position):
		return actor

	var now_msec: int = Time.get_ticks_msec()
	if now_msec - _last_redirect_msec < REDIRECT_COOLDOWN_MSEC:
		return actor

	var valid_allies: Array[Actor] = _get_valid_allies()
	if valid_allies.is_empty():
		return actor

	var chosen_ally: Actor = _choose_nearest_ally(valid_allies)
	if not is_instance_valid(chosen_ally):
		return actor

	_last_redirect_msec = now_msec
	_show_indicators(valid_allies)
	_perform_swap(chosen_ally)
	_log_swap(attacker, chosen_ally)

	return chosen_ally

func _get_valid_allies() -> Array[Actor]:
	var result: Array[Actor] = []
	if not is_instance_valid(actor) or not actor._arena_grid:
		return result

	for other in actor._arena_grid.actors:
		var other_actor: Actor = other as Actor
		if not is_instance_valid(other_actor) or other_actor == actor:
			continue
		if other_actor.is_dead:
			continue
		if not _is_safe_vector(other_actor.global_position):
			continue
		if not actor.is_ally(other_actor):
			continue

		# Size check: only Small or Medium allies can be redirected into the attack.
		if other_actor.actor_size == Actor.Size.LARGE:
			continue

		var flat_distance: float = _flat_distance(actor.global_position, other_actor.global_position)
		if flat_distance <= MAX_SWAP_DISTANCE:
			result.append(other_actor)

	return result

func _choose_nearest_ally(valid_allies: Array[Actor]) -> Actor:
	var best: Actor = null
	var best_distance: float = INF

	for other_actor in valid_allies:
		if not is_instance_valid(other_actor):
			continue
		var dist: float = _flat_distance(actor.global_position, other_actor.global_position)
		if dist < best_distance:
			best_distance = dist
			best = other_actor

	return best

func _flat_distance(a: Vector3, b: Vector3) -> float:
	var a2: Vector2 = Vector2(a.x, a.z)
	var b2: Vector2 = Vector2(b.x, b.z)
	return a2.distance_to(b2)

func _show_indicators(targets: Array[Actor]) -> void:
	var tex: Texture2D = load(INDICATOR_TEXTURE_PATH) as Texture2D
	if not tex:
		return

	for target in targets:
		if is_instance_valid(target):
			_create_indicator(target, tex)

func _create_indicator(target: Actor, tex: Texture2D) -> void:
	var sprite: Sprite3D = Sprite3D.new()
	sprite.texture = tex
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.no_depth_test = true
	sprite.pixel_size = 0.01
	sprite.fixed_size = true

	target.add_child(sprite)
	sprite.position = Vector3(0, 1.8, 0)

	var tween: Tween = sprite.create_tween()
	tween.tween_property(sprite, "scale", Vector3(1.2, 1.2, 1.2), 0.1)
	tween.tween_property(sprite, "scale", Vector3(1.0, 1.0, 1.0), 0.1)
	tween.tween_interval(0.6)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.2)
	tween.tween_callback(sprite.queue_free)

func _perform_swap(ally: Actor) -> void:
	if not is_instance_valid(actor) or not is_instance_valid(ally):
		return

	var actor_start: Vector3 = actor.global_position
	var ally_start: Vector3 = ally.global_position
	var actor_target: Vector3 = _get_safe_swap_position(ally_start)
	var ally_target: Vector3 = _get_safe_swap_position(actor_start)

	if not _is_safe_vector(actor_target) or not _is_safe_vector(ally_target):
		return

	_show_swap_effect(actor_start)
	_show_swap_effect(ally_start)
	_play_swoosh()

	_freeze_actor_for_swap(actor)
	_freeze_actor_for_swap(ally)

	actor.global_position = actor_target
	ally.global_position = ally_target

	_freeze_actor_for_swap(actor)
	_freeze_actor_for_swap(ally)
	_reset_ai_target(actor)
	_reset_ai_target(ally)

	actor.force_update_transform()
	ally.force_update_transform()

func _freeze_actor_for_swap(a: Actor) -> void:
	if not is_instance_valid(a):
		return

	a.velocity = Vector3.ZERO

	if a.movement_component:
		a.movement_component.external_velocity = Vector3.ZERO
		a.movement_component.stop(1.0 / 60.0)

func _get_safe_swap_position(raw_pos: Vector3) -> Vector3:
	var safe_pos: Vector3 = raw_pos
	safe_pos.y = _get_safe_surface_y(raw_pos) + SAFE_Y_OFFSET
	return safe_pos

func _get_safe_surface_y(pos: Vector3) -> float:
	var fallback_y: float = pos.y
	if not _is_safe_number(fallback_y) or fallback_y > 6.0 or fallback_y < -4.0:
		fallback_y = 0.0

	if not is_instance_valid(actor) or not actor._arena_grid:
		return fallback_y

	var arena: Object = actor._arena_grid
	if not arena.has_method("get_tile_at_world_position") or not arena.has_method("_get_tile_surface_y"):
		return fallback_y

	var tile: Object = arena.call("get_tile_at_world_position", pos) as Object
	if not tile:
		return fallback_y

	var surface_value: Variant = arena.call("_get_tile_surface_y", tile)
	if typeof(surface_value) == TYPE_FLOAT or typeof(surface_value) == TYPE_INT:
		return float(surface_value)

	return fallback_y

func _reset_ai_target(a: Actor) -> void:
	if not is_instance_valid(a):
		return

	if a.controller is ActorAIController:
		var ai: ActorAIController = a.controller as ActorAIController
		ai._movement_target = a.global_position
		ai._previous_tile = null

func _play_swoosh() -> void:
	if not is_instance_valid(actor):
		return
	var swoosh: AudioStreamPlayer3D = actor.get_node_or_null("SwooshPlayer") as AudioStreamPlayer3D
	if swoosh:
		swoosh.play()

func _show_swap_effect(_pos: Vector3) -> void:
	# Placeholder for future visual effects.
	pass

func _log_swap(attacker: Actor, ally: Actor) -> void:
	var actor_n: String = _get_clean_name(actor)
	var ally_n: String = _get_clean_name(ally)
	var attacker_n: String = "unknown"
	if is_instance_valid(attacker):
		attacker_n = _get_clean_name(attacker)

	print("[%s] safely switched places with [%s] after being attacked by [%s]" % [actor_n, ally_n, attacker_n])

func _get_clean_name(n: Node) -> String:
	if not is_instance_valid(n):
		return "unknown"
	return n.name.trim_prefix("@").split("@")[0]

func _is_safe_vector(v: Vector3) -> bool:
	return _is_safe_number(v.x) and _is_safe_number(v.y) and _is_safe_number(v.z)

func _is_safe_number(value: float) -> bool:
	return value == value and abs(value) < 100000.0
