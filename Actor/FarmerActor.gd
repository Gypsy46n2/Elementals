class_name FarmerActor
extends Actor

func _init() -> void:
	element_type = "farmer"
	should_bob = false
	max_hp = 4
	move_speed = 3.0

func _ready() -> void:
	super._ready()
	faction_component.setup(FactionComponent.Faction.FARMSTEAD)
	# Commoner stats (0 = base multiplier)
	ability_scores_component.strength = 0
	ability_scores_component.dexterity = 0
	ability_scores_component.constitution = 0
	ability_scores_component.intelligence = 0
	ability_scores_component.wisdom = 0
	ability_scores_component.charisma = 0

func _create_controller() -> ActorAIController:
	return FarmerController.new()

func get_actor_color() -> Color:
	return Color.YELLOW_GREEN

func herd_goat(goat: GoatActor) -> void:
	if goat.has_method("_scream"):
		goat.call("_scream")
	if goat.movement_component and controller:
		var center = (controller as FarmerController).farm_center
		var push_dir = (center - goat.global_position).normalized()
		goat.movement_component.apply_external_force(push_dir * 5.0)
