class_name GoatCharge
extends AbilityAction

func _init(p_actor: Actor, p_component: AbilityComponent) -> void:
	super(p_actor, p_component)
	ability_name = "Headbutt Charge"
	ability_description = "Charge forward with great speed, headbutting anything in your path. Deals damage and knockback."
	ability_usage = "Left Click while controlled."
	# Try to find a suitable icon or use default
	ability_icon = preload("res://assets/generated/thwak_popup_frame_0_1774916398.png")

func execute(type: String, value = null) -> void:
	if type == "charge" and actor.has_method("_start_charge"):
		var target_pos: Vector3 = value if value is Vector3 else Vector3.ZERO
		actor._start_charge(target_pos)
