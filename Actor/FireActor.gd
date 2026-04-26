class_name FireActor
extends Actor

const MANA_TEXTURE = preload("res://assets/generated/fire_particle_1774823455.png")

func _init() -> void:
	projectile_scene = preload("res://Actor/Projectiles/FireProjectile.tscn")
	lob_projectile_scene = preload("res://Actor/Projectiles/FireLobProjectile.tscn")
	element_type = "fire"
	is_playable = false

func _ready() -> void:
	super._ready()
	if visual_component:
		visual_component.mana_particle_texture = MANA_TEXTURE
		visual_component.hide_body = true
		if visual_component.body:
			visual_component.body.visible = false
	
	if particle_component:
		particle_component.setup_mana_visuals(MANA_TEXTURE)

func get_actor_color() -> Color:
	return Color(1.0, 0.4, 0.1)
