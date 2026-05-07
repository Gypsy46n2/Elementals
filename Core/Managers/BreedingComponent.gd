class_name BreedingComponent
extends Node

func breed(parent_a: ActorData, parent_b: ActorData) -> bool:
	# Find which is male and which is female
	var male: ActorData
	var female: ActorData
	
	if parent_a.gender == ActorData.Gender.MALE and parent_b.gender == ActorData.Gender.FEMALE:
		male = parent_a
		female = parent_b
	elif parent_a.gender == ActorData.Gender.FEMALE and parent_b.gender == ActorData.Gender.MALE:
		male = parent_b
		female = parent_a
	else:
		return false  # Must be male + female
	
	if female.is_pregnant or female.is_exhausted or male.is_exhausted:
		return false
		
	female.is_pregnant = true
	female.pregnancy_timer = 3 # 3 days pregnancy
	female.pregnancy_father = male
	
	# Breeding is tiring
	female.is_exhausted = true
	male.is_exhausted = true
	
	GameEvents.herd_updated.emit()
	return true

func process_pregnancy(actors: Array) -> Array[ActorData]:
	var new_offspring: Array[ActorData] = []
	for actor in actors:
		if actor is ActorData and actor.is_pregnant:
			actor.pregnancy_timer -= 1
			if actor.pregnancy_timer <= 0:
				actor.is_pregnant = false
				var partner = actor.pregnancy_father
				if not partner:
					partner = _find_random_male(actors)
				
				if partner:
					var kid = actor.create_offspring(partner)
					new_offspring.append(kid)
				
				actor.pregnancy_father = null
	return new_offspring

func _find_random_male(actors: Array[ActorData]) -> ActorData:
	var males = actors.filter(func(a): return a.gender == ActorData.Gender.MALE)
	if males.is_empty():
		return null
	return males.pick_random()
