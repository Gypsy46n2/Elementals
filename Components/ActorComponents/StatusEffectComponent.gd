class_name StatusEffectComponent
extends Node

## Component that handles status effects like burning and water interactions for an Actor.

signal burning_started()
signal burning_damage_taken()
signal burning_ended()
signal entered_water()
signal exited_water()
signal splash_triggered()

const FIRE_TEXTURE = preload("res://assets/generated/fire_particle_1774823455.png")
const SPLASH_INTERVAL = 1.0
const SINK_OFFSET_PIXELS = 50.0

var _burning_time_left: float = 0.0
var _damage_tick_timer: float = 0.0
var _fire_particles: GPUParticles3D

var _splash_timer: float = 0.0
var _is_in_water: bool = false

var _actor: Actor
var _body: Node3D
var _splash_player: AudioStreamPlayer3D

func setup(actor: Actor) -> void:
	_actor = actor
	_body = actor.get_node_or_null("Body")
	_splash_player = actor.get_node_or_null("SplashPlayer")
	_setup_fire_particles()
	if actor.health_component:
		actor.health_component.damage_received.connect(_on_damage_received)

func _setup_fire_particles() -> void:
	_fire_particles = GPUParticles3D.new()
	_actor.add_child(_fire_particles)
	_fire_particles.position = Vector3.ZERO
	_fire_particles.emitting = false

	ActorParticleComponent.setup_gpu_particles(_fire_particles, {
		"amount": 15,
		"lifetime": 0.5,
		"velocity_min": 1.0,
		"velocity_max": 2.0,
		"gravity": Vector3(0.0, 2.0, 0.0),
		"scale_min": 0.1,
		"scale_max": 0.2,
		"texture": FIRE_TEXTURE,
		"emission_shape": ParticleProcessMaterial.EMISSION_SHAPE_BOX,
		"emission_box_extents": Vector3(0.3, 0.1, 0.3)
	})

# TODO(Optimization): Use Timer node or signals for status effect updates instead of per-frame processing (~1.5% CPU per actor)
func _process(delta: float) -> void:
	_update_burning(delta)
	_update_tile_effects(delta)

func _physics_process(_delta: float) -> void:
	# Handle water sinking visual after BobComponent has set the position
	if _is_in_water and _body:
		var sprite: Sprite3D = _body as Sprite3D
		if sprite:
			var sink_offset: float = -SINK_OFFSET_PIXELS * sprite.pixel_size * sprite.scale.y
			_body.position.y += sink_offset

func is_burning() -> bool:
	return _burning_time_left > 0.0

func is_in_water() -> bool:
	return _is_in_water

func extinguish() -> void:
	if _burning_time_left > 0:
		_burning_time_left = 0.0
		if _fire_particles:
			_fire_particles.emitting = false
		burning_ended.emit()

func _update_burning(delta: float) -> void:
	if _burning_time_left > 0:
		_burning_time_left -= delta
		_damage_tick_timer -= delta

		if _fire_particles:
			_fire_particles.emitting = true

		if _damage_tick_timer <= 0:
			_actor.take_damage(1, "burning", Vector3.UP)
			burning_damage_taken.emit()
			_damage_tick_timer = 1.0
	else:
		var was_burning: bool = _fire_particles != null and _fire_particles.emitting
		if _fire_particles:
			_fire_particles.emitting = false
		_damage_tick_timer = 0.0
		if was_burning:
			burning_ended.emit()

func _start_burning() -> void:
	if _burning_time_left <= 0:
		_burning_time_left = 1.0
		_actor.take_damage(1, "burning", Vector3.UP)
		burning_damage_taken.emit()
		burning_started.emit()
		_damage_tick_timer = 1.0
	else:
		_burning_time_left = 1.0

func _update_tile_effects(delta: float) -> void:
	var tile_interaction_component: ActorTileInteractionComponent = _actor.tile_interaction_component
	var ground_tile: HexTileData = tile_interaction_component.get_ground_tile() if tile_interaction_component else null

	# Standing on fire tiles causes burning
	if ground_tile and ground_tile.tile_type == TileConstants.Type.FIRE:
		if _burning_time_left <= 0:
			_start_burning()

	if ground_tile and ground_tile.tile_type == TileConstants.Type.PUDDLE:
		if not _is_in_water:
			_is_in_water = true
			_splash_timer = 0.0
			entered_water.emit()

		if _burning_time_left > 0:
			extinguish()

		_splash_timer -= delta
		if _splash_timer <= 0:
			_play_splash()
			splash_triggered.emit()
			_splash_timer = SPLASH_INTERVAL
	else:
		if _is_in_water:
			_is_in_water = false
			exited_water.emit()
		_splash_timer = 0.0

func _play_splash() -> void:
	if _splash_player and _splash_player.stream:
		_splash_player.play()

func _on_damage_received(_amount: float, type: String) -> void:
	if type == "fire":
		_start_burning()
	elif type == "water":
		extinguish()
