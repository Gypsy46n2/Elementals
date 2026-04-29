class_name ActorParticleComponent
extends Node

## Component that handles particle effects for an Actor.
## Provides utility methods for setting up GPU particles and manages common actor effects.

static func setup_gpu_particles(particles: GPUParticles3D, params: Dictionary) -> void:
	if not particles: return
	
	particles.emitting = params.get("emitting", true)
	particles.amount = params.get("amount", 20)
	particles.lifetime = params.get("lifetime", 1.0)
	particles.local_coords = params.get("local_coords", true)
	
	var material = particles.process_material as ParticleProcessMaterial
	if not material:
		material = ParticleProcessMaterial.new()
		particles.process_material = material
		
	material.direction = params.get("direction", Vector3.UP)
	material.spread = params.get("spread", 45.0)
	material.initial_velocity_min = params.get("velocity_min", 1.0)
	material.initial_velocity_max = params.get("velocity_max", 2.0)
	material.gravity = params.get("gravity", Vector3.ZERO)
	material.scale_min = params.get("scale_min", 0.1)
	material.scale_max = params.get("scale_max", 0.2)
	material.color = params.get("color", Color.WHITE)
	
	if params.has("emission_shape"): 
		material.emission_shape = params["emission_shape"]
	if params.has("emission_box_extents"): 
		material.emission_box_extents = params["emission_box_extents"]
	if params.has("damping_min"): 
		material.damping_min = params["damping_min"]
	if params.has("damping_max"): 
		material.damping_max = params["damping_max"]

	if not particles.draw_pass_1:
		var pass_mesh: QuadMesh = QuadMesh.new()
		var p_mat: StandardMaterial3D = StandardMaterial3D.new()
		p_mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		p_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		p_mat.vertex_color_use_as_albedo = true
		p_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		
		if params.has("texture"):
			var tex = params["texture"]
			if tex is String: 
				p_mat.albedo_texture = load(tex)
			elif tex is Texture2D: 
				p_mat.albedo_texture = tex
				
		pass_mesh.material = p_mat
		particles.draw_pass_1 = pass_mesh

func setup(p_actor: Actor) -> void:
	actor = p_actor
	_rng.randomize()
	_mana_phase = _rng.randf_range(0, 100)

var actor: Actor
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

# TODO(Optimization): Throttle mana particle updates or use GPU particles for animations to reduce CPU (~1% CPU per actor)
func _process(delta: float) -> void:
	if actor and actor.mana_component:
		update_mana_visuals(delta, actor.mana_component.current_mana, actor.mana_component.shot_mana_cost)

# Mana Particle Visuals (Sprite3D based)
var mana_particles: Array[Sprite3D] = []
var mana_particles_container: Node3D
var _mana_phase: float = 0.0
var _mana_texture: Texture2D

func setup_mana_visuals(texture: Texture2D) -> void:
	_mana_texture = texture
	
	if not mana_particles_container:
		mana_particles_container = Node3D.new()
		mana_particles_container.name = "ManaParticlesContainer"
		actor.add_child(mana_particles_container)
	
	var body = actor.get_node_or_null("Body")
	if body:
		mana_particles_container.position.y = body.position.y

func update_mana_visuals(delta: float, current_mana: float, shot_mana_cost: float) -> void:
	if not _mana_texture:
		for p in mana_particles:
			if is_instance_valid(p): p.queue_free()
		mana_particles.clear()
		return
		
	var charges: int = 0
	if shot_mana_cost > 0:
		charges = int(current_mana / 5) # Matches original logic
	
	while mana_particles.size() < charges:
		var sprite: Sprite3D = Sprite3D.new()
		sprite.texture = _mana_texture
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.pixel_size = 0.03
		sprite.render_priority = 5
		sprite.transparent = true
		sprite.shaded = false
		
		var rand_axis: Vector3 = Vector3(_rng.randf_range(-1,1), _rng.randf_range(-1,1), _rng.randf_range(-1,1)).normalized()
		if rand_axis == Vector3.ZERO: rand_axis = Vector3.UP
		var orbit_basis: Basis = Basis(rand_axis, _rng.randf_range(0, TAU))
		
		sprite.set_meta("orbit_rotation", orbit_basis)
		sprite.set_meta("phase_offset", _rng.randf_range(0, TAU))
		sprite.set_meta("speed_mult", _rng.randf_range(0.3, 0.6))
		
		mana_particles_container.add_child(sprite)
		mana_particles.append(sprite)
		
	while mana_particles.size() > charges:
		var sprite: Sprite3D = mana_particles.pop_back()
		if is_instance_valid(sprite):
			sprite.queue_free()
		
	_mana_phase += delta
	var orbit_radius: float = 1.1
	for i in range(mana_particles.size()):
		var sprite: Sprite3D = mana_particles[i]
		if not is_instance_valid(sprite): continue
		
		var phase: float = _mana_phase * sprite.get_meta("speed_mult") + sprite.get_meta("phase_offset")
		var lx: float = sin(phase) * orbit_radius
		var ly: float = sin(2.0 * phase) * (orbit_radius * 0.5)
		var lz: float = cos(phase) * (orbit_radius * 0.2)
		
		var orbit_rot: Basis = sprite.get_meta("orbit_rotation")
		sprite.position = orbit_rot * Vector3(lx, ly, lz)
		
		var s: float = 0.8 + sin(phase * 1.5) * 0.15
		sprite.scale = Vector3.ONE * s
