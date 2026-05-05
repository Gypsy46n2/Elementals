class_name GoatCharge
extends AbilityAction

## Handles the goat's signature headbutt charge attack.
## Manages charge state, physics, collision detection, and damage.

var _is_charging: bool = false
var _charge_direction: Vector3 = Vector3.ZERO
var _charge_remaining_dist: float = 0.0
var _charge_cooldown_timer: float = 0.0

var is_charging: bool:
	get: return _is_charging

func _init(p_actor: Actor, p_component: Node) -> void:
	super(p_actor, p_component)
	ability_name = "Headbutt Charge"
	ability_description = "Charge forward with great speed, headbutting anything in your path. Deals damage and knockback."
	ability_usage = "Left Click while controlled."
	ability_icon = preload("res://assets/generated/thwak_popup_frame_0_1774916398.png")

func execute(type: String, value = null) -> void:
	if type == "charge":
		var target_pos: Vector3 = value if value is Vector3 else Vector3.ZERO
		_start_charge(target_pos)

func update(delta: float) -> void:
	if _charge_cooldown_timer > 0:
		_charge_cooldown_timer -= delta

func process_physics(delta: float) -> void:
	if not actor:
		return

	if actor.is_stunned():
		_is_charging = false
		actor.velocity = Vector3.ZERO
		return

	if _is_charging:
		_handle_charge_logic(delta)

func process_collisions() -> void:
	if not actor or not _is_charging:
		return
	_process_charge_collisions()

func _start_charge(target_pos: Vector3) -> void:
	if _is_charging or _charge_cooldown_timer > 0 or actor.is_stunned():
		return

	var diff := target_pos - actor.global_position
	diff.y = 0

	if diff.length() > 0.1:
		var dir := diff.normalized()
		_is_charging = true
		_charge_direction = dir

		var multiplier: float = actor.terrain_speed_modifier_component.get_speed_multiplier()

		_charge_remaining_dist = actor.charge_distance * multiplier
		_charge_cooldown_timer = actor.charge_cooldown

		actor.velocity = dir * (actor.charge_speed * multiplier)
		_play_swoosh()

		var tile_interaction = actor.get("tile_interaction_component")
		var ground_tile = tile_interaction.get_ground_tile() if tile_interaction else null
		var arena_grid = actor.get("_arena_grid")
		if ground_tile and arena_grid:
			arena_grid.apply_element_to_tile(ground_tile, "headbutt")

func _handle_charge_logic(delta: float) -> void:
	var multiplier: float = actor.terrain_speed_modifier_component.get_speed_multiplier()

	var current_charge_speed: float = actor.charge_speed * multiplier

	actor.velocity.x = _charge_direction.x * current_charge_speed
	actor.velocity.z = _charge_direction.z * current_charge_speed

	var horizontal_vel := Vector3(actor.velocity.x, 0, actor.velocity.z)

	if horizontal_vel.length() < current_charge_speed * 0.5 and current_charge_speed > 0.1:
		_is_charging = false
		actor.velocity = Vector3.ZERO
		return

	_charge_remaining_dist -= horizontal_vel.length() * delta
	if _charge_remaining_dist <= 0:
		_is_charging = false
		actor.velocity = Vector3.ZERO

func _process_charge_collisions() -> void:
	for i in actor.get_slide_collision_count():
		var collision := actor.get_slide_collision(i)
		var collider := collision.get_collider()
		if collider is Actor and collider != actor:
			_handle_headbutt_hit(collider, collision.get_position())
			_is_charging = false
			actor.velocity = Vector3.ZERO
			break
		else:
			var arena_grid = actor.get("_arena_grid")
			if arena_grid and (collider == arena_grid.physics or collider.name == "FloorStaticBody"):
				var tile_data = arena_grid.get_tile_data_at_world_position(collision.get_position())
				if tile_data:
					if arena_grid.apply_element_to_tile(tile_data, "headbutt"):
						actor._play_whack()
						actor._show_thwak_visual(collision.get_position())

					if tile_data.tile_type == TileConstants.Type.STONE:
						_is_charging = false
						actor.velocity = Vector3.ZERO
						break
			else:
				var potential_feature := collider
				while potential_feature and not potential_feature.has_method("apply_element"):
					potential_feature = potential_feature.get_parent()
					if potential_feature == actor.get_tree().root:
						potential_feature = null
						break

				if potential_feature and potential_feature.has_method("apply_element"):
					if potential_feature.apply_element("headbutt", actor.velocity.normalized()):
						actor._play_whack()
						actor._show_thwak_visual(collision.get_position())
						_is_charging = false
						actor.velocity = Vector3.ZERO
						break

func _handle_headbutt_hit(target: Actor, hit_pos: Vector3) -> void:
	var damage := 1
	var knockback_strength := 12.0

	var ability_scores = actor.get("ability_scores_component")
	var goat_data = actor.get("goat_data")
	if goat_data and ability_scores:
		damage = int(max(1, ability_scores.strength))
		knockback_strength *= ability_scores.strength

	target.take_damage(damage, "normal", (target.global_position - actor.global_position).normalized())
	target.stun(0.5)
	actor._show_thwak_visual(hit_pos)
	actor._play_whack()

	var movement = target.get("movement_component")
	if movement:
		var knockback_dir := (target.global_position - actor.global_position).normalized()
		knockback_dir.y = 0.5
		movement.apply_external_force(knockback_dir * knockback_strength)

func _play_swoosh() -> void:
	var swoosh: AudioStreamPlayer3D = actor.get_node_or_null("SwooshPlayer")
	if swoosh and swoosh.stream:
		swoosh.play()
