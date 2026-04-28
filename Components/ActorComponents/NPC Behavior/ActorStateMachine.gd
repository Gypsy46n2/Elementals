class_name ActorStateMachine
extends RefCounted

signal state_changed(new_state_name: String, old_state_name: String)
signal affected_state_changed(new_state_name: String, old_state_name: String)

var base_state: Variant
var affected_state: Variant
var states: Dictionary = {}  ## String -> AIState
var _base_state_name: String = ""
var _affected_state_name: String = ""

## The actor this state machine controls.
var actor: Node3D
## The AI controller that owns this state machine.
var controller: Variant

func register_state(name: String, state: Variant) -> void:
	state.state_machine = self
	state.actor = actor
	state.controller = controller
	states[name] = state

## Changes the underlying base state (Idle, Roam, Chase, etc.).
func change_state(name: String) -> void:
	if not states.has(name):
		push_error("ActorStateMachine: Base state not found: " + name)
		return
	if base_state:
		base_state.exit()
	var old_name: String = _base_state_name
	_base_state_name = name
	base_state = states[name]
	base_state.enter()
	state_changed.emit(name, old_name)
	## [Action Item] I'd like a console log here that says [ActorName] change state from [start state] to [end state']

## Applies an affected state that temporarily overrides the base state (Stunned, Frozen, etc.).
func change_affected_state(name: String) -> void:
	if not states.has(name):
		push_error("ActorStateMachine: Affected state not found: " + name)
		return
	if affected_state:
		affected_state.exit()
	var old_name: String = _affected_state_name
	_affected_state_name = name
	affected_state = states[name]
	affected_state.enter()
	affected_state_changed.emit(name, old_name)
	## [console log please]

## Clears the active affected state and resumes base state behavior.
func clear_affected_state() -> void:
	if affected_state:
		affected_state.exit()
		var old_name: String = _affected_state_name
		_affected_state_name = ""
		affected_state = null
		affected_state_changed.emit("", old_name)
		## console log

func update(delta: float) -> void:
	if affected_state:
		affected_state.update(delta)
	elif base_state:
		base_state.update(delta)

func physics_update(delta: float) -> void:
	if affected_state:
		affected_state.physics_update(delta)
	elif base_state:
		base_state.physics_update(delta)

## Returns the affected state name if active, otherwise the base state name.
func get_current_state_name() -> String:
	if _affected_state_name != "":
		return _affected_state_name
	return _base_state_name

func get_base_state_name() -> String:
	return _base_state_name

func get_affected_state_name() -> String:
	return _affected_state_name
