## BiomeData defines tree spawn density and behavior for a terrain biome.
class_name BiomeData
extends Resource

## Identifier for this biome (e.g., "plains", "forest", "dense_woods")
@export var biome_id: String = "default"

## Display name shown in debug UI
@export var display_name: String = "Default Biome"

## Base tree density per tile (0.0–1.0).
## Higher values = more trees spawn.
## Final chance is: density * distance_multiplier
@export_range(0.0, 1.0, 0.01) var base_density: float = 0.15

## Distance-based density multiplier.
## Trees become more common further from center (farmstead).
## Format: { distance_radius: multiplier }
## Example: { 5: 0.5, 10: 1.0, 20: 1.5 } means trees are sparse near farmstead, denser farther out.
@export var distance_multipliers: Dictionary = {
	0: 0.0,    # Farmstead — no trees
	3: 0.1,    # Perimeter — very sparse
	7: 0.5,    # Just outside farmstead — sparse
	15: 1.0,   # Mid-range — normal density
	25: 1.5,   # Far — dense
	100: 2.0,  # Edge — very dense
}

## Minimum distance between trees (in hex tiles).
## Set to 0 to allow any spacing.
@export_range(0, 5) var min_tree_spacing: int = 1

## If true, trees prefer tiles adjacent to dirt or mud (for variety).
## If false, trees spawn randomly on valid grass tiles.
@export var prefer_near_dirt: bool = false

## If true, trees avoid tiles with many neighbors that already have trees.
## This creates natural clustering vs. even distribution.
@export var allow_clustering: bool = true

## Maximum attempts to find a valid tile before giving up on a tree spawn.
@export_range(1, 20) var spawn_attempts: int = 5

## List of tree blueprints available in this biome.
## One is randomly chosen per tree spawned.
@export var tree_blueprints: Array[Resource] = []

## Returns the density multiplier for a given distance from center.
## Uses linear interpolation between defined distance thresholds.
func get_density_for_distance(distance: int) -> float:
	var distances: Array = distance_multipliers.keys()
	distances.sort()
	
	if distance <= distances[0]:
		return distance_multipliers[distances[0]]
	if distance >= distances[-1]:
		return distance_multipliers[distances[-1]]
	
	var lower_dist: int = distances[0]
	var upper_dist: int = distances[-1]
	for i in range(distances.size() - 1):
		if distances[i] <= distance and distance < distances[i + 1]:
			lower_dist = distances[i]
			upper_dist = distances[i + 1]
			break
	
	var t: float = float(distance - lower_dist) / float(upper_dist - lower_dist)
	return lerp(distance_multipliers[lower_dist], distance_multipliers[upper_dist], t)

## Returns the final spawn chance for a tile at the given distance.
func get_spawn_chance(distance_from_center: int) -> float:
	var distance_mult: float = get_density_for_distance(distance_from_center)
	return clampf(base_density * distance_mult, 0.0, 1.0)

## Returns a random tree blueprint from the available pool.
func get_random_blueprint() -> Resource:
	if tree_blueprints.is_empty():
		var oak: Resource = preload("res://src/trees/resources/OakTree.tres")
		if oak:
			return oak
		return null
	return tree_blueprints[randi() % tree_blueprints.size()]
