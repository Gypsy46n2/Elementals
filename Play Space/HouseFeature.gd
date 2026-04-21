class_name HouseFeature
extends Node3D

@onready var sprite: Sprite3D = $Sprite3D
@onready var collision_body: StaticBody3D = $StaticBody3D

var health_component: HealthComponent
var tile: HexTileData

func _ready() -> void:
	_setup_health_component()
	if sprite:
		sprite.texture = preload("res://assets/generated/farm_house_frame_0_1776586173.png")

func _setup_health_component() -> void:
	health_component = DamageComponent.find_health_component(self)
	if not health_component:
		health_component = HealthComponent.new()
		add_child(health_component)
	
	health_component.max_health = 50.0
	health_component.current_health = 50.0
	health_component.bar_color = Color.BLUE
	health_component.bar_offset = Vector3(0, 3.5, 0)
	health_component.health_depleted.connect(_on_health_depleted)

func _on_health_depleted() -> void:
	# House destroyed logic (e.g. fire, game over condition)
	print("The Farm House has been destroyed!")
	queue_free()

func set_tile(p_tile: HexTileData) -> void:
	tile = p_tile

func apply_element(element: String, _direction: Vector3 = Vector3.ZERO) -> bool:
	if element == "fire":
		take_damage(5.0, true)
		return true
	return false

func take_damage(amount: float, is_fire: bool) -> void:
	if health_component:
		health_component.take_damage(amount, "fire" if is_fire else "normal")
