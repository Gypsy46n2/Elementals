class_name ManaComponent
extends Node

signal mana_changed(new_mana: float, max_mana: float)

@export var max_mana: float = 100.0
@export var mana_regen_rate: float = 20.0
@export var shot_mana_cost: float = 20.0
@export var element_type: String = "none"

var current_mana: float = 100.0:
	set(value):
		var old_int = int(current_mana)
		current_mana = value
		if int(current_mana) != old_int:
			mana_changed.emit(current_mana, max_mana)

var _actor: Node3D

func setup(actor: Node3D) -> void:
	_actor = actor
	current_mana = max_mana
	if "element_type" in actor:
		element_type = actor.get("element_type")

func regenerate_mana(delta: float, multiplier: float = 1.0) -> void:
	var current_regen_mult = multiplier
	
	if _actor and _actor.has_method("is_on_floor") and _actor.is_on_floor():
		var tic = _actor.get("tile_interaction_component")
		if tic:
			var ground_tile = tic.get_ground_tile()
			if ground_tile:
				if element_type == "fire" and ground_tile.current_state == TileConstants.State.FIRE:
					current_regen_mult *= 2.0
				elif element_type == "water" and ground_tile.current_state == TileConstants.State.PUDDLE:
					current_regen_mult *= 2.0
					
	current_mana = min(current_mana + mana_regen_rate * current_regen_mult * delta, max_mana)


func use_mana(amount: float) -> bool:
	if current_mana >= amount:
		current_mana -= amount
		return true
	return false
