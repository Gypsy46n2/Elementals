class_name RangedComponent
extends Node

## Component responsible for launching projectiles and managing ranged attack logic.
## Separated from Weapon.gd to handle projectile instantiation and initialization.

var _weapon: Weapon
var _owner_actor: Actor
var _weapon_data: WeaponData

## Initializes the component with its parent weapon.
func setup(p_weapon: Weapon) -> void:
	_weapon = p_weapon
	_owner_actor = p_weapon._owner_actor

## Updates the weapon data used for projectile calculations.
func set_weapon_data(data: WeaponData) -> void:
	_weapon_data = data

## Spawns and initializes a projectile for ranged attacks.
func launch(target_position: Vector3, _dir: Vector3) -> void:
	if not _weapon_data or not _owner_actor: return
	
	var spawn_pos: Vector3 = _owner_actor.global_position + Vector3(0, 1.2, 0)
	var direction: Vector3 = (target_position - spawn_pos).normalized()
	
	# Determine projectile path based on weapon data
	var projectile_path: String = "res://Actor/Projectiles/ArrowProjectile.tscn"
	
	if _weapon_data.projectile_scene_path != "":
		projectile_path = _weapon_data.projectile_scene_path
	elif _weapon_data.name == "Dagger":
		projectile_path = "res://Actor/Projectiles/DaggerProjectile.tscn"
	elif "Javelin" in _weapon_data.name:
		# For now, Javelins use a slightly modified dagger or arrow. 
		# We'll stick with Arrow for now as it's long, or Dagger if it looks better.
		projectile_path = "res://Actor/Projectiles/ArrowProjectile.tscn"
	elif "Crossbow" in _weapon_data.name:
		projectile_path = "res://Actor/Projectiles/ArrowProjectile.tscn"
		
	var proj_scene: PackedScene = load(projectile_path)
	if not proj_scene:
		push_error("RangedComponent: Could not load projectile scene: " + projectile_path)
		return
		
	var proj: Node = proj_scene.instantiate()
	var parent: Node = _owner_actor.get_parent() if _owner_actor.get_parent() else _owner_actor.get_tree().current_scene
	parent.add_child(proj)
	
	proj.global_transform.origin = spawn_pos
	
	var damage: float = _weapon_data.roll_damage()
	var hex_size: float = _owner_actor._arena_grid.hex_size if _owner_actor._arena_grid else 1.5
	var proj_range: float = float(_weapon_data.range_max) * hex_size * 1.5
	
	if proj_range <= 0:
		proj_range = _owner_actor.projectile_max_range_in_tiles * hex_size * 1.5 # Fallback
	
	if proj.has_method("initialize"):
		proj.initialize(
			_owner_actor._arena_grid, 
			_owner_actor, 
			_owner_actor.global_position, 
			0.0, 
			direction, 
			_owner_actor.projectile_speed, 
			damage, 
			_owner_actor.projectile_lifetime, 
			proj_range
		)
		
	if "source_weapon_data" in proj:
		proj.source_weapon_data = _weapon_data
		
	# Apply specific scaling for heavy weapons like Greatclub
	if _weapon_data.name == "Greatclub":
		proj.scale = Vector3(1.5, 1.5, 1.5)
