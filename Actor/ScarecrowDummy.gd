class_name ScarecrowDummy
extends Actor

func _init() -> void:
	is_playable = false
	is_friendly = false

func _ready() -> void:
	max_hp = 999
	move_speed = 0.0
	should_bob = false
	
	super._ready()
	
	if health_component:
		health_component.bar_visible_always = true
		health_component.bar_color = Color.YELLOW

func _physics_process(delta: float) -> void:
	# Health regeneration: 1 per second
	if health_component and health_component.current_health < health_component.max_health:
		health_component.heal(1.0 * delta)
	
	# Keep it stationary
	velocity.x = 0
	velocity.z = 0
	
	super._physics_process(delta)

func _launch_projectile() -> void:
	# Disabled
	pass
