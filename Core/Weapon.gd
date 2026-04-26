## Component responsible for handling weapon logic, including attacking, 
## ammo management, and visual representation of the weapon in 3D space.
## It handles both melee and ranged weapons and integrates with the ItemsAutoload system.
class_name Weapon
extends Node3D

@onready var _whack_player: AudioStreamPlayer3D = get_node_or_null("WhackPlayer")
@onready var _swoosh_player: AudioStreamPlayer3D = get_node_or_null("SwooshPlayer")

var weapon_data: WeaponData:
	set(v):
		weapon_data = v
		if _melee_hitbox: _melee_hitbox.set_weapon_data(v)
		if _ranged_component: _ranged_component.set_weapon_data(v)
		if _visual_component: _visual_component.set_weapon_data(v)
		if weapon_data:
			current_ammo = weapon_data.max_ammo

var _cooldown: float = 0.0
var _melee_hitbox: MeleeHitbox
var _ranged_component: RangedComponent
var _visual_component: WeaponVisualComponent
var _owner_actor: Actor
var current_ammo: int = -1

## Initializes the weapon component and links it to an Actor.
func setup(actor: Actor) -> void:
	_owner_actor = actor
	
	_melee_hitbox = MeleeHitbox.new()
	_melee_hitbox.name = "MeleeHitbox"
	add_child(_melee_hitbox)
	
	_ranged_component = RangedComponent.new()
	_ranged_component.name = "RangedComponent"
	add_child(_ranged_component)
	
	_visual_component = WeaponVisualComponent.new()
	_visual_component.name = "WeaponVisualComponent"
	add_child(_visual_component)
	
	_melee_hitbox.setup(self)
	_ranged_component.setup(self)
	_visual_component.setup(self)

	if weapon_data:
		self.weapon_data = weapon_data # Trigger setter to sync sub-components
	
	var wl = get_node_or_null("/root/ItemsAutoload")
	if wl:
		wl.weapon_selected.connect(_on_global_weapon_selected)
		if _owner_actor.is_controlled and wl.selected_weapon:
			_on_weapon_selected(wl.selected_weapon)
	
	# Try to find audio players on the owner if not on self
	if not _whack_player: _whack_player = _owner_actor.get_node_or_null("WhackPlayer")
	if not _swoosh_player: _swoosh_player = _owner_actor.get_node_or_null("SwooshPlayer")

## Internal handler for global weapon selection signals.
func _on_global_weapon_selected(p_weapon: WeaponData) -> void:
	if _owner_actor and _owner_actor.is_controlled:
		_on_weapon_selected(p_weapon)

## Updates the weapon's current WeaponData and refreshes its visuals.
func _on_weapon_selected(p_weapon: WeaponData) -> void:
	weapon_data = p_weapon

## Adds ammo to the current weapon or equips it if the actor is unarmed.
func add_weapon_ammo(p_weapon_data: WeaponData, amount: int) -> void:
	if weapon_data == p_weapon_data:
		current_ammo = min(current_ammo + amount, p_weapon_data.max_ammo)
	elif weapon_data and weapon_data.name == "Unarmed strike":
		_on_weapon_selected(p_weapon_data)
		current_ammo = amount

## Reverts the actor to an "Unarmed strike" state.
func unequip_weapon() -> void:
	var wl = get_node_or_null("/root/ItemsAutoload")
	if wl:
		for w in wl.weapons:
			if w.name == "Unarmed strike":
				_on_weapon_selected(w)
				break

## Spawns the current weapon as a physical pickup in the world and unequips it.
func drop_inventory() -> void:
	if not weapon_data or weapon_data.name == "Unarmed strike":
		return
		
	if not _owner_actor or not _owner_actor._arena_grid: return
	
	var projectile_path = weapon_data.projectile_scene_path
	if projectile_path == "":
		projectile_path = "res://Actor/Projectiles/ArrowProjectile.tscn"
		
	var proj_scene = load(projectile_path)
	if not proj_scene: return
	
	var drop = proj_scene.instantiate()
	_owner_actor.get_parent().add_child(drop)
	drop.global_position = _owner_actor.global_position + Vector3(0, 0.5, 0)
	
	if drop.has_method("initialize"):
		drop.initialize(_owner_actor._arena_grid, _owner_actor, _owner_actor.global_position, 0.0, Vector3.FORWARD, 0.0, 1, 100.0)
	
	drop.set("source_weapon_data", weapon_data)
	drop.set("remaining_charges", current_ammo)
	
	if drop.has_method("_stick"):
		drop.call("_stick") # Make it a pickup
	
	unequip_weapon()

func _process(delta: float) -> void:
	if _cooldown > 0:
		_cooldown -= delta

func is_on_cooldown() -> bool:
	return _cooldown > 0

func get_cooldown_progress() -> float:
	if weapon_data and weapon_data.cooldown > 0:
		return 1.0 - (_cooldown / weapon_data.cooldown)
	return 1.0

func _can_attack() -> bool:
	return _owner_actor and not is_on_cooldown() and not _owner_actor.is_stunned() and weapon_data != null

## Initiates an attack towards the specified target position.
func swing(target_pos: Vector3) -> bool:
	if not _can_attack(): return false
	_perform_attack(target_pos, false)
	return true

## Initiates a secondary attack (typically throwing the current weapon).
func secondary_attack(target_pos: Vector3, forced: bool = false) -> bool:
	if not _can_attack(): return false
	if not forced and not weapon_data.is_thrown: return false
	if current_ammo == 0: return false
	
	_perform_attack(target_pos, true)
	return true

func _perform_attack(target_pos: Vector3, is_secondary: bool) -> void:
	_cooldown = weapon_data.cooldown
	
	var dir = (target_pos - _owner_actor.global_position).normalized()
	dir.y = 0
	
	if _swoosh_player: _swoosh_player.play()
	
	if is_secondary or weapon_data.is_ranged:
		_ranged_component.launch(target_pos, dir)
		_visual_component.animate_throw(weapon_data.cooldown, current_ammo)
		
		if is_secondary and current_ammo > 0:
			current_ammo -= 1
			if current_ammo == 0:
				_owner_actor.unequip_weapon()
	else:
		_melee_hitbox.perform_swing(dir)
		_visual_component.animate_swing(dir)
