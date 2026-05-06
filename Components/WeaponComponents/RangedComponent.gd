## Component responsible for launching projectiles and managing ranged attack logic.
## Separated from Weapon.gd to handle projectile instantiation and initialization.
extends Node

signal projectile_launched(is_secondary: bool)

var _weapon: Node3D
var _owner_actor: Node3D
var _weapon_data: WeaponData

## Initializes the component with its parent weapon.
func setup(p_weapon: Node3D) -> void:
	_weapon = p_weapon
	_owner_actor = p_weapon.get("_owner_actor")

## Updates the weapon data used for projectile calculations.
func set_weapon_data(data: WeaponData) -> void:
	_weapon_data = data

## Adds ammo to the current weapon.
func add_ammo(p_weapon_data: WeaponData, amount: int) -> void:
	if not _weapon or not _weapon.has_method("add_weapon_ammo"): return
	_weapon.call("add_weapon_ammo", p_weapon_data, amount)

## Spawns and initializes a projectile for ranged attacks.
func launch(target_position: Vector3, _dir: Vector3, is_secondary: bool = false) -> void:
	if not _weapon_data or not _owner_actor: return
	
	var spawn_pos: Vector3 = _owner_actor.global_position + Vector3(0, 1.2, 0)
	var direction: Vector3 = (target_position - spawn_pos).normalized()
	
	# Determine projectile path based on weapon data
	var projectile_path: String = "res://scenes/projectiles/ArrowProjectile.tscn"
	
	if "bow" in _weapon_data.name.to_lower() or "crossbow" in _weapon_data.name.to_lower():
		projectile_path = "res://scenes/projectiles/ArrowProjectile.tscn"
	elif _weapon_data.projectile_scene_path != "":
		projectile_path = _weapon_data.projectile_scene_path
	elif _weapon_data.name == "Dagger" or "Dagger" in _weapon_data.name:
		projectile_path = "res://scenes/projectiles/DaggerProjectile.tscn"
	elif "Javelin" in _weapon_data.name:
		projectile_path = "res://scenes/projectiles/JavelinProjectile.tscn"
	elif "Crossbow" in _weapon_data.name:
		projectile_path = "res://scenes/projectiles/ArrowProjectile.tscn"
		
	var proj_scene: PackedScene = load(projectile_path)
	if not proj_scene:
		push_error("RangedComponent: Could not load projectile scene: " + projectile_path)
		return
		
	var proj: Node = proj_scene.instantiate()
	var parent: Node = _owner_actor.get_parent() if _owner_actor.get_parent() else _owner_actor.get_tree().current_scene
	parent.add_child(proj)
	
	proj.global_transform.origin = spawn_pos
	
	var damage: float = _weapon_data.roll_damage()
	var arena_grid = _owner_actor.get("_arena_grid")
	var hex_size: float = arena_grid.hex_size if arena_grid else 1.5
	var proj_range: float = float(_weapon_data.range_max) * hex_size * 1.5
	
	if proj_range <= 0:
		proj_range = _owner_actor.get("projectile_max_range") # Fallback
	
	# Determine how many tiles this projectile can affect.
	# For physical weapons like Daggers/Arrows, this is usually 1.
	# For elemental weapons, it might be more.
	var max_charges: int = 1
	var dtype = _weapon_data.damage_type.to_lower()
	if dtype in ["fire", "water", "ice", "poison", "lightning", "acid"]:
		max_charges = 5
	
	var p_speed: float = _owner_actor.get("projectile_speed") if _owner_actor.get("projectile_speed") != null else 14.0
	var p_lifetime: float = _owner_actor.get("projectile_lifetime") if _owner_actor.get("projectile_lifetime") != null else 5.0
	
	if proj.has_method("initialize_lob") and is_secondary:
		proj.call("initialize_lob", 
			arena_grid, 
			_owner_actor, 
			_owner_actor.global_position, 
			target_position,
			p_speed, 
			max_charges, 
			p_lifetime,
			damage
		)
	elif proj.has_method("initialize"):
		proj.initialize(
			arena_grid, 
			_owner_actor, 
			_owner_actor.global_position, 
			0.0, 
			direction, 
			p_speed, 
			max_charges, 
			p_lifetime, 
			proj_range,
			damage
		)
		
	if "source_weapon_data" in proj:
		proj.source_weapon_data = _weapon_data
		
	# Apply specific scaling for heavy weapons like Greatclub
	if _weapon_data.name == "Greatclub":
		proj.scale = Vector3(1.5, 1.5, 1.5)
	
	projectile_launched.emit(is_secondary)
