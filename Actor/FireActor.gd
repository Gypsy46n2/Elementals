class_name FireActor
extends Actor

const MANA_TEXTURE = preload("res://assets/generated/fire_particle_1774823455.png")

func _init() -> void:
	projectile_scene = preload("res://Actor/Projectiles/FireProjectile.tscn")
	lob_projectile_scene = preload("res://Actor/Projectiles/FireLobProjectile.tscn")
	element_type = "fire"

func _setup_actor() -> void:
	# Hide the body mesh so the actor is only represented by particles
	if _body:
		_body.visible = false

func _get_mana_particle_texture() -> Texture2D:
	return MANA_TEXTURE

func get_actor_color() -> Color:
	return Color(1.0, 0.4, 0.1)

func _do_tile_effect(tile: HexTileData) -> void:
	if _arena_grid.apply_element_to_tile(tile, "fire"):
		if tile.current_state == TileConstants.State.FIRE:
			current_mana = min(current_mana + 1.0, max_mana)
