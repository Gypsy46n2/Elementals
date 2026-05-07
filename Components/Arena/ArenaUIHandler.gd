## Component that manages the Arena's UI elements related to character status and control.
## It handles the reticle, health/mana labels, and main UI buttons.
class_name ArenaUIHandler
extends Node

var arena: Node3D # ArenaGrid

var target_label: Label
var prev_button: Button
var next_button: Button
var options_menu: OptionsMenu
var options_button: Button
var reticle: Control

var _current_actor: Actor

func setup(p_arena: Node3D) -> void:
	arena = p_arena
	
	target_label = arena.get_node_or_null("UI/HBoxContainer/TargetLabel")
	prev_button = arena.get_node_or_null("UI/HBoxContainer/PrevButton")
	next_button = arena.get_node_or_null("UI/HBoxContainer/NextButton")
	options_menu = arena.get_node_or_null("UI/OptionsMenu")
	options_button = arena.get_node_or_null("UI/OptionsButton")
	
	_setup_reticle()
	_setup_ui_connections()

func _setup_reticle() -> void:
	var canvas_layer = CanvasLayer.new()
	canvas_layer.name = "ReticleLayer"
	add_child(canvas_layer)
	
	reticle = Control.new()
	reticle.set_script(preload("res://Player/Reticle.gd"))
	reticle.size = Vector2(64, 64)
	reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas_layer.add_child(reticle)

func _setup_ui_connections() -> void:
	if prev_button:
		prev_button.focus_mode = Control.FOCUS_NONE
		prev_button.pressed.connect(arena.player_input.previous_actor)
	if next_button:
		next_button.focus_mode = Control.FOCUS_NONE
		next_button.pressed.connect(arena.player_input.next_actor)
	if options_button and options_menu:
		options_button.focus_mode = Control.FOCUS_NONE
		options_button.pressed.connect(options_menu.toggle)
	
	var finish_button = Button.new()
	finish_button.text = "Finish Day"
	finish_button.focus_mode = Control.FOCUS_NONE
	finish_button.position = Vector2(20, 100)
	finish_button.pressed.connect(_on_finish_day_pressed)
	var ui_node = arena.get_node_or_null("UI")
	if ui_node:
		ui_node.add_child(finish_button)

func update_for_actor(actor: Actor) -> void:
	if _current_actor:
		if _current_actor.health_component:
			if _current_actor.health_component.health_changed.is_connected(_on_actor_hp_changed):
				_current_actor.health_component.health_changed.disconnect(_on_actor_hp_changed)
		if _current_actor.mana_changed.is_connected(_on_actor_mana_changed):
			_current_actor.mana_changed.disconnect(_on_actor_mana_changed)
	
	_current_actor = actor
	
	if _current_actor:
		if _current_actor.health_component:
			_current_actor.health_component.health_changed.connect(_on_actor_hp_changed)
		_current_actor.mana_changed.connect(_on_actor_mana_changed)
		if reticle:
			reticle.color = _current_actor.get_actor_color()
		update_ui_text()
		
		# Update UI abilities
		var ability_comp = _current_actor.ability_component
		if ability_comp and ability_comp.actions.size() > 0:
			ItemsAutoload.set_selected_ability(ability_comp.actions[0].get_ability_data())
		else:
			ItemsAutoload.set_selected_ability(null)
			
		ItemsAutoload.set_selected_actor(_current_actor)

func _on_actor_hp_changed(_hp: float, _m_hp: float) -> void:
	update_ui_text()

func _on_actor_mana_changed(_m: float, _mm: float) -> void:
	update_ui_text()

func update_ui_text() -> void:
	if not _current_actor or not target_label: return
	var hp = 0.0
	var m_hp = 0.0
	if _current_actor.health_component:
		hp = _current_actor.health_component.current_health
		m_hp = _current_actor.health_component.max_health
	target_label.text = "Following: " + _current_actor.name + \
		" HP: %d / %d | Mana: %d / %d" % [int(hp), int(m_hp), int(_current_actor.current_mana), int(_current_actor.max_mana)]

func _on_finish_day_pressed() -> void:
	GameEvents.day_finished.emit()
	if arena.has_node("/root/HerdManager"):
		arena.get_node("/root/HerdManager").next_day()
	arena.get_tree().change_scene_to_file("res://Ranch/Ranch.tscn")

func handle_game_over() -> void:
	if target_label:
		target_label.text = "ALL FRIENDLIES HAVE DIED!"
		target_label.modulate = Color.RED
	
	_current_actor = null
	var timer = arena.get_tree().create_timer(3.0)
	timer.timeout.connect(_on_finish_day_pressed)

func _process(_delta: float) -> void:
	if _current_actor and reticle:
		reticle.mana_value = _current_actor.get_main_action_progress()
		if _current_actor.projectile_component:
			reticle.attack_pattern = _current_actor.projectile_component.current_attack_pattern
