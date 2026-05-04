class_name FactionComponent
extends Node

enum Faction {
	PLAYER,
	GOBLINS,
	FARMSTEAD,
	WILDLIFE,
	NEUTRAL,
	MONSTERS
}

@export var faction: Faction = Faction.NEUTRAL

var _enemy_cache: Dictionary = {}
var _ally_cache: Dictionary = {}

func setup(p_faction: Faction) -> void:
	faction = p_faction
	clear_cache()

func is_ally(other: Node) -> bool:
	if not is_instance_valid(other):
		return false
		
	if _ally_cache.has(other):
		return _ally_cache[other]
	
	var result: bool = _compute_is_ally(other)
	_ally_cache[other] = result
	return result

func is_enemy(other: Node) -> bool:
	if not is_instance_valid(other):
		return false
		
	if _enemy_cache.has(other):
		return _enemy_cache[other]
	
	var result: bool = _compute_is_enemy(other)
	_enemy_cache[other] = result
	return result

func clear_cache() -> void:
	_enemy_cache.clear()
	_ally_cache.clear()

func _compute_is_ally(other: Node) -> bool:
	if not other: return false
	
	var other_faction_comp: FactionComponent = _get_faction_component(other)
	if not other_faction_comp:
		# Fallback for actors without a faction component yet
		if other.get("is_friendly") != null:
			return _is_friendly_to_faction(other.get("is_friendly"))
		return false
		
	# Same faction are always allies
	if other_faction_comp.faction == faction:
		return true
		
	# Cross-faction alliances
	match faction:
		Faction.PLAYER:
			return other_faction_comp.faction == Faction.FARMSTEAD
		Faction.FARMSTEAD:
			return other_faction_comp.faction == Faction.PLAYER
			
	return false

func _compute_is_enemy(other: Node) -> bool:
	if not other: return false
	if other == get_parent(): return false
	
	var other_faction_comp: FactionComponent = _get_faction_component(other)
	if not other_faction_comp:
		# Fallback
		if other.get("is_friendly") != null:
			return not _is_friendly_to_faction(other.get("is_friendly"))
		return false
		
	if other_faction_comp.faction == Faction.NEUTRAL or faction == Faction.NEUTRAL:
		return false
		
	return not is_ally(other)

func _get_faction_component(node: Node) -> FactionComponent:
	if node.get("faction_component"):
		return node.faction_component as FactionComponent
	return node.get_node_or_null("FactionComponent") as FactionComponent

func _is_friendly_to_faction(other_is_friendly: bool) -> bool:
	match faction:
		Faction.PLAYER, Faction.FARMSTEAD:
			return other_is_friendly
		Faction.GOBLINS, Faction.WILDLIFE:
			return not other_is_friendly
	return false
