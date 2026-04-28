class_name GoblinMinion
extends Actor

## Goblin Minion: Small Fey (Goblinoid), Chaotic Neutral
## AC 12, HP 2d6, Speed 3
## Nimble Escape: Disengage (dodge) or Hide (invisibility)

@export_group("Goblin Stats")
@export var stealth_modifier: int = 6
@export var passive_perception: int = 9

func _init() -> void:
	element_type = "goblin"
	should_bob = false
	is_playable = false
	move_speed = 3.0
	actor_size = Size.SMALL

func _create_controller() -> ActorAIController:
	return GoblinController.new()

func _ready() -> void:
	super._ready()
	faction_component.setup(FactionComponent.Faction.GOBLINS)
	
	# Stat bonuses
	ability_scores_component.strength = -1
	ability_scores_component.dexterity = 2.5
	ability_scores_component.constitution = 0
	ability_scores_component.intelligence = 0
	ability_scores_component.wisdom = -1
	ability_scores_component.charisma = -1

	# Armor Setup: AC 12 (10 base + 2 dex)
	if armor_class_component:
		armor_class_component.armor_type = ArmorClassComponent.ArmorType.NONE
		armor_class_component.armor_value = 10
		armor_class_component.refresh()

	# Roll HP: 2d6
	max_hp = health_component.roll_max_health(2, 6, _rng)
	
	# Load Dagger weapon - overrides the default if found
	var wl = get_node_or_null("/root/ItemsAutoload")
	if wl:
		for w in wl.weapons:
			if w.name == "Dagger":
				_on_weapon_selected(w)
				break
	
	if not equipped_weapon:
		# Fallback if ItemsAutoload not ready or dagger not found
		_on_weapon_selected(WeaponData.new("Dagger", "2 gp", "1d4", "piercing", 1, "Finesse, light, thrown (range 10/30), ammo 5"))

	if _body is AnimatedSprite3D:
		var sprite = _body as AnimatedSprite3D
		sprite.pixel_size = 0.02
		sprite.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		sprite.play(&"idle")
		sprite.offset.y = 24

func _process(delta: float) -> void:
	_update_sprite_animation()

func _update_sprite_animation() -> void:
	if not _body is AnimatedSprite3D: return
	var sprite = _body as AnimatedSprite3D
	
	if weapon and weapon_component.is_on_cooldown():
		if sprite.animation != &"attack":
			sprite.play(&"attack")
		return

	var horizontal_velocity = Vector3(velocity.x, 0, velocity.z)
	if horizontal_velocity.length() > 0.2:
		_last_dir = get_cardinal_direction(horizontal_velocity.normalized())
		var anim_name = "walk_" + _last_dir
		if sprite.animation != anim_name:
			sprite.play(anim_name)
		sprite.flip_h = false
	else:
		var anim_name = StringName("idle_" + _last_dir) if sprite.sprite_frames.has_animation("idle_" + _last_dir) else &"idle"
		if sprite.animation != anim_name:
			sprite.play(anim_name)
		sprite.flip_h = false
