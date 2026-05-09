## Global registry for all biome definitions.
class_name BiomeRegistry
extends RefCounted

static var _biomes: Dictionary = {}

static func register(biome: BiomeData) -> void:
	_biomes[biome.biome_id] = biome

static func get_biome(biome_id: String) -> BiomeData:
	return _biomes.get(biome_id)

static func get_all_biomes() -> Array[BiomeData]:
	return _biomes.values()
