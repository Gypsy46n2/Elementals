class_name GoatActor
extends Actor

## Specialized Actor that represents a goat.
## Features a charge attack, terrain-based speed modifiers, and specialized visual effects.

@export_group("Goat Charge")
## The speed at which the goat charges forward.
@export var charge_speed: float = 25.0
## The maximum distance the goat can travel in a single charge.
@export var charge_distance: float = 5.0
## The time in seconds between consecutive charges.
@export var charge_cooldown: float = 1.0
## The minimum time in seconds between consecutive screams for this goat.
@export var scream_cooldown: float = 2.0

# Charging state variables
var _is_charging: bool = false
var _charge_direction: Vector3 = Vector3.ZERO
var _charge_remaining_dist: float = 0.0
var _charge_cooldown_timer: float = 0.0
var _scream_timer: float = 0.0

# Burning state variables
var _burning_time_left: float = 0.0
var _damage_tick_timer: float = 0.0
var _fire_particles: GPUParticles3D

# Water interaction state variables
var _splash_timer: float = 0.0
var _is_in_water: bool = false

var _name_label: Label3D

@onready var _whack_player: AudioStreamPlayer3D = get_node_or_null("WhackPlayer")
@onready var _splash_player: AudioStreamPlayer3D = get_node_or_null("SplashPlayer")
@onready var _swoosh_player: AudioStreamPlayer3D = get_node_or_null("SwooshPlayer")
@onready var _scream_player: AudioStreamPlayer3D = get_node_or_null("ScreamPlayer")

@onready var pattern_sprite: Sprite3D = get_node_or_null("Body/Pattern")
@onready var horns_sprite: Sprite3D = get_node_or_null("Body/Horns")

var goat_data: GoatData:
	set(v):
		if goat_data:
			if goat_data.stats_changed.is_connected(_on_goat_data_changed):
				goat_data.stats_changed.disconnect(_on_goat_data_changed)
		goat_data = v
		if goat_data:
			goat_data.stats_changed.connect(_on_goat_data_changed)
			_on_goat_data_changed()

func _ready() -> void:
	# Update actor size based on body type
	match goat_data.body_type:
		GoatData.BodyType.SMALL: actor_size = Size.SMALL
		GoatData.BodyType.MEDIUM: actor_size = Size.MEDIUM
		GoatData.BodyType.LARGE: actor_size = Size.LARGE
	
	super._ready()
	faction_component.setup(FactionComponent.Faction.WILDLIFE)
	element_type = "goat"
	should_bob = false
	
	_on_goat_data_changed()
	
	if _body is Sprite3D:
		if _body.hframes * _body.vframes > 1:
			_body.frame = _rng.randi_range(0, _body.hframes * _body.vframes - 1)
	
	get_tree().node_added.connect(_on_node_added)
	# Connect to existing goats
	for node in get_tree().get_nodes_in_group("goats"):
		if node != self:
			node.screamed.connect(_on_other_goat_screamed)
	add_to_group("goats")

	if health_component:
		health_component.damage_received.connect(_on_damage_received)
	
	_fire_particles = GPUParticles3D.new()
	add_child(_fire_particles)
	_fire_particles.position = Vector3(0, 0, 0)
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


func _on_goat_data_changed() -> void:
	if not is_node_ready() or not goat_data:
		return
	
	# Visuals
	_update_goat_visuals()
	
	# Performance Stats Scaling
	ability_scores_component.strength = goat_data.strength
	ability_scores_component.dexterity = goat_data.dexterity
	ability_scores_component.constitution = goat_data.constitution
	ability_scores_component.intelligence = goat_data.intelligence
	ability_scores_component.wisdom = goat_data.wisdom
	ability_scores_component.charisma = goat_data.charisma

	move_speed = 3.0 * ability_scores_component.dexterity
	max_hp = 10.0 * ability_scores_component.constitution
	
	charge_speed = 25.0 + (5.0 * ability_scores_component.strength)
	charge_distance = 5.0 + (1.0 * ability_scores_component.strength)
	
	# Scale Body
	var s = 1.5
	match goat_data.body_type:
		GoatData.BodyType.SMALL: 
			s = 1.2
			actor_size = Size.SMALL
		GoatData.BodyType.MEDIUM: 
			s = 1.5
			actor_size = Size.MEDIUM
		GoatData.BodyType.LARGE: 
			s = 1.8
			actor_size = Size.LARGE
	
	if _body:
		_body.scale = Vector3.ONE * s
		_body.visible = true
		if health_component:
			health_component.bar_offset = Vector3(0, 1.2 * s, 0)
		var body_sprite = _body as Sprite3D
		if body_sprite:
			if body_sprite.texture == null:
				body_sprite.texture = preload("res://assets/Characters/GruffGoat.png")
			_update_sprite_offsets()
	
func _update_sprite_offsets() -> void:
	var sprites: Array[Sprite3D] = [_body as Sprite3D, pattern_sprite, horns_sprite]
	for s in sprites:
		if s and s.texture:
			# Positive Y offset on Sprite3D (when centered=true) moves it UP.
			# We want the bottom (which is at -H/2) to move to 0.
			s.offset.y = s.texture.get_height() / 2.0

func die() -> void:
	# Inform the arena for game-over checking via the event bus
	GameEvents.actor_died.emit(self)
	
	# Permanent removal from the persistent herd
	if has_node("/root/GoatManager"):
		get_node("/root/GoatManager").remove_goat(goat_data)
	
	# Visual feedback: poof or just vanish
	print("Goat PERMANENTLY died: ", goat_data.goat_name)
	queue_free()

func _update_goat_visuals() -> void:
	if not goat_data: return
	
	# Re-use the ASSETS from GoatRenderer logic or similar
	var body_tex = preload("res://assets/experimental/goat_body_quadruped_frame_0_1775009982.png")
	if not body_tex:
		body_tex = preload("res://assets/Characters/GruffGoat.png")
		
	var patterns = {
		GoatData.PatternType.SOLID: null,
		GoatData.PatternType.PIEBALD: preload("res://assets/generated/GoatCurledHornsGreyStriped_SideView_frame_1_1775090983.png"),
		GoatData.PatternType.SPOTTED: preload("res://assets/generated/GoatCurledHornsGreyStriped_SideView_frame_2_1775090983.png"),
	}
	var horns = {
		GoatData.HornType.NONE: null,
		GoatData.HornType.SMALL: preload("res://assets/generated/GoatCurledHornsGreyStriped_SideView_frame_0_1775090983.png"),
		GoatData.HornType.LARGE: preload("res://assets/generated/GoatCurledHornsGreyStriped_SideView_frame_0_1775090983.png"),
		GoatData.HornType.SPIRAL: preload("res://assets/generated/GoatCurledHornsGreyStriped_SideView_frame_3_1775090983.png"),
	}

	var body_sprite = _body as Sprite3D
	if body_sprite:
		body_sprite.texture = body_tex
		body_sprite.modulate = goat_data.base_color
		
	if pattern_sprite:
		pattern_sprite.texture = patterns.get(goat_data.pattern_type)
		pattern_sprite.visible = pattern_sprite.texture != null
		pattern_sprite.modulate = goat_data.pattern_color
		
	if horns_sprite:
		horns_sprite.texture = horns.get(goat_data.horn_type)
		horns_sprite.visible = horns_sprite.texture != null
		horns_sprite.modulate = Color(0.9, 0.9, 0.8)
	
	_update_sprite_offsets()

	if not _name_label:
		_name_label = Label3D.new()
		_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		_name_label.no_depth_test = true
		_name_label.render_priority = 25
		_name_label.modulate = Color.YELLOW
		_name_label.outline_modulate = Color.BLACK
		_name_label.pixel_size = 0.015 # "Big" letters
		_name_label.font_size = 64
		add_child(_name_label)
	
	_name_label.text = goat_data.goat_name
	var s = 1.5
	match goat_data.body_type:
		GoatData.BodyType.SMALL: s = 1.2
		GoatData.BodyType.MEDIUM: s = 1.5
		GoatData.BodyType.LARGE: s = 1.8
	_name_label.position = Vector3(0, 1.6 * s, 0) # Position above the HP bar

# Constants for visual behavior
const SINK_OFFSET_PIXELS = 50.0
const SPLASH_INTERVAL = 1.0

# Static scream management to prevent feedback loops and performance spikes
static var _pending_responses_count: int = 0
const MAX_CONCURRENT_RESPONSES = 2

const FIRE_TEXTURE = preload("res://assets/generated/fire_particle_1774823455.png")
const THWAK_TEXTURE = preload("res://assets/generated/thwak_popup_frame_0_1774916398.png")
const SCREAM_TEXTURE = preload("res://assets/generated/scream_bubble_frame_0_1774821924.png")

func _create_controller() -> ActorAIController:
	return GoatController.new()

signal screamed(pos: Vector3)

func _process(delta: float) -> void:
	## Main update loop handling visual updates and cooldowns.
	_update_burning(delta)
	_update_water_effect(delta)
	
	# Handle charge cooldown
	if _charge_cooldown_timer > 0:
		_charge_cooldown_timer -= delta
		
	# Handle scream cooldown
	if _scream_timer > 0:
		_scream_timer -= delta

func _physics_process(delta: float) -> void:
	## Extends physics processing to check for headbutt collisions during a charge.
	
	if is_stunned():
		_is_charging = false
		velocity = Vector3.ZERO
	
	if _is_charging:
		_handle_charge_logic(delta)
	
	super._physics_process(delta)
	
	# Handle water sinking visual after BobComponent has set the position
	if _is_in_water and _body:
		var sprite: Sprite3D = _body as Sprite3D
		if sprite:
			var sink_offset = -SINK_OFFSET_PIXELS * sprite.pixel_size * sprite.scale.y
			_body.position.y += sink_offset
	
	if _is_charging:
		# Check for collisions with other actors during the charge
		for i in get_slide_collision_count():
			var collision = get_slide_collision(i)
			var collider = collision.get_collider()
			if collider is Actor and collider != self:
				_handle_headbutt_hit(collider, collision.get_position())
				# Stop the charge immediately upon hitting another actor
				_is_charging = false
				velocity = Vector3.ZERO
				break
			elif _arena_grid and (collider == _arena_grid.physics or collider.name == "FloorStaticBody"):
				var tile_data = _arena_grid.get_tile_data_at_world_position(collision.get_position())
				if tile_data:
					if _arena_grid.apply_element_to_tile(tile_data, "headbutt"):
						_play_whack()
						_show_thwak_visual(collision.get_position())
					
					if tile_data.tile_type == TileConstants.Type.STONE:
						_is_charging = false
						velocity = Vector3.ZERO
						break
			else:
				# Check if we hit a feature on the tile (like a tree)
				var potential_feature = collider
				while potential_feature and not potential_feature.has_method("apply_element"):
					potential_feature = potential_feature.get_parent()
					if potential_feature == get_tree().root:
						potential_feature = null
						break
				
				if potential_feature and potential_feature.has_method("apply_element"):
					if potential_feature.apply_element("headbutt", velocity.normalized()):
						_play_whack()
						_show_thwak_visual(collision.get_position())
						
						# Stop charging if we hit a feature that handled the element
						_is_charging = false
						velocity = Vector3.ZERO
						break

func _handle_charge_logic(delta: float) -> void:
	## Manages the active charge state, updating distance and speed.
	var multiplier = _get_speed_multiplier()
	var current_charge_speed = charge_speed * multiplier
	
	# Maintain the charge direction even if player tries to move elsewhere
	velocity.x = _charge_direction.x * current_charge_speed
	velocity.z = _charge_direction.z * current_charge_speed
	
	var horizontal_vel = Vector3(velocity.x, 0, velocity.z)
	
	# Stop charging if we reach the distance limit or get stuck
	if horizontal_vel.length() < current_charge_speed * 0.5 and current_charge_speed > 0.1:
		_is_charging = false
		velocity = Vector3.ZERO
		return
		
	_charge_remaining_dist -= horizontal_vel.length() * delta
	if _charge_remaining_dist <= 0:
		_is_charging = false
		velocity = Vector3.ZERO

func _handle_headbutt_hit(target: Actor, hit_pos: Vector3) -> void:
	## Deals damage to the target and displays the "Thwak" visual effect.
	var damage = 1
	var knockback_strength = 12.0
	
	if goat_data:
		damage = int(max(1, ability_scores_component.strength))
		knockback_strength *= ability_scores_component.strength

	target.take_damage(damage, "normal", (target.global_position - global_position).normalized())
	target.stun(0.5)
	_show_thwak_visual(hit_pos)
	_play_whack()
	
	# Apply knockback to the target
	if target.movement_component:
		var knockback_dir = (target.global_position - global_position).normalized()
		knockback_dir.y = 0.5 # Add a little upward pop
		target.movement_component.apply_external_force(knockback_dir * knockback_strength)

func _play_whack() -> void:
	if _whack_player:
		_whack_player.play()

func _show_thwak_visual(pos: Vector3) -> void:
	## Displays a "THWAK!" comic book style popup at the collision point.
	var sprite = Sprite3D.new()
	var texture = THWAK_TEXTURE
	
	if texture:
		sprite.texture = texture
		sprite.pixel_size = 0.02 # Toned down from 0.04
	else:
		return
		
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	# Add to the arena (parent) so it stays at the collision world position
	if get_parent():
		get_parent().add_child(sprite)
	else:
		add_child(sprite)
		
	sprite.global_position = pos + Vector3(0, 0.5, 0) # Position slightly above the hit point
	
	# Animate: Pop in, slight shake, and fade out
	sprite.scale = Vector3.ZERO
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector3.ONE * 1.0, 0.1)
	
	# Brief shake
	for i in range(3):
		var shake = Vector3(randf_range(-0.05, 0.05), randf_range(-0.05, 0.05), 0)
		tween.tween_property(sprite, "position", sprite.position + shake, 0.04)
	
	# Fade and rise
	tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.parallel().tween_property(sprite, "position:y", sprite.position.y + 0.4, 0.3).set_delay(0.2)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.3).set_delay(0.2)
	tween.tween_callback(sprite.queue_free)

func _update_water_effect(delta: float) -> void:
	## Monitors if the goat is standing in water (puddle) and triggers splash effects.
	var ground_tile = tile_interaction_component.get_ground_tile() if tile_interaction_component else null
	if ground_tile and ground_tile.tile_type == TileConstants.Type.PUDDLE:
		if not _is_in_water:
			_is_in_water = true
			_splash_timer = 0.0 # Trigger immediate splash upon entry
		
		# Instantly extinguish fire if we enter water
		if _burning_time_left > 0:
			_burning_time_left = 0.0
		
		_splash_timer -= delta
		if _splash_timer <= 0:
			_play_splash()
			_splash_timer = SPLASH_INTERVAL
	else:
		_is_in_water = false
		_splash_timer = 0.0

func _play_splash() -> void:
	if _splash_player and _splash_player.stream:
		_splash_player.play()

func _play_swoosh() -> void:
	if _swoosh_player and _swoosh_player.stream:
		_swoosh_player.play()

func _update_burning(delta: float) -> void:
	## Handles the logic for when the goat is on fire, including damage over time.
	if _burning_time_left > 0:
		_burning_time_left -= delta
		_damage_tick_timer -= delta
		
		if _fire_particles:
			_fire_particles.emitting = true
		
		# Apply damage every tick
		if _damage_tick_timer <= 0:
			_take_fire_damage()
	else:
		if _fire_particles:
			_fire_particles.emitting = false
		_damage_tick_timer = 0.0

func _check_tile_damage(tile: HexTileData) -> bool:
	## Overrides base damage check to add specific logic for fire tiles.
	if tile.tile_type == TileConstants.Type.FIRE:
		_start_burning()
		return true
	return false

func _start_burning() -> void:
	## Initiates the burning state.
	if _burning_time_left <= 0:
		_burning_time_left = 1.0
		_take_fire_damage()
	else:
		_burning_time_left = 1.0

func _take_fire_damage() -> void:
	## Applies damage and visual/audio feedback for fire damage.
	take_damage(1, "burning", Vector3.UP)
	_scream()
	_flash_red()
	_damage_tick_timer = 1.0

func _on_damage_received(_amount: float, type: String) -> void:
	if type == "fire":
		_start_burning()
	elif type == "water":
		_burning_time_left = 0.0

func _flash_red() -> void:
	## Briefly modulates the sprite red to indicate damage.
	if _body:
		var sprite = _body as Sprite3D
		if sprite:
			var base_color = Color.WHITE
			if goat_data:
				base_color = goat_data.base_color
				
			var tween = create_tween()
			tween.tween_property(sprite, "modulate", Color.RED, 0.1)
			tween.tween_property(sprite, "modulate", base_color, 0.1)

func get_actor_color() -> Color:
	## Returns the thematic color for the goat actor.
	return Color(0.7, 0.6, 0.4) # A light brown/grey

func get_main_action_progress() -> float:
	## Overridden to show the headbutt (charge) cooldown progress instead of mana.
	if _charge_cooldown_timer > 0:
		return 1.0 - (_charge_cooldown_timer / charge_cooldown)
	return 1.0


func _get_speed_multiplier() -> float:
	## Returns a movement speed multiplier based on the current terrain tile.
	var ground_tile = tile_interaction_component.get_ground_tile() if tile_interaction_component else null
	if not ground_tile:
		return 1.0
		
	match ground_tile.tile_type:
		TileConstants.Type.MUD:
			return 0.5
		TileConstants.Type.PUDDLE:
			return 0.7
		TileConstants.Type.GRASS:
			return 1.2
		TileConstants.Type.STONE:
			return 1.0
		TileConstants.Type.FIRE:
			return 1.3 # Goats run faster when their feet are on fire!
		_:
			return 1.0

func _launch_projectile() -> void:
	## Overrides base projectile logic as goats do not use projectiles.
	pass

func _unhandled_input(event: InputEvent) -> void:
	## Handles player input for scream (right click) and charge (left click) when controlled.
	if is_controlled and not is_stunned() and event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and event.pressed:
			_scream()
		elif event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var target_pos = _get_mouse_3d_position()
			_start_charge(target_pos)
			get_viewport().set_input_as_handled()

func _start_charge(target_pos: Vector3) -> void:
	## Initiates a fast-moving charge attack towards the specified target position.
	if _is_charging or _charge_cooldown_timer > 0 or is_stunned():
		return
		
	var diff = (target_pos - global_position)
	diff.y = 0 # Ensure charge is purely horizontal
	
	if diff.length() > 0.1:
		var dir = diff.normalized()
		_is_charging = true
		_charge_direction = dir
		
		# Terrain affects the total charge distance and speed
		var multiplier = _get_speed_multiplier()
		_charge_remaining_dist = charge_distance * multiplier
		_charge_cooldown_timer = charge_cooldown
		
		velocity = dir * (charge_speed * multiplier)
		_play_swoosh()
		
		# Send pinecones on the present tile rolling in the direction of the headbutt
		var ground_tile = tile_interaction_component.get_ground_tile() if tile_interaction_component else null
		if ground_tile and _arena_grid:
			_arena_grid.apply_element_to_tile(ground_tile, "headbutt")

func ai_start_charge(target_pos: Vector3) -> void:
	## AI-triggered charge attack.
	_start_charge(target_pos)

func _get_mouse_3d_position() -> Vector3:
	## Project the mouse position into the 3D world on the ground plane (y=0).
	var camera = get_viewport().get_camera_3d()
	if not camera:
		return Vector3.ZERO
		
	var mouse_pos = get_viewport().get_mouse_position()
	var ray_origin = camera.project_ray_origin(mouse_pos)
	var ray_direction = camera.project_ray_normal(mouse_pos)
	
	if abs(ray_direction.y) < 1e-6:
		return Vector3.ZERO
		
	var t = -ray_origin.y / ray_direction.y
	return ray_origin + ray_direction * t

func _scream() -> void:
	## Triggers the goat's iconic scream sound and visual effect.
	if _scream_timer > 0:
		return
		
	# Set cooldown immediately to prevent rapid-fire screaming
	_scream_timer = scream_cooldown
	
	if _scream_player and _scream_player.stream:
		_scream_player.play()
	
	_show_scream_visual()
	screamed.emit(global_position)

func _on_other_goat_screamed(pos: Vector3) -> void:
	## If another goat screams nearby, this goat might scream back.
	# Don't respond if we are already cooling down, charging, or if too many are already responding
	if _scream_timer > 0 or _pending_responses_count >= MAX_CONCURRENT_RESPONSES:
		return
		
	if pos.distance_to(global_position) < 15.0 and randf() < 0.25: # Reduced probability
		# Increment pending response count globally
		GoatActor._pending_responses_count += 1
		
		# Wait a random short time before screaming back
		var timer = get_tree().create_timer(randf_range(0.3, 1.2)) # Slightly longer/more varied delay
		timer.timeout.connect(func():
			# Always decrement the pending count when the timer finishes
			GoatActor._pending_responses_count -= 1
			
			if not is_instance_valid(self): return
			if not _is_charging and not is_stunned(): # Don't scream if charging or stunned
				_scream()
		)

func _on_node_added(node: Node) -> void:
	if node is GoatActor and node != self:
		if not node.screamed.is_connected(_on_other_goat_screamed):
			node.screamed.connect(_on_other_goat_screamed)

func _show_scream_visual() -> void:
	## Displays a "BAAAAAA!" comic book style speech bubble above the goat.
	var sprite = Sprite3D.new()
	var texture = SCREAM_TEXTURE
	
	if texture:
		sprite.texture = texture
		sprite.pixel_size = 0.04 # Toned down from 0.06
	else:
		# Fallback to text label if texture is missing
		print("Warning: Scream bubble texture missing.")
		_show_scream_text()
		return
		
	sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sprite.position = Vector3(0, 1.8, 0.1)
	sprite.modulate = Color.WHITE
	add_child(sprite)
	
	# Animate the speech bubble: pop in, shake, then float and fade
	sprite.scale = Vector3.ZERO
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector3.ONE * 1.2, 0.15)
	
	# Rapid shake for emphasis
	for i in range(4):
		var shake_offset = Vector3(randf_range(-0.1, 0.1), randf_range(-0.1, 0.1), 0)
		tween.tween_property(sprite, "position", Vector3(0, 0.8, 0.1) + shake_offset, 0.05)
	
	# Final fade and removal
	tween.tween_property(sprite, "position", Vector3(0, 0.8, 0.1), 0.05)
	tween.set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_IN)
	tween.tween_property(sprite, "position:y", 1.1, 0.4).set_delay(0.2)
	tween.parallel().tween_property(sprite, "modulate:a", 0.0, 0.4).set_delay(0.2)
	tween.tween_callback(sprite.queue_free)

func _show_scream_text() -> void:
	## Fallback visual effect using a Label3D.
	var label = Label3D.new()
	label.text = "BAAAAAA!"
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = Vector3(0, 0.75, 0)
	label.modulate = Color.WHITE
	label.outline_modulate = Color.BLACK
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", 1.25, 0.5)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.5)
	tween.tween_callback(label.queue_free)
