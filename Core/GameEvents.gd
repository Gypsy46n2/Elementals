extends Node

# Actor/Combat Signals
signal actor_died(actor: Node3D)
signal element_applied(target: Node, element: String, direction: Vector3)

# Management/Economy Signals
signal gold_changed(new_amount: int)
signal herd_updated()
signal day_advanced(new_day: int)
signal day_finished()

# UI/Interaction Signals
signal actor_selection_toggled(actor: ActorData, is_selected: bool)
signal request_ui_update()
signal weapon_equipped(weapon: WeaponData)

# Deprecated: Use actor_selection_toggled instead
# signal goat_selection_toggled(goat: GoatData, is_selected: bool)

func emit_actor_died(actor: Node3D) -> void:
	actor_died.emit(actor)

func emit_element_applied(target: Node, element: String, direction: Vector3) -> void:
	element_applied.emit(target, element, direction)

func emit_gold_changed(new_amount: int) -> void:
	gold_changed.emit(new_amount)

func emit_herd_updated() -> void:
	herd_updated.emit()

func emit_day_advanced(new_day: int) -> void:
	day_advanced.emit(new_day)

func emit_day_finished() -> void:
	day_finished.emit()

func emit_actor_selection_toggled(actor: ActorData, is_selected: bool) -> void:
	actor_selection_toggled.emit(actor, is_selected)

func emit_request_ui_update() -> void:
	request_ui_update.emit()

func emit_weapon_equipped(weapon: WeaponData) -> void:
	weapon_equipped.emit(weapon)
