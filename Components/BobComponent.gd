class_name BobComponent
extends Node

@export var bob_amplitude: float = 0.35
@export var bob_speed: float = 2.2
@export var should_bob: bool = true

var _bob_phase: float = 0.0
var _base_visual_y: float = 0.0
var _target_node: Node3D
var _mana_particles_container: Node3D

func setup(target: Node3D, base_y: float, mana_container: Node3D = null) -> void:
	_target_node = target
	_base_visual_y = base_y
	_mana_particles_container = mana_container

func _physics_process(delta: float) -> void:
	apply_bob(delta)

func apply_bob(delta: float) -> void:
	var bob_offset: float = 0.0
	if should_bob:
		_bob_phase += bob_speed * delta
		bob_offset = sin(_bob_phase) * bob_amplitude
	
	if _target_node:
		_target_node.position.y = _base_visual_y + bob_offset
	
	if _mana_particles_container:
		_mana_particles_container.position.y = _base_visual_y + bob_offset
