class_name DamageComponent
extends Node

## A component that defines damage properties and can apply them to targets.

@export var damage_amount: float = 1.0
@export var element_type: String = "none"

## Attempts to deal damage to a target node if it has a HealthComponent.
func deal_damage(target: Node, direction: Vector3 = Vector3.ZERO) -> bool:
	if target.has_method("take_damage"):
		target.take_damage(damage_amount, element_type, direction)
		return true
		
	var health = find_health_component(target)
	if health:
		health.take_damage(damage_amount, element_type)
		return true
	
	return false

## Helper to apply an element effect to a node, with optional direction.
static func apply_element(target: Node, element: String, direction: Vector3 = Vector3.ZERO) -> bool:
	if not target: return false
	
	var handled = false
	if target.has_method("apply_element"):
		handled = target.apply_element(element, direction)
	
	# Global event for side effects/logging
	GameEvents.element_applied.emit(target, element, direction)
	
	return handled

## Helper to find a HealthComponent on a node or its children.
static func find_health_component(node: Node) -> HealthComponent:
	if not node: return null
	
	if node is HealthComponent:
		return node
		
	# Check direct children
	for child in node.get_children():
		if child is HealthComponent:
			return child
			
	return null
