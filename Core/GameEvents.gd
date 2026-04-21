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
signal goat_selection_toggled(goat: GoatData, is_selected: bool)
signal request_ui_update()
