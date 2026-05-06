class_name WaterActor
extends Actor

const MANA_TEXTURE = preload("res://assets/generated/magic_water_drop_frame_0_1774826822.png")
const PARTICLE_TEXTURE = preload("res://assets/generated/magic_water_drop_frame_0_1774826822.png")
const DRIP_TEXTURE = preload("res://assets/generated/magic_water_drop_frame_1_1774826822.png")

func _init() -> void:
	projectile_scene = preload("res://scenes/projectiles/WaterProjectile.tscn")
	lob_projectile_scene = preload("res://scenes/projectiles/WaterLobProjectile.tscn")
	element_type = "water"
	is_playable = false

func _ready() -> void:
	super._ready()
	if faction_component.faction == FactionComponent.Faction.NEUTRAL:
		faction_component.setup(FactionComponent.Faction.MONSTERS)
	if visual_component:
		visual_component.mana_particle_texture = MANA_TEXTURE
		visual_component.hide_body = true
		if visual_component.body:
			visual_component.body.visible = false
	
	if particle_component:
		particle_component.setup_mana_visuals(MANA_TEXTURE)

func get_actor_color() -> Color:
	return Color(0.1, 0.5, 1.0)

func _configure_particles(particles: GPUParticles3D) -> void:
	ActorParticleComponent.setup_gpu_particles(particles, {
		"amount": 20,
		"spread": 45.0,
		"velocity_min": 1.0,
		"velocity_max": 2.0,
		"gravity": Vector3(0.0, -1.0, 0.0),
		"scale_min": 0.1,
		"scale_max": 0.2,
		"color": Color(0.4, 0.7, 1.0, 0.6),
		"texture": PARTICLE_TEXTURE
	})

func _configure_drips(particles: GPUParticles3D) -> void:
	ActorParticleComponent.setup_gpu_particles(particles, {
		"amount": 15,
		"lifetime": 1.2,
		"local_coords": false,
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_BOX,
		"emission_box_extents": Vector3(0.5, 0.2, 0.5),
		"direction": Vector3.DOWN,
		"spread": 10.0,
		"velocity_min": 0.1,
		"velocity_max": 0.5,
		"gravity": Vector3(0.0, -9.8, 0.0),
		"scale_min": 0.15,
		"scale_max": 0.3,
		"damping_min": 0.5,
		"damping_max": 1.0,
		"texture": DRIP_TEXTURE
	})
