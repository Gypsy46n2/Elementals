class_name ProjectileComponent
extends Node

enum AttackPattern { SINGLE, SPREAD, LOB }

@export var projectile_speed: float = 14.0
@export var projectile_lifetime: float = 5.0
@export var projectile_max_range: float = 45.0
@export var projectile_charge_capacity: int = 5
@export var projectile_interval: float = 1.0
@export var trigger_range: float = 6.75
@export var projectile_scene: PackedScene
@export var lob_projectile_scene: PackedScene

var current_attack_pattern: AttackPattern = AttackPattern.SINGLE
var _actor: Node3D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func setup(actor: Node3D) -> void:
	_actor = actor
	_rng.randomize()

func cycle_attack_pattern() -> void:
	current_attack_pattern = (current_attack_pattern + 1) % AttackPattern.size() as AttackPattern
	_on_pattern_changed()

func prev_attack_pattern() -> void:
	current_attack_pattern = (current_attack_pattern - 1 + AttackPattern.size()) % AttackPattern.size() as AttackPattern
	_on_pattern_changed()

func _on_pattern_changed() -> void:
	print(_actor.name, " switched to ", AttackPattern.keys()[current_attack_pattern], " pattern.")
	if _actor.get("is_controlled") and _actor.get("_arena_grid"):
		_actor.get("_arena_grid").call("_update_ui")

func launch_projectile_at(target_position: Vector3, mana_comp: ManaComponent = null) -> void:
	if not _actor.get("_arena_grid"):
		return
	
	var wc = _actor.get("weapon_component")
	if wc and wc.has_method("update_attack_direction"):
		wc.update_attack_direction(target_position)
	
	match current_attack_pattern:
		AttackPattern.SINGLE:
			_launch_single_shot(target_position, mana_comp)
		AttackPattern.SPREAD:
			_launch_spread_shot(target_position, mana_comp)
		AttackPattern.LOB:
			_launch_lob_shot(target_position, mana_comp)

func _launch_single_shot(target_position: Vector3, mana_comp: ManaComponent) -> void:
	if not projectile_scene or (mana_comp and not mana_comp.use_mana(mana_comp.shot_mana_cost)):
		return
	_do_launch_projectile(target_position)

func _launch_spread_shot(target_position: Vector3, mana_comp: ManaComponent) -> void:
	var spread_cost = mana_comp.shot_mana_cost * 1.5 if mana_comp else 0.0
	if not projectile_scene or (mana_comp and not mana_comp.use_mana(spread_cost)):
		return
	
	var spawn_position = _actor.global_transform.origin
	var base_direction = (target_position - spawn_position).normalized()
	base_direction.y = 0
	if base_direction == Vector3.ZERO: base_direction = Vector3.FORWARD
	
	var angles = [-30, -15, 0, 15, 30]
	for angle in angles:
		var rad = deg_to_rad(angle)
		var direction = base_direction.rotated(Vector3.UP, rad)
		_do_launch_projectile_with_params(projectile_scene, spawn_position, direction, projectile_speed, 1, projectile_lifetime)

func _launch_lob_shot(target_position: Vector3, mana_comp: ManaComponent) -> void:
	var lob_cost = mana_comp.shot_mana_cost * 1.2 if mana_comp else 0.0
	var scene = lob_projectile_scene if lob_projectile_scene else projectile_scene
	if not scene or (mana_comp and not mana_comp.use_mana(lob_cost)):
		return
	
	var spawn_position = _actor.global_transform.origin
	var parent = _actor.get_parent() if _actor.get_parent() else _actor.get_tree().get_current_scene()
	
	for i in range(5):
		var projectile = scene.instantiate()
		parent.add_child(projectile)
		projectile.global_transform = Transform3D(Basis(), spawn_position)
		
		var offset = Vector3(_rng.randf_range(-1.0, 1.0), 0, _rng.randf_range(-1.0, 1.0))
		var cluster_target = target_position + offset
		
		if projectile.has_method("initialize_lob"):
			projectile.initialize_lob(_actor.get("_arena_grid"), _actor, spawn_position, cluster_target, projectile_speed * 0.8, 1, projectile_lifetime)
		elif projectile.has_method("initialize"):
			var dir = (cluster_target - spawn_position).normalized()
			projectile.initialize(_actor.get("_arena_grid"), _actor, spawn_position, 0.0, dir, projectile_speed, 1, projectile_lifetime)

func _do_launch_projectile(target_position: Vector3) -> void:
	var spawn_position = _actor.global_transform.origin
	var direction = (target_position - spawn_position).normalized()
	direction.y = 0
	if direction == Vector3.ZERO: direction = Vector3.FORWARD
	_do_launch_projectile_with_params(projectile_scene, spawn_position, direction, projectile_speed, projectile_charge_capacity, projectile_lifetime)

func _do_launch_projectile_with_params(scene: PackedScene, spawn_pos: Vector3, direction: Vector3, p_velocity: float, charges: int, p_lifetime: float) -> void:
	var projectile = scene.instantiate()
	var parent = _actor.get_parent() if _actor.get_parent() else _actor.get_tree().get_current_scene()
	parent.add_child(projectile)
	projectile.global_transform = Transform3D(Basis(), spawn_pos)
	if projectile.has_method("initialize"):
		projectile.initialize(_actor.get("_arena_grid"), _actor, spawn_pos, trigger_range, direction, p_velocity, charges, p_lifetime, projectile_max_range)

func launch_projectile_ai(mana_comp: ManaComponent) -> void:
	var patterns = [AttackPattern.SINGLE, AttackPattern.SPREAD, AttackPattern.LOB]
	current_attack_pattern = patterns[_rng.randi_range(0, patterns.size() - 1)]
	
	var heading = _rng.randf_range(0.0, TAU)
	var distance = _rng.randf_range(5.0, trigger_range)
	var target_position = _actor.global_transform.origin + Vector3(cos(heading), 0.0, sin(heading)) * distance
	
	launch_projectile_at(target_position, mana_comp)
