class_name GoatRenderer
extends Control

@export var goat_data: GoatData:
	set(v):
		if goat_data:
			if goat_data.stats_changed.is_connected(update_visuals):
				goat_data.stats_changed.disconnect(update_visuals)
		goat_data = v
		if goat_data:
			goat_data.stats_changed.connect(update_visuals)
		update_visuals()

const ASSETS = {
	"body": preload("res://assets/experimental/goat_body_quadruped_frame_0_1775009982.png"),
	"patterns": {
		GoatData.PatternType.SOLID: null,
		GoatData.PatternType.PIEBALD: preload("res://assets/generated/GoatCurledHornsGreyStriped_SideView_frame_1_1775090983.png"), # Placeholder
		GoatData.PatternType.SPOTTED: preload("res://assets/generated/GoatCurledHornsGreyStriped_SideView_frame_2_1775090983.png"), # Placeholder
	},
	"horns": {
		GoatData.HornType.NONE: null,
		GoatData.HornType.SMALL: preload("res://assets/generated/GoatCurledHornsGreyStriped_SideView_frame_0_1775090983.png"), # Placeholder
		GoatData.HornType.LARGE: preload("res://assets/generated/GoatCurledHornsGreyStriped_SideView_frame_0_1775090983.png"), # Placeholder
		GoatData.HornType.SPIRAL: preload("res://assets/generated/GoatCurledHornsGreyStriped_SideView_frame_3_1775090983.png"), # Placeholder
	}
}

func _ready() -> void:
	update_visuals()

func update_visuals() -> void:
	if not is_node_ready() or not goat_data:
		return
	
	# Body Type Scaling
	var scale_factor = 1.0
	match goat_data.body_type:
		GoatData.BodyType.SMALL: scale_factor = 0.8
		GoatData.BodyType.MEDIUM: scale_factor = 1.0
		GoatData.BodyType.LARGE: scale_factor = 1.2
	
	custom_minimum_size = Vector2(128, 128) * scale_factor
	pivot_offset = size / 2.0
	scale = Vector2.ONE * scale_factor
