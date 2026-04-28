class_name StunComponent
extends Node

signal stun_started(duration: float)
signal stun_ended()

var _stun_timer: float = 0.0
var _stun_visual: Node3D
var _actor: Node3D

func setup(actor: Node3D) -> void:
	_actor = actor
	_setup_stun_visuals()

func _setup_stun_visuals() -> void:
	# StunVisual3D should be globally accessible or preloaded
	# Assuming it's available or we can use a placeholder if not
	_stun_visual = StunVisual3D.new()
	_stun_visual.position = Vector3(0, 1.2, 0)
	_stun_visual.visible = false
	_stun_visual.set_process(false)
	_actor.add_child(_stun_visual)

func _process(delta: float) -> void:
	update_stun(delta)

func stun(duration: float) -> void:
	var was_stunned: bool = is_stunned()
	_stun_timer = max(_stun_timer, duration)
	if not was_stunned:
		stun_started.emit(duration)

func is_stunned() -> bool:
	return _stun_timer > 0.0

func update_stun(delta: float) -> void:
	if _stun_timer > 0:
		_stun_timer -= delta
		if _stun_visual and not _stun_visual.visible:
			_stun_visual.visible = true
			_stun_visual.set_process(true)
		if _stun_timer <= 0:
			_stun_timer = 0.0
			stun_ended.emit()
			if _stun_visual and _stun_visual.visible:
				_stun_visual.visible = false
				_stun_visual.set_process(false)
	else:
		if _stun_visual and _stun_visual.visible:
			_stun_visual.visible = false
			_stun_visual.set_process(false)
