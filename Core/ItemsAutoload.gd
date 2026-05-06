extends Node

signal weapon_selected(weapon: WeaponData)
signal ability_selected(ability: AbilityData)
signal goat_selected(goat: GoatData)
signal actor_selected(actor: Actor)

var weapons: Array[WeaponData] = []
var selected_weapon: WeaponData

var abilities: Array[AbilityData] = []
var selected_ability: AbilityData

var selected_goat: GoatData
var selected_actor: Actor

func _ready() -> void:
	_init_weapons()
	_init_abilities()

func _init_abilities() -> void:
	# Abilities are now largely actor-specific and initialized via AbilityAction scripts.
	# We keep the array for global reference if needed.
	pass

func _init_weapons() -> void:
	# Load all icons
	var club_icon = load("res://assets/generated/club_icon_frame_0_1776824494.png")
	var dagger_icon = load("res://assets/generated/dagger_icon_frame_0_1776824505.png")
	var greatclub_icon = load("res://assets/generated/greatclub_icon_frame_0_1776824509.png")
	var handaxe_icon = load("res://assets/generated/handaxe_icon_frame_0_1776824504.png")
	var javelin_icon = load("res://assets/generated/javelin_icon_frame_0_1777161398.png")
	var light_hammer_icon = load("res://assets/generated/light_hammer_icon_frame_0_1776824508.png")
	var mace_icon = load("res://assets/generated/mace_icon_frame_0_1776824498.png")
	var quarterstaff_icon = load("res://assets/generated/quarterstaff_icon_frame_0_1776824509.png")
	var sickle_icon = load("res://assets/generated/sickle_icon_frame_0_1776824508.png")
	var spear_icon = load("res://assets/generated/spear_icon_frame_0_1776824508.png")
	var unarmed_strike_icon = load("res://assets/generated/unarmed_strike_icon_frame_0_1776824523.png")
	var crossbow_light_icon = load("res://assets/generated/crossbow_light_icon_frame_0_1776824527.png")
	var dart_icon = load("res://assets/generated/dart_icon_frame_0_1776824526.png")
	var shortbow_icon = load("res://assets/generated/shortbow_icon_frame_0_1776824525.png")
	var sling_icon = load("res://assets/generated/sling_icon_frame_0_1776824526.png")
	var battleaxe_icon = load("res://assets/generated/battleaxe_icon_frame_0_1776824527.png")
	var flail_icon = load("res://assets/generated/flail_icon_frame_0_1776824527.png")
	var glaive_icon = load("res://assets/generated/glaive_icon_frame_0_1776824527.png")
	var greataxe_icon = load("res://assets/generated/greataxe_icon_frame_0_1776824527.png")
	var greatsword_icon = load("res://assets/generated/greatsword_icon_frame_0_1776824526.png")
	var halberd_icon = load("res://assets/generated/halberd_icon_frame_0_1776824542.png")
	var lance_icon = load("res://assets/generated/lance_icon_frame_0_1776824546.png")
	var longsword_icon = load("res://assets/generated/longsword_icon_frame_0_1776824542.png")
	var maul_icon = load("res://assets/generated/maul_icon_frame_0_1776824544.png")
	var morningstar_icon = load("res://assets/generated/morningstar_icon_frame_0_1776824544.png")
	var pike_icon = load("res://assets/generated/pike_icon_frame_0_1776824544.png")
	var rapier_icon = load("res://assets/generated/rapier_icon_frame_0_1776824556.png")
	var scimitar_icon = load("res://assets/generated/scimitar_icon_frame_0_1776824545.png")
	var shortsword_icon = load("res://assets/generated/shortsword_icon_frame_0_1776824545.png")
	var trident_icon = load("res://assets/generated/trident_icon_frame_0_1776824555.png")
	var war_pick_icon = load("res://assets/generated/war_pick_icon_frame_0_1776824573.png")
	var warhammer_icon = load("res://assets/generated/warhammer_icon_frame_0_1776824570.png")
	var whip_icon = load("res://assets/generated/whip_icon_frame_0_1776824571.png")
	var blowgun_icon = load("res://assets/generated/blowgun_icon_frame_0_1776824575.png")
	var crossbow_hand_icon = load("res://assets/generated/crossbow_hand_icon_frame_0_1776824578.png")
	var crossbow_heavy_icon = load("res://assets/generated/crossbow_heavy_icon_frame_0_1776824571.png")
	var longbow_icon = load("res://assets/generated/longbow_icon_frame_0_1776824572.png")
	var net_icon = load("res://assets/generated/net_icon_frame_0_1776824573.png")

	# Define weapons
	_add("Club", "1 sp", "1d4", "bludgeoning", 2, "Light", club_icon, "res://scenes/projectiles/ClubProjectile.tscn")
	_add("Dagger", "2 gp", "1d4", "piercing", 1, "Finesse, light, thrown (range 20/60), reach 1.5, cone 110, ammo 5", dagger_icon, "res://scenes/projectiles/DaggerProjectile.tscn")
	_add("Greatclub", "2 sp", "1d8", "bludgeoning", 10, "Two-handed", greatclub_icon, "res://scenes/projectiles/ClubProjectile.tscn")
	_add("Handaxe", "5 gp", "1d6", "slashing", 2, "Light, thrown (range 20/60), ammo 3", handaxe_icon, "res://scenes/projectiles/HandaxeProjectile.tscn")
	_add("Javelin", "5 sp", "1d6", "piercing", 2, "Thrown (range 15/60), cone 30, ammo 5", javelin_icon, "res://scenes/projectiles/JavelinProjectile.tscn")
	_add("Light hammer", "2 gp", "1d4", "bludgeoning", 2, "Light, thrown (range 10/30), ammo 3", light_hammer_icon)
	_add("Mace", "5 gp", "1d6", "bludgeoning", 4, "-", mace_icon)
	_add("Quarterstaff", "2 sp", "1d6", "bludgeoning", 4, "Versatile (1d8)", quarterstaff_icon)
	_add("Sickle", "1 gp", "1d4", "slashing", 2, "Light", sickle_icon)
	_add("Spear", "1 gp", "1d6", "piercing", 3, "Thrown (range 10/30), versatile (1d8)", spear_icon)
	_add("Unarmed strike", "0 gp", "1", "bludgeoning", 0, "-", unarmed_strike_icon)
	_add("Crossbow, light", "25 gp", "1d8", "piercing", 5, "Ammunition (range 80/320), loading, two-handed, ammo 20", crossbow_light_icon)
	_add("Dart", "5 cp", "1d4", "piercing", 0.25, "Finesse, thrown (range 10/30), ammo 20", dart_icon)
	_add("Shortbow", "25 gp", "1d6", "piercing", 2, "Ammunition (range 80/320), two-handed, ammo 20", shortbow_icon, "res://scenes/projectiles/ShortbowProjectile.tscn")
	_add("Sling", "1 sp", "1d4", "bludgeoning", 0, "Ammunition (range 30/120), ammo 20", sling_icon)
	_add("Battleaxe", "10 gp", "1d8", "slashing", 4, "Versatile (1d10)", battleaxe_icon)
	_add("Flail", "10 gp", "1d8", "bludgeoning", 2, "-", flail_icon)
	_add("Glaive", "20 gp", "1d10", "slashing", 6, "Heavy, reach, two-handed", glaive_icon)
	_add("Greataxe", "30 gp", "1d12", "slashing", 7, "Heavy, two-handed", greataxe_icon)
	_add("Greatsword", "50 gp", "2d6", "slashing", 6, "Heavy, two-handed", greatsword_icon)
	_add("Halberd", "20 gp", "1d10", "slashing", 6, "Heavy, reach, two-handed", halberd_icon)
	_add("Lance", "10 gp", "1d12", "piercing", 6, "Reach, special", lance_icon)
	_add("Longsword", "15 gp", "1d8", "slashing", 3, "Versatile (1d10)", longsword_icon)
	_add("Maul", "10 gp", "2d6", "bludgeoning", 10, "Heavy, two-handed", maul_icon)
	_add("Morningstar", "15 gp", "1d8", "piercing", 4, "-", morningstar_icon)
	_add("Pike", "5 gp", "1d10", "piercing", 18, "Heavy, reach, two-handed", pike_icon)
	_add("Rapier", "25 gp", "1d8", "piercing", 2, "Finesse", rapier_icon)
	_add("Scimitar", "25 gp", "1d6", "slashing", 3, "Finesse, light", scimitar_icon, "res://scenes/projectiles/ScimitarProjectile.tscn")
	_add("Shortsword", "10 gp", "1d6", "piercing", 2, "Finesse, light", shortsword_icon)
	_add("Trident", "5 gp", "1d6", "piercing", 4, "Thrown (range 10/30), versatile (1d8)", trident_icon)
	_add("War pick", "5 gp", "1d8", "piercing", 2, "-", war_pick_icon)
	_add("Warhammer", "15 gp", "1d8", "bludgeoning", 2, "Versatile (1d10)", warhammer_icon)
	_add("Whip", "2 gp", "1d4", "slashing", 3, "Finesse, reach", whip_icon)
	_add("Blowgun", "10 gp", "1", "piercing", 1, "Ammunition (range 25/100), loading, ammo 20", blowgun_icon)
	_add("Crossbow, hand", "75 gp", "1d6", "piercing", 3, "Ammunition (range 30/120), light, loading, ammo 20", crossbow_hand_icon)
	_add("Crossbow, heavy", "50 gp", "1d10", "piercing", 18, "Ammunition (range 100/400), heavy, loading, two-handed, ammo 20", crossbow_heavy_icon)
	_add("Longbow", "50 gp", "1d8", "piercing", 2, "Ammunition (range 150/600), heavy, two-handed, ammo 20", longbow_icon)
	_add("Net", "1 gp", "-", "none", 3, "Thrown (range 5/15), special", net_icon)
	
	for w in weapons:
		if w.name == "Unarmed strike":
			selected_weapon = w
			break

func _add(p_name: String, p_cost: String, p_damage: String, p_type: String, p_weight: float, p_notes: String, p_icon: Texture2D, p_proj: String = "") -> void:
	var w = WeaponData.new(p_name, p_cost, p_damage, p_type, p_weight, p_notes, p_proj)
	w.icon = p_icon
	weapons.append(w)

func set_selected_weapon(weapon: WeaponData) -> void:
	selected_weapon = weapon
	weapon_selected.emit(weapon)

func set_selected_ability(ability: AbilityData) -> void:
	selected_ability = ability
	ability_selected.emit(ability)

func set_selected_goat(goat: GoatData) -> void:
	selected_goat = goat
	goat_selected.emit(goat)

func set_selected_actor(actor: Actor) -> void:
	selected_actor = actor
	actor_selected.emit(actor)
	if actor and actor is GoatActor:
		set_selected_goat(actor.goat_data)
	else:
		set_selected_goat(null)
