class_name CommunicationComponent
extends Node

## Base component for Actor-to-Actor call and response communication.
## Extend this to create specific communication types (screams, calls, alerts, etc.)

@export_group("Communication Settings")
## Maximum distance at which other actors can receive this communication.
@export var range: float = 15.0
## Probability (0.0-1.0) that this actor will respond to a received communication.
@export var probability: float = 0.25
## Minimum delay before responding to a received communication.
@export var response_delay_min: float = 0.3
## Maximum delay before responding to a received communication.
@export var response_delay_max: float = 1.2

## Maximum number of concurrent pending responses across all instances.
@export var max_concurrent_responses: int = 10

## The signal name this component broadcasts when communicating.
@export var broadcast_signal_name: StringName = &"communication_received"

static var _pending_response_count: int = 0

var actor: Actor

## Track pending responses to prevent response spam.
var pending_responses: int = 0

func setup(p_actor: Actor) -> void:
	actor = p_actor

func _ready() -> void:
	if not actor:
		push_error("CommunicationComponent: actor not set. Call setup() first.")
		return
	
	_connect_to_actor_broadcast()

## Override in subclasses to define what happens when this actor broadcasts.
func _get_broadcast_position() -> Vector3:
	return actor.global_position

## Override in subclasses to add conditions for whether this actor can respond.
## Return false to prevent response entirely.
func _can_respond_to(source_pos: Vector3) -> bool:
	return true

## Override in subclasses to add additional checks before responding.
## Return false to skip the response.
func _should_respond(source_actor: Actor, source_pos: Vector3) -> bool:
	return true

## Override in subclasses to define the actual response behavior.
func _execute_response(source_actor: Actor, source_pos: Vector3) -> void:
	pass

## Call this when the actor wants to initiate communication.
func broadcast() -> void:
	if not can_broadcast():
		return
	
	_perform_broadcast()
	_finish_broadcast()

## Check if this actor can currently broadcast.
func can_broadcast() -> bool:
	return true

## Override in subclasses to add conditions for broadcast (cooldowns, states, etc.).
func _can_broadcast() -> bool:
	return true

func _perform_broadcast() -> void:
	# Emit the broadcast signal on the actor
	actor.emit_signal(broadcast_signal_name, _get_broadcast_position(), self)

func _finish_broadcast() -> void:
	pass

## Called by other actors when they receive this communication.
func try_respond_to(source_pos: Vector3, source_component: CommunicationComponent) -> void:
	# Check if we can respond
	if not _can_respond_to(source_pos):
		return
	
	# Check range
	if source_pos.distance_to(actor.global_position) >= range:
		return
	
	# Check probability
	if randf() >= probability:
		return
	
	# Check concurrent limit
	if _pending_response_count >= max_concurrent_responses:
		return
	
	# Check source actor
	var source_actor = source_component.actor if source_component else null
	if source_actor and not _should_respond(source_actor, source_pos):
		return
	
	# Queue the response with random delay
	_pending_response_count += 1
	pending_responses += 1
	
	var delay := randf_range(response_delay_min, response_delay_max)
	var timer := actor.get_tree().create_timer(delay)
	timer.timeout.connect(_on_response_timer_timeout.bind(source_actor, source_pos, source_component))

func _on_response_timer_timeout(source_actor: Actor, source_pos: Vector3, source_component: CommunicationComponent) -> void:
	_pending_response_count -= 1
	pending_responses = max(0, pending_responses - 1)
	
	if not is_instance_valid(actor):
		return
	
	if source_actor and not is_instance_valid(source_actor):
		return
	
	# Final check before executing response
	if _should_respond(source_actor, source_pos):
		_execute_response(source_actor, source_pos)

## Connect to the actor's broadcast signal to receive communications from others.
func _connect_to_actor_broadcast() -> void:
	# Get all other actors and connect to their broadcast signals
	var tree := actor.get_tree()
	
	# Connect to node added to auto-connect new actors
	tree.node_added.connect(_on_node_added)

func _on_node_added(node: Node) -> void:
	if node is Actor and node != actor:
		_connect_to_actor(node)

func _connect_to_actor(other_actor: Actor) -> void:
	var other_comm := other_actor.get("communication_component") as CommunicationComponent
	if other_comm and other_comm.broadcast_signal_name == broadcast_signal_name:
		if not other_actor.has_signal(broadcast_signal_name):
			return
		# Check if already connected
		var method := "_on_communication_received"
		if not _is_connected_to_signal(other_actor, broadcast_signal_name, method):
			other_actor.connect(broadcast_signal_name, Callable(self, method), Object.CONNECT_ONE_SHOT)

func _is_connected_to_signal(source: Object, signal_name: StringName, method: String) -> bool:
	return source.has_signal(signal_name) and source.has_user_signal(method)

func _on_communication_received(source_pos: Vector3, source_component: CommunicationComponent) -> void:
	if source_component and source_component.actor == actor:
		return  # Don't respond to self
	try_respond_to(source_pos, source_component)
