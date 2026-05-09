class_name TreeBlueprint
extends Resource

## Defines the parameters for procedurally generating a single tree.
## Used by TreeSpawner and HarvestableTree to construct trees from CSG primitives.

#region Foliage Shape
enum FoliageShape {
	SPHERE,
	CONE,
	CAPSULE
}
#endregion

#region Trunk Configuration
## Total height of the trunk in world units.
@export_range(2.0, 6.0, 0.1) var base_height: float = 8.0

## Radius at the base of the trunk.
@export_range(0.1, 1.0, 0.1) var base_radius: float = 1.0

## Number of cylindrical/conical segments composing the trunk.
@export_range(2, 4, 1) var segment_count: int = 3

## Maximum bend angle (degrees) per trunk segment. Adds organic variation.
@export_range(0.0, 15.0, 0.5) var jank_factor: float = 5.0

## Variation modifier applied to each segment's height and rotation (±%).
@export_range(0.0, 0.2, 0.01) var segment_randomness: float = 0.1
#endregion

#region Branch Rules
## Total number of branches to spawn across the entire tree.
## Distributed evenly across trunk segments (excluding base segment).
@export_range(0, 12, 1) var total_branch_budget: int = 3

## Minimum and maximum branch length in world units (max < 1/3 tree height).
@export_range(0.5, 2.5, 0.1) var branch_length_min: float = 1.0
@export_range(0.5, 2.5, 0.1) var branch_length_max: float = 2.5

## Branch angle in degrees from horizontal (0°=horizontal, 90°=vertical).
@export_range(0.0, 90.0, 1.0) var branch_angle_min: float = 5.0
@export_range(0.0, 90.0, 1.0) var branch_angle_max: float = 75.0

## X = minimum branch radius as ratio of parent segment, Y = maximum.
@export var branch_radius_ratio: Vector2 = Vector2(0.5, 0.65)

## Probability (0-1) that each branch spawns with foliage at its tip.
@export_range(0.0, 1.0, 0.05) var branch_foliage_ratio: float = 0.1

## Fraction of trunk height to reserve at top and bottom (no branch spawn zone).
## Applied equally to top and bottom, so effective usable range is padding*2 to 1-padding*2.
@export_range(0.05, 0.25, 0.01) var branch_attachment_padding: float = 0.15
#endregion

#region Foliage Layers
## Minimum number of canopy layers.
@export_range(1, 4, 1) var foliage_layers_min: int = 2

## Maximum number of canopy layers.
@export_range(1, 4, 1) var foliage_layers_max: int = 3

## Primitive shape used for foliage clusters.
@export var foliage_shape: FoliageShape = FoliageShape.SPHERE

## Up/down offset jitter per layer in world units.
@export_range(0.0, 1.0, 0.1) var layer_offset_variance: float = 0.4

## Scale jitter applied to each layer (±%).
@export_range(0.0, 0.3, 0.05) var layer_scale_variance: float = 0.15

## Random Y-axis rotation range when placing each layer (degrees).
@export_range(0.0, 60.0, 1.0) var layer_rotation_variance: float = 20.0

## X = minimum foliage density (primitives per layer), Y = maximum.
@export_range(3.0, 5.0, 0.5) var foliage_density_min: float = 3.0
@export_range(3.0, 5.0, 0.5) var foliage_density_max: float = 5.0

## Base size of foliage primitives.
@export_range(0.5, 2.0, 0.1) var foliage_size: float = 1.2
#endregion

#region Materials
## Tint color applied to trunk meshes. Set at runtime for variation.
@export var trunk_tint: Color = Color(0.9, 0.35, 0.2, 1.0)

## Tint color applied to branch meshes.
@export var branch_tint: Color = Color(0.9, 0.32, 0.18, 1.0)

## Tint color applied to foliage meshes.
@export var foliage_tint: Color = Color(0.2, 0.55, 0.15, 1.0)
#endregion

#region LOD Meshes
## Simplified mesh for LOD1 (30-60 units from camera).
@export var lod1_mesh: Mesh

## Billboard or silhouette mesh for LOD2 (60-100 units from camera).
@export var lod2_mesh: Mesh
#endregion


#region Generated Data Structures

## Represents a single trunk segment with proper chaining data.
class TrunkSegment:
	var origin: Vector3          ## Starting point (fixed for segment 0, chained for others)
	var terminal: Vector3       ## Ending point after jank applied
	var axis: Vector3           ## Unit vector from origin to terminal
	var height: float           ## Distance between origin and terminal
	var radius: float           ## Radius at this segment
	var midpoint: Vector3       ## (origin + terminal) / 2 for CSG cylinder center
	var rotation: Quaternion   ## Orientation for CSG cylinder alignment
	var is_base: bool           ## True if this is the first segment (Y = 0 origin)

class BranchData:
	var origin: Vector3          ## Attachment point on trunk
	var direction: Vector3      ## Unit vector pointing outward
	var length: float           ## Branch length
	var radius: float           ## Branch radius
	var rotation: Quaternion    ## Orientation for CSG cylinder

class FoliageData:
	var position: Vector3       ## World position of foliage center
	var anchor_point: Vector3   ## Point the foliage is anchored to (trunk terminal or branch tip)
	var radius: float           ## Sphere radius
	var scale: float            ## Layer scale multiplier
	var rotation_y: float       ## Y-axis rotation in radians

## Container for the complete generated tree structure.
class GeneratedTree:
	var segments: Array[TrunkSegment] = []
	var branches: Array[BranchData] = []
	var foliage: Array[FoliageData] = []

#endregion


#region Computed Properties

## Returns the total branch budget for this tree.
func get_total_branch_budget() -> int:
	return total_branch_budget

## Returns the effective foliage layer count as a random value between min and max.
func get_random_foliage_layers() -> int:
	return randi() % (foliage_layers_max - foliage_layers_min + 1) + foliage_layers_min

## Returns a random branch length within the configured range.
func get_random_branch_length() -> float:
	return randf() * (branch_length_max - branch_length_min) + branch_length_min

## Returns a random branch angle (degrees from horizontal).
func get_random_branch_angle() -> float:
	return randf() * (branch_angle_max - branch_angle_min) + branch_angle_min

## Returns a random branch radius ratio.
func get_random_branch_radius_ratio() -> float:
	return randf() * (branch_radius_ratio.y - branch_radius_ratio.x) + branch_radius_ratio.x

## Returns a random foliage density for a layer.
func get_random_foliage_density() -> float:
	return randf() * (foliage_density_max - foliage_density_min) + foliage_density_min

## Returns the base HP for this tree based on trunk height and branch count.
## Used by HarvestableComponent to initialize the tree's HP pool.
func compute_max_hp(branch_count: int) -> int:
	var height_factor := 3.0
	var branch_factor := 2.0
	var base_hp := 10
	return int(base_hp + (base_height * height_factor) + (branch_count * branch_factor))

## Returns an estimated wood yield based on tree parameters.
## This is a tuning placeholder — adjust coefficients based on gameplay feedback.
func compute_wood_yield(branch_count: int) -> int:
	var base_yield := 5
	var height_contribution := int(base_height * 1.2)
	var branch_contribution := branch_count * 2
	return base_yield + height_contribution + branch_contribution

#endregion


#region Tree Generation

## Generates a complete tree structure from this blueprint.
## Uses segment-chaining algorithm where each segment's origin = previous segment's terminal.
## The first segment is always anchored at ground level (Y = 0).
func generate_tree() -> GeneratedTree:
	var tree := GeneratedTree.new()
	var remaining_branch_budget: int = total_branch_budget
	var branch_foliage: Array[FoliageData] = []
	
	# Calculate segment heights with randomness applied
	var segment_heights := _calculate_segment_heights()
	
	# Chain segments: each segment's origin is the previous segment's terminal
	var current_origin := Vector3(0, 0, 0)
	var current_axis := Vector3(0, 1, 0)  # Start pointing up
	var accumulated_jank := Vector3(0, 0, 0)
	
	for i in range(segment_count):
		var segment_height: float = segment_heights[i]
		var segment_radius: float = _calculate_trunk_radius(i, segment_count)
		
		# Generate jank for this segment (accumulates to create natural lean)
		var jank := _generate_jank()
		accumulated_jank += jank
		
		# Calculate terminal point: origin + rotated axis * height
		var jank_rotation := _create_jank_rotation(accumulated_jank)
		var rotated_axis := jank_rotation * current_axis
		var terminal := current_origin + rotated_axis * segment_height
		
		# Create segment data
		var segment := TrunkSegment.new()
		segment.origin = current_origin
		segment.terminal = terminal
		segment.axis = rotated_axis
		segment.height = segment_height
		segment.radius = segment_radius
		segment.midpoint = (current_origin + terminal) / 2.0
		segment.rotation = jank_rotation
		segment.is_base = (i == 0)
		tree.segments.append(segment)
		
		# Attach branches at segment joints (not the base joint or topmost segment)
		if i > 0 and i < (segment_count - 1):
			var is_last = (i == segment_count - 1)
			var branches := _generate_branches_at_joint(terminal, segment_radius, remaining_branch_budget, is_last, branch_foliage)
			for branch in branches:
				tree.branches.append(branch)
				remaining_branch_budget -= 1
		
		# Move origin to this segment's terminal for next iteration
		current_origin = terminal
	
	# Generate foliage at the top (guaranteed - topmost trunk always gets foliage)
	var trunk_foliage: Array[FoliageData] = _generate_foliage(tree.segments.back())
	trunk_foliage.append_array(branch_foliage)
	tree.foliage = trunk_foliage
	
	return tree


## Calculates segment heights with randomness applied per-segment.
func _calculate_segment_heights() -> Array:
	var segment_height := base_height / segment_count
	var heights: Array = []
	
	for i in range(segment_count):
		var variation := randf_range(1.0 - segment_randomness, 1.0 + segment_randomness)
		heights.append(segment_height * variation)
	
	return heights


## Calculates trunk radius at a given segment index with taper and variation.
func _calculate_trunk_radius(segment_index: int, total_segments: int) -> float:
	var taper := 1.0 - (segment_index / float(total_segments)) * 0.5
	var variation := randf_range(1.0 - segment_randomness, 1.0 + segment_randomness)
	return base_radius * taper * variation


## Generates randomized jank offset with asymmetric distribution.
## Y-component has reduced range for height stability.
func _generate_jank() -> Vector3:
	return Vector3(
		randf_range(-jank_factor, jank_factor),
		randf_range(-jank_factor * 0.5, jank_factor * 0.5),
		randf_range(-jank_factor, jank_factor)
	)


## Creates a quaternion rotation from accumulated jank angles.
## Rotates around axes perpendicular to the current axis to create natural lean/twist.
func _create_jank_rotation(jank: Vector3) -> Quaternion:
	# Create rotation from jank angles
	# X rotation tilts forward/back, Z rotation tilts left/right
	var euler := Vector3(
		deg_to_rad(jank.x * 0.3),  # Scaled down for subtlety
		deg_to_rad(jank.y * 0.1),
		deg_to_rad(jank.z * 0.3)
	)
	return Quaternion.from_euler(euler)


## Generates branches attached at a trunk joint.
func _generate_branches_at_joint(joint_position: Vector3, parent_radius: float, remaining_budget: int, is_last: bool, branch_foliage: Array[FoliageData]) -> Array[BranchData]:
	var branches: Array[BranchData] = []
	
	# Determine how many branches to spawn at this joint
	var branch_ratio: float
	if is_last:
		branch_ratio = 0.4 + (randf() * 0.3)  # 40-70% chance
	else:
		branch_ratio = 0.2 + (randf() * 0.2)  # 20-40% chance
	
	var should_spawn := randf() < branch_ratio
	if not should_spawn or remaining_budget <= 0:
		return branches
	
	# Spawn 1-2 branches per joint
	var branch_count := mini(randi_range(1, 2), remaining_budget)
	
	for i in range(branch_count):
		var branch := BranchData.new()
		branch.origin = joint_position
		
		# Randomize outward direction
		var angle_horizontal := randf_range(0, TAU)
		var angle_vertical := deg_to_rad(randf_range(branch_angle_min, branch_angle_max))
		
		# Direction points outward from trunk axis with upward tilt
		branch.direction = Vector3(
			cos(angle_horizontal) * sin(angle_vertical),
			cos(angle_vertical),
			sin(angle_horizontal) * sin(angle_vertical)
		).normalized()
		
		branch.length = randf_range(branch_length_min, branch_length_max)
		branch.radius = parent_radius * randf_range(branch_radius_ratio.x, branch_radius_ratio.y)
		
		# Calculate rotation to align cylinder along branch direction
		branch.rotation = _rotation_to_align_with(branch.direction)
		
		branches.append(branch)
		
		# Emit foliage from branch tip (guaranteed - every branch gets foliage)
		var tip_position := joint_position + (branch.direction * branch.length)
		var f := FoliageData.new()
		f.anchor_point = tip_position
		f.position = tip_position  # Tip is center, no variance
		f.radius = randf_range(0.4, 0.8)
		f.scale = randf_range(1.0 - layer_scale_variance, 1.0 + layer_scale_variance)
		f.rotation_y = randf_range(0, deg_to_rad(layer_rotation_variance))
		branch_foliage.append(f)
	
	return branches


## Creates a quaternion rotation that aligns the local +Y axis with the given direction.
func _rotation_to_align_with(direction: Vector3) -> Quaternion:
	var up := Vector3(0, 1, 0)
	if abs(direction.dot(up)) > 0.999:
		# Direction is nearly parallel to up, use minimal rotation
		return Quaternion.IDENTITY
	
	# Cross product gives perpendicular axis
	var axis := up.cross(direction).normalized()
	var angle := acos(clamp(up.dot(direction), -1.0, 1.0))
	return Quaternion(axis, angle)


## Generates foliage data for the upper portion of the tree.
func _generate_foliage(anchor_segment: TrunkSegment) -> Array[FoliageData]:
	var foliage: Array[FoliageData] = []
	
	var anchor_point := anchor_segment.terminal
	var layer_count := randi_range(foliage_layers_min, foliage_layers_max)
	var base_radius := foliage_size / layer_count
	
	for i in range(layer_count):
		var layer := FoliageData.new()
		layer.anchor_point = anchor_point
		layer.position = anchor_point  # Terminal is center, no variance
		
		layer.radius = base_radius * randf_range(1.0 - layer_scale_variance, 1.0 + layer_scale_variance)
		layer.scale = randf_range(1.0 - layer_scale_variance, 1.0 + layer_scale_variance)
		layer.rotation_y = randf_range(0, deg_to_rad(layer_rotation_variance))
		
		foliage.append(layer)
	
	return foliage


#endregion


#region Material Generation Helpers

## Creates a trunk material with configured tint.
func create_trunk_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = trunk_tint.lerp(Color.BROWN, 0.5)
	mat.roughness = 0.9
	return mat


## Creates a branch material with configured tint.
func create_branch_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = branch_tint.lerp(Color.BROWN, 0.3)
	mat.roughness = 0.85
	return mat


## Creates a foliage material with configured tint.
func create_foliage_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = foliage_tint
	mat.roughness = 0.8
	return mat


#endregion
