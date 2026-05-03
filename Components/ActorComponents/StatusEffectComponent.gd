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
const BURN_DURATION = 1.0
const DAMAGE_TICK_INTERVAL = 1.0
const SPLASH_INTERVAL = 1.0
const TILE_CHECK_INTERVAL = 0.1
const SINK_OFFSET_PIXELS = 50.0

var _burning_time_left: float = 0.0
var _fire_particles: GPUParticles3D

var _is_in_water: bool = false

var _actor: Actor
var _body: Node3D
var _splash_player: AudioStreamPlayer3D

var _burn_timer: Timer
var _damage_tick_timer: Timer
var _tile_check_timer: Timer
var _splash_timer: Timer

func setup(actor: Actor) -> void:
	_actor = actor
	_body = actor.get_node_or_null("Body")
	_splash_player = actor.get_node_or_null("SplashPlayer")
	_setup_fire_particles()
	_setup_timers()
	if actor.health_component:
		actor.health_component.damage_received.connect(_on_damage_received)

func _setup_fire_particles() -> void:
	_fire_particles = GPUParticles3D.new()
	_actor.add_child(_fire_particles)
	_fire_particles.position = Vector3.ZERO
	_fire_particles.emitting = false

	ActorParticleComponent.setup_gpu_particles(_fire_particles, {
		"emitting": false,
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

func _setup_timers() -> void:
	# Don't start timers yet - they only get started when status effects activate
	_burn_timer = _create_timer("BurnTimer", TILE_CHECK_INTERVAL, _on_burn_timer_timeout, false, false)
	_damage_tick_timer = _create_timer("DamageTickTimer", DAMAGE_TICK_INTERVAL, _on_damage_tick_timeout, false, false)
	_tile_check_timer = _create_timer("TileCheckTimer", TILE_CHECK_INTERVAL, _on_tile_check_timer_timeout, false, false)
	_splash_timer = _create_timer("SplashTimer", SPLASH_INTERVAL, _on_splash_timer_timeout, false, false)
	# Start the tile check timer to monitor for fire/water tiles
	_tile_check_timer.start()

func _create_timer(name: String, wait_time: float, callback: Callable, one_shot: bool, autostart: bool = true) -> Timer:
	var timer: Timer = Timer.new()
	timer.name = name
	timer.wait_time = wait_time
	timer.one_shot = one_shot
	timer.timeout.connect(callback)
	add_child(timer)
	if autostart:
		timer.start()
	return timer

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
		_burn_timer.stop()
		_damage_tick_timer.stop()
		burning_ended.emit()

func _on_burn_timer_timeout() -> void:
	if _burning_time_left > 0:
		_burning_time_left -= TILE_CHECK_INTERVAL
		if _burning_time_left <= 0:
			_end_burning()
	else:
		_check_ground_tile()

func _on_damage_tick_timeout() -> void:
	if _burning_time_left > 0:
		_actor.take_damage(1, "burning", Vector3.UP)
		burning_damage_taken.emit()

func _on_tile_check_timer_timeout() -> void:
	if _burning_time_left <= 0:
		_check_ground_tile()

func _on_splash_timer_timeout() -> void:
	_play_splash()
	splash_triggered.emit()

func _start_burning() -> void:
	if _burning_time_left <= 0:
		_burning_time_left = BURN_DURATION
		_actor.take_damage(1, "burning", Vector3.UP)
		burning_damage_taken.emit()
		burning_started.emit()
		_damage_tick_timer.start()
		_burn_timer.start()
	else:
		_burning_time_left = BURN_DURATION

func _end_burning() -> void:
	var was_burning: bool = _fire_particles != null and _fire_particles.emitting
	if _fire_particles:
		_fire_particles.emitting = false
	_damage_tick_timer.stop()
	if was_burning:
		burning_ended.emit()

func _check_ground_tile() -> void:
	var tile_interaction_component: ActorTileInteractionComponent = _actor.tile_interaction_component
	var ground_tile: HexTileData = tile_interaction_component.get_ground_tile() if tile_interaction_component else null

	if ground_tile and ground_tile.tile_type == TileConstants.Type.FIRE:
		_start_burning()
	elif ground_tile and ground_tile.tile_type == TileConstants.Type.PUDDLE:
		if not _is_in_water:
			_is_in_water = true
			_splash_timer.start()
			entered_water.emit()

		if _burning_time_left > 0:
			extinguish()
	else:
		if _is_in_water:
			_is_in_water = false
			_splash_timer.stop()
			exited_water.emit()

func _play_splash() -> void:
	if _splash_player and _splash_player.stream:
		_splash_player.play()

func _on_damage_received(_amount: float, type: String) -> void:
	if type == "fire":
		_start_burning()
	elif type == "water":
		extinguish()
