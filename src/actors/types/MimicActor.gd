class_name MimicActor
extends Actor

const MimicControllerScript = preload("res://src/actors/types/MimicController.gd")
const MimicShapechangeScript = preload("res://Components/ActorComponents/AbilityComponents/MimicShapechange.gd")
const MimicAmbushBiteScript = preload("res://Components/ActorComponents/AbilityComponents/MimicAmbushBite.gd")

func _init() -> void:
	element_type = "mimic"
	should_bob = false
	actor_size = Size.MEDIUM
	move_speed = 2.2
	armor_class = 12
	max_hp = 58.0
	# Wild mimics are hostile by default. Selected-player spawns override this.
	is_playable = false

func _ready() -> void:
	super._ready()
	if faction_component and not is_playable and faction_component.faction == FactionComponent.Faction.NEUTRAL:
		faction_component.setup(FactionComponent.Faction.MONSTERS)
	_apply_mimic_stat_profile()
	call_deferred("_equip_default_unarmed")
	_setup_ability_from_settings()
	call_deferred("_refresh_selected_ability_ui")

func _create_controller() -> ActorAIController:
	return MimicControllerScript.new()

func _equip_default_unarmed() -> void:
	if not weapon_component:
		return
	if weapon_component.weapon_data:
		return
	var wl: Node = get_node_or_null("/root/ItemsAutoload")
	if wl == null:
		return
	var weapons_value: Variant = wl.get("weapons")
	if typeof(weapons_value) != TYPE_ARRAY:
		return
	for w in (weapons_value as Array):
		if w.name == "Unarmed strike":
			weapon_component.weapon_data = w
			break

func get_actor_color() -> Color:
	return Color(0.44, 0.30, 0.18)

func take_damage(amount: float, type: String = "normal", direction: Vector3 = Vector3.ZERO) -> void:
	if String(type).to_lower().strip_edges() == "acid":
		return
	super.take_damage(amount, type, direction)

func die() -> void:
	var morph_component: Node = get_node_or_null("CreatureMorphComponent")
	if morph_component and morph_component.has_method("force_true_form"):
		morph_component.call("force_true_form")
	var skill_copy_component: Node = get_node_or_null("SkillCopyComponent")
	if skill_copy_component and skill_copy_component.has_method("restore"):
		skill_copy_component.call("restore")
	super.die()

func _apply_mimic_stat_profile() -> void:
	if ability_scores_component:
		ability_scores_component.strength = 3
		ability_scores_component.dexterity = 1
		ability_scores_component.constitution = 2
		ability_scores_component.intelligence = -3
		ability_scores_component.wisdom = 1
		ability_scores_component.charisma = -1

func _setup_ability_from_settings() -> void:
	if ability_component == null:
		return

	ability_component.actions.clear()

	var ability_selection: int
	if is_playable:
		ability_selection = GameSettings.selected_ability_index
	else:
		ability_selection = _rng.randi_range(0, 1)
	ability_selection = clampi(ability_selection, 0, 1)

	var action_instance: Variant
	match ability_selection:
		0:
			action_instance = MimicShapechangeScript.new(self, ability_component)
		1:
			action_instance = MimicAmbushBiteScript.new(self, ability_component)

	if action_instance is AbilityAction:
		ability_component.add_action(action_instance as AbilityAction)

func _refresh_selected_ability_ui() -> void:
	if not is_controlled or ability_component == null:
		return
	if ability_component.actions.is_empty():
		return
	if has_node("/root/ItemsAutoload"):
		ItemsAutoload.set_selected_ability(ability_component.actions[0].get_ability_data())
