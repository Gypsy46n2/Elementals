extends Node
## Utility class for map settings management.
## Can be added as an autoload (MapSettingsHelper) or instantiated.

## Get settings as a dictionary from UI controls
static func get_settings_dict(
	size_spinner: SpinBox,
	seed_spinner: SpinBox,
	random_seed_check: CheckBox,
	scale_slider: HSlider,
	height_slider: HSlider,
	dirt_slider: HSlider
) -> Dictionary:
	var settings := {
		"grid_width": int(size_spinner.value),
		"grid_height": int(size_spinner.value),
	}
	
	if random_seed_check.button_pressed:
		settings["noise_seed"] = randi() % 100000
	else:
		settings["noise_seed"] = int(seed_spinner.value)
	
	settings["noise_frequency"] = scale_slider.value
	settings["height_step"] = height_slider.value
	settings["dirt_threshold"] = dirt_slider.value
	
	return settings

## Apply settings dictionary to a given GameSettings reference
static func apply_settings_to_game_settings(settings: Dictionary, gs) -> void:
	gs.grid_width = settings.get("grid_width", gs.grid_width)
	gs.grid_height = settings.get("grid_height", gs.grid_height)
	gs.noise_seed = settings.get("noise_seed", gs.noise_seed)
	gs.noise_frequency = settings.get("noise_frequency", gs.noise_frequency)
	gs.height_step = settings.get("height_step", gs.height_step)
	gs.dirt_threshold = settings.get("dirt_threshold", gs.dirt_threshold)

## Normalize dirt threshold to 0-1 range
static func normalize_dirt_value(value: float) -> float:
	return clamp((value + 0.3) / 0.6, 0.0, 1.0)