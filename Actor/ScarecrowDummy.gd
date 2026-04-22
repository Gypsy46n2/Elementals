class_name ScarecrowDummy
extends Actor

func _init() -> void:
	is_playable = false
	is_friendly = false

func _ready() -> void:
	max_hp = 999
	move_speed = 0.0
	shot_mana_cost = 999999.0
	should_bob = false
	
	super._ready()
	
	if health_component:
		health_component.bar_visible_always = true
		health_component.bar_color = Color.YELLOW

func _physics_process(delta: float) -> void:
	# Health regeneration: 1 per second
	if health_component and health_component.current_health < health_component.max_health:
		health_component.heal(1.0 * delta)
	
	# Skip movement and attack logic from base Actor class
	# We still update tile info for effects (like fire spreading to it)
	_update_tile_below()
	_apply_ground_effects()
	
	# Mana regen still happens as it's harmless
	current_mana = min(current_mana + mana_regen_rate * delta, max_mana)
	
	# Apply gravity to keep it on ground, but zero horizontal velocity
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = 0
	
	velocity.x = 0
	velocity.z = 0
	
	move_and_slide()

func _launch_projectile() -> void:
	# Disabled
	pass

func launch_projectile_at(_target: Vector3) -> void:
	# Disabled
	pass
