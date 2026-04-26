extends VBoxContainer

var arena: ArenaGrid
@onready var debug_checkbox: CheckBox = $DebugCheckBox
@onready var debug_label: Label = $TileCountLabel

var spawn_buttons_container: HBoxContainer

func _ready() -> void:
	# Find the ArenaGrid in the scene
	arena = get_tree().get_first_node_in_group("arena")
	if not arena:
		# Fallback: search parents
		var parent = get_parent()
		while parent:
			if parent is ArenaGrid:
				arena = parent
				break
			parent = parent.get_parent()
	
	if arena:
		arena.tile_counts_changed.connect(_on_tile_counts_changed)
	
	if debug_checkbox:
		debug_checkbox.toggled.connect(_on_debug_checkbox_toggled)
	
	_setup_spawn_buttons()

func _on_tile_counts_changed(counts: Dictionary) -> void:
	_update_debug_info(counts)

func _setup_spawn_buttons() -> void:
	spawn_buttons_container = HBoxContainer.new()
	add_child(spawn_buttons_container)
	# Reorder so it's after checkbox but before label
	move_child(spawn_buttons_container, 1)
	
	var fire_btn = Button.new()
	fire_btn.text = "Spawn Fire"
	fire_btn.focus_mode = Control.FOCUS_NONE
	fire_btn.pressed.connect(func(): if arena and arena.actor_spawner: arena.actor_spawner.spawn_actor("fire"))
	spawn_buttons_container.add_child(fire_btn)
	
	var water_btn = Button.new()
	water_btn.text = "Spawn Water"
	water_btn.focus_mode = Control.FOCUS_NONE
	water_btn.pressed.connect(func(): if arena and arena.actor_spawner: arena.actor_spawner.spawn_actor("water"))
	spawn_buttons_container.add_child(water_btn)
	
	var goat_btn = Button.new()
	goat_btn.text = "Spawn Goat"
	goat_btn.focus_mode = Control.FOCUS_NONE
	goat_btn.pressed.connect(func(): if arena and arena.actor_spawner: arena.actor_spawner.spawn_actor("goat"))
	spawn_buttons_container.add_child(goat_btn)

func _update_debug_info(counts: Dictionary = {}) -> void:
	if not debug_checkbox or not debug_label or not arena:
		return
		
	# We don't have a global static debug_enabled anymore, or we can add it to ArenaGrid
	# For now, let's just update the activeness of all tiles
	if arena and arena.tile_system:
		for tile in arena.tile_data_grid:
			arena.tile_system.check_activeness(tile)
	
	if spawn_buttons_container:
		spawn_buttons_container.visible = debug_checkbox.button_pressed
		
	if not debug_checkbox.button_pressed:
		debug_label.visible = false
		return
		
	debug_label.visible = true
	
	if counts.is_empty():
		counts = arena.tile_counts
		
	var state_names = {
		TileConstants.State.GRASS: "Grass",
		TileConstants.State.DIRT: "Dirt",
		TileConstants.State.MUD: "Mud",
		TileConstants.State.PUDDLE: "Puddle",
		TileConstants.State.FIRE: "Fire",
		TileConstants.State.STONE: "Stone"
	}
	
	var sorted_counts = []
	for state in state_names.keys():
		sorted_counts.append({"name": state_names[state], "count": counts.get(state, 0)})
	
	sorted_counts.sort_custom(func(a, b): return a.count > b.count)
				
	var text = "Tile Counts:\n"
	for item in sorted_counts:
		text += "%s: %d\n" % [item.name, item.count]
	
	debug_label.text = text

func _on_debug_checkbox_toggled(pressed: bool) -> void:
	DebugComponent.debug_enabled = pressed
	_update_debug_info()

# Replace _process with nothing or a simpler version if needed
# Actually, the checkbox state change needs to be handled too.
