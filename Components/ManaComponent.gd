class_name ManaComponent
extends Node

signal mana_changed(new_mana: float, max_mana: float)

@export var max_mana: float = 100.0
@export var mana_regen_rate: float = 20.0
@export var shot_mana_cost: float = 20.0

var current_mana: float = 100.0:
	set(value):
		var old_int = int(current_mana)
		current_mana = value
		if int(current_mana) != old_int:
			mana_changed.emit(current_mana, max_mana)

var _mana_particles: Array[Sprite3D] = []
var _mana_particles_container: Node3D
var _mana_phase: float = 0.0
var _mana_texture: Texture2D
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _actor: Node3D

func setup(actor: Node3D, texture: Texture2D) -> void:
	_actor = actor
	_mana_texture = texture
	_rng.randomize()
	_mana_phase = _rng.randf_range(0, 100)
	current_mana = max_mana
	_setup_mana_visuals()

func _setup_mana_visuals() -> void:
	_mana_particles_container = Node3D.new()
	_mana_particles_container.name = "ManaParticlesContainer"
	_actor.add_child(_mana_particles_container)
	
	var body = _actor.get_node_or_null("Body")
	if body:
		_mana_particles_container.position.y = body.position.y

func update_mana_visuals(delta: float) -> void:
	var texture = _mana_texture
	if not texture:
		for p in _mana_particles:
			if is_instance_valid(p): p.queue_free()
		_mana_particles.clear()
		return
		
	var charges = 0
	if shot_mana_cost > 0:
		charges = int(current_mana / 5)
	
	while _mana_particles.size() < charges:
		var sprite = Sprite3D.new()
		sprite.texture = texture
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.03
		sprite.render_priority = 5
		sprite.transparent = true
		if "shading_mode" in sprite:
			sprite.set("shading_mode", BaseMaterial3D.SHADING_MODE_UNSHADED)
		
		var rand_axis = Vector3(_rng.randf_range(-1,1), _rng.randf_range(-1,1), _rng.randf_range(-1,1)).normalized()
		if rand_axis == Vector3.ZERO: rand_axis = Vector3.UP
		var orbit_basis = Basis(rand_axis, _rng.randf_range(0, TAU))
		
		sprite.set_meta("orbit_rotation", orbit_basis)
		sprite.set_meta("phase_offset", _rng.randf_range(0, TAU))
		sprite.set_meta("speed_mult", _rng.randf_range(0.3, 0.6))
		
		_mana_particles_container.add_child(sprite)
		_mana_particles.append(sprite)
		
	while _mana_particles.size() > charges:
		var sprite = _mana_particles.pop_back()
		if is_instance_valid(sprite):
			sprite.queue_free()
		
	_mana_phase += delta
	var orbit_radius = 1.1
	for i in range(_mana_particles.size()):
		var sprite = _mana_particles[i]
		if not is_instance_valid(sprite): continue
		
		var phase = _mana_phase * sprite.get_meta("speed_mult") + sprite.get_meta("phase_offset")
		var lx = sin(phase) * orbit_radius
		var ly = sin(2.0 * phase) * (orbit_radius * 0.5)
		var lz = cos(phase) * (orbit_radius * 0.2)
		
		var orbit_rot = sprite.get_meta("orbit_rotation") as Basis
		sprite.position = orbit_rot * Vector3(lx, ly, lz)
		
		var s = 0.8 + sin(phase * 1.5) * 0.15
		sprite.scale = Vector3.ONE * s

func regenerate_mana(delta: float, multiplier: float = 1.0) -> void:
	current_mana = min(current_mana + mana_regen_rate * multiplier * delta, max_mana)

func use_mana(amount: float) -> bool:
	if current_mana >= amount:
		current_mana -= amount
		return true
	return false
