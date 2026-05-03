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

	# Armor Setup: based on GameSettings selection for player, randomized for NPC goblins
	if armor_class_component:
		var armor_selection: int
		
		if is_playable:
			# Player goblin uses the selected equipment
			armor_selection = GameSettings.selected_armor_index
		else:
			# NPC goblins get randomized equipment
			armor_selection = _rng.randi_range(0, 2)
		
		match armor_selection:
			0:
				# No armor: AC 10 + dex
				armor_class_component.armor_type = ArmorClassComponent.ArmorType.NONE
				armor_class_component.armor_value = 10
				armor_class_component.equipped_armor = null
			1:
				# Leather armor: AC 11 + dex
				armor_class_component.equipped_armor = ArmorData.create_standard_armor("leather")
			2:
				# Chain shirt: AC 13 + dex (max 2)
				armor_class_component.equipped_armor = ArmorData.create_standard_armor("chain shirt")
		armor_class_component.refresh()
		
		# Update body color to match armor
		if _body is GoblinModel:
			var model: GoblinModel = _body as GoblinModel
			match armor_selection:
				0:
					model.set_armor_skin(GoblinModel.ArmorSkin.NONE)
				1:
					model.set_armor_skin(GoblinModel.ArmorSkin.LEATHER)
				2:
					model.set_armor_skin(GoblinModel.ArmorSkin.CHAIN)

	# Roll HP: 2d6
	max_hp = health_component.roll_max_health(2, 6, _rng)
	
	# Weapon: based on GameSettings selection for player, randomized for NPC goblins
	var weapon_names: Array[String] = ["Dagger", "Scimitar", "Shortbow"]
	var weapon_selection: int
	
	if is_playable:
		# Player goblin uses the selected weapon
		weapon_selection = GameSettings.selected_weapon_index
	else:
		# NPC goblins get randomized weapon
		weapon_selection = _rng.randi_range(0, weapon_names.size() - 1)
	
	weapon_selection = clampi(weapon_selection, 0, weapon_names.size() - 1)
	var chosen_weapon_name: String = weapon_names[weapon_selection]
	
	var wl = get_node_or_null("/root/ItemsAutoload")
	var weapon_to_equip: WeaponData = null
	if wl:
		for w in wl.weapons:
			if w.name == chosen_weapon_name:
				weapon_to_equip = w.duplicate()
				break
	
	if not weapon_to_equip:
		# Fallback if ItemsAutoload not ready or weapon not found
		match chosen_weapon_name:
			"Dagger":
				weapon_to_equip = WeaponData.new("Dagger", "2 gp", "1d4", "piercing", 1, "Finesse, light, thrown (range 10/30), ammo 5")
			"Scimitar":
				weapon_to_equip = WeaponData.new("Scimitar", "25 gp", "1d6", "slashing", 3, "Finesse, light")
			"Shortbow":
				weapon_to_equip = WeaponData.new("Shortbow", "25 gp", "1d6", "piercing", 2, "Ammunition (range 80/320), two-handed, ammo 20")
	
	if chosen_weapon_name == "Shortbow":
		var arrow_count: int = 0
		for i in range(2):
			arrow_count += _rng.randi_range(1, 10)
		weapon_to_equip.current_ammo = arrow_count
	
	_on_weapon_selected(weapon_to_equip)
	
	# Ability: based on GameSettings selection (0=Nimble Escape, 1=Redirect Attack)
	_setup_ability_from_settings()

func _setup_ability_from_settings() -> void:
	if not ability_component:
		return
	
	# Clear any existing actions (they were randomly added in AbilityComponent.setup)
	ability_component.actions.clear()
	
	# Get ability selection for player, randomized for NPC goblins (0=Nimble Escape, 1=Redirect Attack)
	var ability_selection: int
	
	if is_playable:
		# Player goblin uses the selected ability
		ability_selection = GameSettings.selected_ability_index
	else:
		# NPC goblins get randomized ability
		ability_selection = _rng.randi_range(0, 1)
	
	ability_selection = clampi(ability_selection, 0, 1)
	
	match ability_selection:
		0:
			# Nimble Escape: Hide and Disengage
			ability_component.add_action(preload("res://Components/ActorComponents/AbilityComponents/NimbleEscape.gd").new(self, ability_component))
		1:
			# Redirect Attack: Swap places with nearby ally
			ability_component.add_action(preload("res://Components/ActorComponents/AbilityComponents/RedirectAttack.gd").new(self, ability_component))
