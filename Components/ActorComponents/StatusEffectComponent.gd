class_name StatusEffectComponent
extends Node

## Component that handles status effects like burning and water interactions for an Actor.
## Uses the Actor's central tick system instead of individual timers.

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
var _sink_tween: Tween

# Tick callback IDs for cleanup
var _fast_tick_id: int = -1
var _slow_tick_id: int = -1

func setup(actor: Actor) -> void:
	_actor = actor
	_body = actor.get_node_or_null("Body")
	_splash_player = actor.get_node_or_null("SplashPlayer")
	_setup_fire_particles()
	if actor.health_component:
		actor.health_component.damage_received.connect(_on_damage_received)
	
	# Register with central game clock (replaces 4 individual timers)
	_fast_tick_id = _actor.register_tick(_on_fast_tick, TILE_CHECK_INTERVAL)
	_slow_tick_id = _actor.register_tick(_on_slow_tick, 1.0)

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

func _physics_process(_delta: float) -> void:
	pass  # All timing routed through GameClockComponent, sinking handled by tweens

func _start_sinking() -> void:
	if not _body or not is_instance_valid(_body):
		return
	if _sink_tween and _sink_tween.is_valid():
		_sink_tween.kill()
	var sink_offset: float = -SINK_OFFSET_PIXELS * (_body.scale.y * 0.01)
	_sink_tween = create_tween()
	_sink_tween.tween_property(_body, "position:y", sink_offset, 0.5).from_current()

func _stop_sinking() -> void:
	if _sink_tween and _sink_tween.is_valid():
		_sink_tween.kill()
	_sink_tween = create_tween()
	_sink_tween.tween_property(_body, "position:y", 0.0, 0.5).from_current()

func _on_fast_tick() -> void:
	# Fast tick (0.1s) - handles tile checks and burn countdown
	if _burning_time_left > 0:
		_burning_time_left -= TILE_CHECK_INTERVAL
		if _burning_time_left <= 0:
			_end_burning()
	else:
		_check_ground_tile()

func _on_slow_tick() -> void:
	# 1.0s tick - handles burn damage and splash sounds
	if _burning_time_left > 0:
		_actor.take_damage(1, "burning", Vector3.UP)
		burning_damage_taken.emit()
	if _is_in_water:
		_play_splash()
		splash_triggered.emit()

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

func _start_burning() -> void:
	if _burning_time_left <= 0:
		_burning_time_left = BURN_DURATION
		_actor.take_damage(1, "burning", Vector3.UP)
		burning_damage_taken.emit()
		burning_started.emit()
	else:
		_burning_time_left = BURN_DURATION

func _end_burning() -> void:
	var was_burning: bool = _fire_particles != null and _fire_particles.emitting
	if _fire_particles:
		_fire_particles.emitting = false
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
			_start_sinking()
			entered_water.emit()

		if _burning_time_left > 0:
			extinguish()
	else:
		if _is_in_water:
			_is_in_water = false
			_stop_sinking()
			exited_water.emit()

func _play_splash() -> void:
	if _splash_player and _splash_player.stream:
		_splash_player.play()

func _on_damage_received(_amount: float, type: String) -> void:
	if type == "fire":
		_start_burning()
	elif type == "water":
		extinguish()

func _exit_tree() -> void:
	# Cleanup tick registrations
	if _fast_tick_id >= 0:
		_actor.unregister_tick(_fast_tick_id)
	if _slow_tick_id >= 0:
		_actor.unregister_tick(_slow_tick_id)
