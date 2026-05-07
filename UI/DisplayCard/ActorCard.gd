class_name ActorCard
extends DisplayCardBase

@onready var actor_renderer: GoatRenderer = $VBoxContainer/GoatRenderer
@onready var name_edit: LineEdit = $VBoxContainer/TopRow/NameEdit
@onready var info_label: Label = $VBoxContainer/InfoLabel
@onready var str_label: Label = $VBoxContainer/StatsGrid/StrLabel
@onready var dex_label: Label = $VBoxContainer/StatsGrid/DexLabel
@onready var con_label: Label = $VBoxContainer/StatsGrid/ConLabel
@onready var int_label: Label = $VBoxContainer/StatsGrid/IntLabel
@onready var wis_label: Label = $VBoxContainer/StatsGrid/WisLabel
@onready var cha_label: Label = $VBoxContainer/StatsGrid/ChaLabel
@onready var ac_label: Label = $VBoxContainer/ACLabel
@onready var arena_checkbox: CheckBox = $VBoxContainer/ArenaCheckBox

var actor_resource: GoatData:
	get:
		return data_resource as GoatData
	set(v):
		setup(v)

# Alias for compatibility with existing code
var goat_data: GoatData:
	get: return actor_resource
	set(v): actor_resource = v

var _actor: Actor

func set_actor(p_actor: Actor) -> void:
	if _actor:
		if _actor.health_component and _actor.health_component.health_changed.is_connected(_on_actor_stats_changed):
			_actor.health_component.health_changed.disconnect(_on_actor_stats_changed)
		if _actor.mana_changed.is_connected(_on_actor_mana_changed):
			_actor.mana_changed.disconnect(_on_actor_mana_changed)
	
	_actor = p_actor
	
	if _actor:
		if _actor is GoatActor:
			setup(_actor.goat_data)
		else:
			data_resource = null
			if _actor.health_component:
				_actor.health_component.health_changed.connect(_on_actor_stats_changed)
			_actor.mana_changed.connect(_on_actor_mana_changed)
			_update_ui()

func _on_actor_stats_changed(_hp: float, _mhp: float) -> void:
	_update_ui()

func _on_actor_mana_changed(_m: float, _mm: float) -> void:
	_update_ui()

func setup(p_data: Resource) -> void:
	if actor_resource:
		if actor_resource.stats_changed.is_connected(_update_ui):
			actor_resource.stats_changed.disconnect(_update_ui)
	
	super.setup(p_data)
	
	if actor_resource:
		actor_resource.stats_changed.connect(_update_ui)

func _ready() -> void:
	super._ready()
	_update_ui()
	arena_checkbox.toggled.connect(_on_arena_toggled)
	
	if name_edit:
		name_edit.text_submitted.connect(_on_name_submitted)
		name_edit.focus_exited.connect(_on_name_focus_exited)

func _update_ui() -> void:
	if not is_node_ready(): return
	
	if actor_resource:
		_update_resource_ui()
	elif _actor:
		_update_node_ui()
	else:
		visible = false

func _update_resource_ui() -> void:
	actor_renderer.visible = true
	actor_renderer.goat_data = actor_resource
	
	if not name_edit.has_focus():
		name_edit.text = actor_resource.goat_name
	
	var gender_str = "Female" if actor_resource.gender == ActorData.Gender.FEMALE else "Male"
	info_label.text = "%s - Lvl: %d - Age: %d" % [gender_str, actor_resource.level, actor_resource.age_days]
	
	if actor_resource.is_pregnant:
		info_label.text += " [P]"
	if actor_resource.is_exhausted:
		info_label.text += " [E]"
		
	_display_ability_scores(
		actor_resource.strength, 
		actor_resource.dexterity, 
		actor_resource.constitution,
		actor_resource.intelligence, 
		actor_resource.wisdom, 
		actor_resource.charisma
	)
	
	# Goats in resource form usually don't have armor components, so we show base AC
	var dex_mod = int(actor_resource.dexterity)
	ac_label.text = "AC: %d (Base)" % (10 + dex_mod)
	
	arena_checkbox.visible = true
	arena_checkbox.set_pressed_no_signal(actor_resource.is_selected)
	arena_checkbox.disabled = actor_resource.is_exhausted and not actor_resource.is_selected
	
	update_visual_state()

func _update_node_ui() -> void:
	actor_renderer.visible = false
	
	if not name_edit.has_focus():
		name_edit.text = _actor.name
	
	var hp = 0.0
	var mhp = 0.0
	if _actor.health_component:
		hp = _actor.health_component.current_health
		mhp = _actor.health_component.max_health
		
	info_label.text = "HP: %d/%d | MP: %d/%d" % [int(hp), int(mhp), int(_actor.current_mana), int(_actor.max_mana)]
	
	if _actor.ability_scores_component:
		var asc = _actor.ability_scores_component
		_display_ability_scores(asc.strength, asc.dexterity, asc.constitution, asc.intelligence, asc.wisdom, asc.charisma)
	
	if _actor.armor_class_component:
		var acc = _actor.armor_class_component
		var ac = acc.calculate_ac()
		var armor_name = "None"
		if acc.equipped_armor:
			armor_name = acc.equipped_armor.name
		elif acc.armor_type != ArmorClassComponent.ArmorType.NONE:
			armor_name = ArmorClassComponent.ArmorType.keys()[acc.armor_type]
		
		if acc.equipped_shield or acc.has_shield:
			armor_name += " + Shield"
			
		ac_label.text = "AC: %d (%s)" % [ac, armor_name]
	else:
		ac_label.text = "AC: %d" % _actor.armor_class
		
	arena_checkbox.visible = false
	modulate = base_color

func _display_ability_scores(p_str: float, p_dex: float, p_con: float, p_int: float, p_wis: float, p_cha: float) -> void:
	str_label.text = "STR: %d" % int(p_str)
	dex_label.text = "DEX: %d" % int(p_dex)
	con_label.text = "CON: %d" % int(p_con)
	int_label.text = "INT: %d" % int(p_int)
	wis_label.text = "WIS: %d" % int(p_wis)
	cha_label.text = "CHA: %d" % int(p_cha)

func _is_selected() -> bool:
	return actor_resource and actor_resource.is_selected

func update_visual_state() -> void:
	if not actor_resource: return
	
	if actor_resource.is_selected:
		modulate = highlight_color
	else:
		modulate = Color(0.7, 0.7, 0.7) if actor_resource.is_exhausted else base_color

func _on_arena_toggled(pressed: bool) -> void:
	if not actor_resource: return
	if pressed != actor_resource.is_selected:
		_toggle_arena_selection()

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if name_edit.get_global_rect().has_point(event.global_position):
			return
		if arena_checkbox.get_global_rect().has_point(event.global_position):
			return
			
		_handle_selection()
		accept_event()

func _handle_selection() -> void:
	super._handle_selection()

func _toggle_arena_selection() -> void:
	HerdManager.toggle_selection(actor_resource)

func _on_name_submitted(new_text: String) -> void:
	if actor_resource:
		actor_resource.goat_name = new_text
	name_edit.release_focus()

func _on_name_focus_exited() -> void:
	if actor_resource:
		actor_resource.goat_name = name_edit.text
