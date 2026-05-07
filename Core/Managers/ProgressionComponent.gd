class_name ProgressionComponent
extends Node

var current_day: int = 1

func initialize(initial_day: int) -> void:
	current_day = initial_day

func advance_day(herd: Array[ActorData]) -> void:
	current_day += 1
	
	for goat in herd:
		# Aging
		goat.age_days += 1
		
		# Stamina Recovery (if they weren't selected, they recover fully)
		# If they were selected, they become exhausted
		if goat.is_selected:
			goat.is_exhausted = true
			goat.is_selected = false # Deselect for next day
		else:
			goat.stamina_current = goat.stamina_max
			goat.is_exhausted = false
			
	GameEvents.day_advanced.emit(current_day)
