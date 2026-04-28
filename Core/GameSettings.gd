extends Node

const SAVE_PATH = "user://settings.cfg"

var selected_actor_type: String = "fire" # "fire", "water", or "goat"
var grid_width: int = 20
var grid_height: int = 20
var fire_count: int = 1
var water_count: int = 1
var goat_count: int = 1

var noise_seed: int = 0
var noise_frequency: float = 0.05
var height_step: float = 1.0
var dirt_threshold: float = 0.2
var master_volume: float = 1.0

func _ready() -> void:
	load_settings()
	_apply_volume(master_volume)

func _apply_volume(value: float) -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(value))

func save_settings() -> void:
	var config = ConfigFile.new()
	
	config.set_value("General", "selected_actor_type", selected_actor_type)
	config.set_value("General", "grid_width", grid_width)
	config.set_value("General", "grid_height", grid_height)
	
	config.set_value("NPCs", "fire_count", fire_count)
	config.set_value("NPCs", "water_count", water_count)
	config.set_value("NPCs", "goat_count", goat_count)
	
	config.set_value("WorldGen", "noise_seed", noise_seed)
	config.set_value("WorldGen", "noise_frequency", noise_frequency)
	config.set_value("WorldGen", "height_step", height_step)
	config.set_value("WorldGen", "dirt_threshold", dirt_threshold)
	config.set_value("Audio", "master_volume", master_volume)
	
	var err = config.save(SAVE_PATH)
	if err != OK:
		push_error("Failed to save settings to %s" % SAVE_PATH)

func load_settings() -> void:
	var config = ConfigFile.new()
	var err = config.load(SAVE_PATH)
	if err != OK:
		return # No settings file exists yet, using defaults
	
	selected_actor_type = config.get_value("General", "selected_actor_type", selected_actor_type)
	grid_width = config.get_value("General", "grid_width", grid_width)
	grid_height = config.get_value("General", "grid_height", grid_height)
	
	fire_count = config.get_value("NPCs", "fire_count", fire_count)
	water_count = config.get_value("NPCs", "water_count", water_count)
	goat_count = config.get_value("NPCs", "goat_count", goat_count)
	
	noise_seed = config.get_value("WorldGen", "noise_seed", noise_seed)
	noise_frequency = config.get_value("WorldGen", "noise_frequency", noise_frequency)
	height_step = config.get_value("WorldGen", "height_step", height_step)
	dirt_threshold = config.get_value("WorldGen", "dirt_threshold", dirt_threshold)
	master_volume = config.get_value("Audio", "master_volume", master_volume)
