class_name HarvestableTree
extends Node3D
## In-game tree representation that builds a CSG tree from a TreeBlueprint.
## Handles state transitions and harvesting mechanics.

signal harvest_started(actor: Node3D)
signal harvest_completed(actor: Node3D, wood_yield: float)
signal tree_fallen

enum State { STANDBY, FELLING, FELLEDB }

@export var blueprint: TreeBlueprint
@export var current_hp: float
@export var max_hp: float

var _state: State = State.STANDBY
var _harvesters: Dictionary = {}  # actor_id -> accumulated_damage
var _animation_player: AnimationPlayer
var _collision_shapes: Array[CollisionShape3D] = []
var _csg_trunk_base: CSGCylinder3D
var _csg_branch_nodes: Array[CSGCylinder3D] = []
var _csg_foliage_nodes: Array[CSGSphere3D] = []
var _mesh_lod1: MeshInstance3D
var _mesh_lod2: MeshInstance3D
var _generated_tree: TreeBlueprint.GeneratedTree


func _ready() -> void:
	_setup_from_blueprint()


func _setup_from_blueprint() -> void:
	if not blueprint:
		push_warning("HarvestableTree: No blueprint assigned")
		return

	# Initialize HP if not set
	if max_hp <= 0:
		max_hp = blueprint.compute_max_hp(blueprint.total_branch_budget)
		current_hp = max_hp

	_build_csge_tree()


func _build_csge_tree() -> void:
	# Clear existing CSG nodes
	_clear_csge_nodes()

	# Generate tree structure from blueprint (handles all the chain logic)
	_generated_tree = blueprint.generate_tree()

	# Build trunk segments
	for i in range(_generated_tree.segments.size()):
		var segment: TreeBlueprint.TrunkSegment = _generated_tree.segments[i]
		_create_trunk_segment(segment, i)

	# Build branches
	for branch: TreeBlueprint.BranchData in _generated_tree.branches:
		_create_branch(branch)

	# Build foliage
	for foliage: TreeBlueprint.FoliageData in _generated_tree.foliage:
		_create_foliage_layer(foliage)

	# Add collision collider at base
	_add_base_collision()


func _create_trunk_segment(segment: TreeBlueprint.TrunkSegment, index: int) -> void:
	var trunk_segment := CSGCylinder3D.new()
	trunk_segment.name = "TrunkSegment_%d" % index
	trunk_segment.radius = segment.radius
	trunk_segment.height = segment.height
	trunk_segment.position = segment.midpoint
	trunk_segment.rotation = segment.rotation.get_euler()
	trunk_segment.use_collision = true
	trunk_segment.material = blueprint.create_trunk_material()

	add_child(trunk_segment)

	if segment.is_base:
		_csg_trunk_base = trunk_segment


func _create_branch(branch: TreeBlueprint.BranchData) -> void:
	var branch_node := CSGCylinder3D.new()
	branch_node.name = "Branch_%d" % _csg_branch_nodes.size()
	branch_node.radius = branch.radius
	branch_node.height = branch.length
	branch_node.position = branch.origin + (branch.direction * branch.length / 2.0)
	branch_node.rotation = branch.rotation.get_euler()
	branch_node.use_collision = true
	branch_node.material = blueprint.create_branch_material()

	add_child(branch_node)
	_csg_branch_nodes.append(branch_node)


func _create_foliage_layer(foliage: TreeBlueprint.FoliageData) -> void:
	var sphere := CSGSphere3D.new()
	sphere.name = "FoliageLayer_%d" % _csg_foliage_nodes.size()
	sphere.radius = foliage.radius
	sphere.position = foliage.position
	sphere.rotation.y = foliage.rotation_y
	sphere.use_collision = false  # Foliage typically doesn't need collision
	sphere.material = blueprint.create_foliage_material()

	add_child(sphere)
	_csg_foliage_nodes.append(sphere)


func _add_base_collision() -> void:
	var shape := CylinderShape3D.new()
	shape.radius = blueprint.base_radius * 1.5
	shape.height = 0.2

	var collision := CollisionShape3D.new()
	collision.name = "BaseCollision"
	collision.shape = shape
	collision.position = Vector3(0, 0.1, 0)
	collision.disabled = false

	var static_body := StaticBody3D.new()
	static_body.name = "BaseStaticBody"
	static_body.add_child(collision)
	add_child(static_body)
	_collision_shapes.append(collision)


func _clear_csge_nodes() -> void:
	for node in _csg_branch_nodes + _csg_foliage_nodes:
		if is_instance_valid(node):
			node.queue_free()
	_csg_branch_nodes.clear()
	_csg_foliage_nodes.clear()

	if is_instance_valid(_csg_trunk_base):
		_csg_trunk_base.queue_free()
		_csg_trunk_base = null


# ─────────────────────────────────────────────
# Harvesting Interface
# ─────────────────────────────────────────────

func start_harvest(actor: Node3D, damage_per_second: float = 10.0) -> void:
	if _state != State.STANDBY:
		return

	_harvesters[actor.get_instance_id()] = { "actor": actor, "dps": damage_per_second, "accumulated": 0.0 }
	harvest_started.emit(actor)


func stop_harvest(actor: Node3D) -> void:
	var actor_id = actor.get_instance_id()
	if _harvesters.has(actor_id):
		_harvesters.erase(actor_id)
		# Harvest continues until HP depleted; stopping just removes this actor's contribution


func apply_damage(damage: float, actor: Node3D = null) -> void:
	if _state != State.STANDBY:
		return

	current_hp = max(0.0, current_hp - damage)

	if current_hp <= 0:
		_trigger_felling(actor)


func _process(delta: float) -> void:
	if _state != State.STANDBY:
		return

	# Process active harvesters
	for actor_id in _harvesters.keys():
		var harvester = _harvesters[actor_id]
		if not is_instance_valid(harvester.actor):
			_harvesters.erase(actor_id)
			continue

		harvester.accumulated += harvester.dps * delta
		current_hp = max(0.0, current_hp - harvester.dps * delta)

		if current_hp <= 0:
			_trigger_felling(harvester.actor)
			return


func _trigger_felling(actor: Node3D = null) -> void:
	_state = State.FELLING

	# Create AnimationPlayer if not exists
	if not _animation_player:
		_animation_player = AnimationPlayer.new()
		_animation_player.name = "TreeAnimation"
		add_child(_animation_player)

		# Create a simple fall animation
		_create_fall_animation()

	_animation_player.play("Fall")

	# Apply rotation to entire tree group
	await _animation_player.animation_finished
	_finalize_felling(actor)


func _create_fall_animation() -> void:
	var animation := Animation.new()
	animation.length = 1.5

	# Rotate around base (pivot at ground level)
	var track_index := animation.add_track(Animation.TYPE_ROTATION_3D)
	animation.track_set_path(track_index, ".")
	animation.rotation_track_set_use_compat(track_index, true)
	animation.track_insert_key(track_index, 0.0, Quaternion.IDENTITY)
	animation.rotation_track_insert_key_compat(track_index, 1.5, Quaternion.from_euler(Vector3(0, 0, deg_to_rad(-85))))

	# Optional: Add a slight bounce at the end
	var bounce_track := animation.add_track(Animation.TYPE_VALUE)
	animation.track_set_path(bounce_track, "rotation_degrees:z")
	animation.track_insert_key(bounce_track, 0.0, 0.0)
	animation.track_insert_key(bounce_track, 1.3, -80.0)
	animation.track_insert_key(bounce_track, 1.5, -85.0)

	_animation_player.add_animation("Fall", animation)


func _finalize_felling(actor: Node3D = null) -> void:
	_state = State.FELLEDB

	# Disable collision on trunk/base
	for shape in _collision_shapes:
		if is_instance_valid(shape):
			shape.disabled = true

	# Update collision for fallen state (cylinder rotated)
	_add_fallen_collision()

	tree_fallen.emit()

	# Calculate and grant wood yield
	if actor or not _harvesters.is_empty():
		var branch_count = _csg_branch_nodes.size()
		var wood_yield = blueprint.compute_wood_yield(branch_count)

		if actor:
			harvest_completed.emit(actor, wood_yield)
		else:
			for harvester_data in _harvesters.values():
				harvest_completed.emit(harvester_data.actor, wood_yield)


func _add_fallen_collision() -> void:
	# Remove old base collision
	for child in get_children():
		if child is StaticBody3D:
			child.queue_free()
	_collision_shapes.clear()

	# Add rotated cylinder collision for fallen tree
	var shape := CylinderShape3D.new()
	shape.radius = blueprint.base_radius * 0.8
	shape.height = blueprint.base_height * 1.2

	var collision := CollisionShape3D.new()
	collision.name = "FallenCollision"
	collision.shape = shape
	collision.rotation = Vector3(0, 0, deg_to_rad(90))
	collision.position = Vector3(0, blueprint.base_height * 0.4, blueprint.base_height * 0.4)
	collision.disabled = false

	var rigid_body := RigidBody3D.new()
	rigid_body.name = "FallenRigidBody"
	rigid_body.add_child(collision)
	rigid_body.freeze = true  # Tree stays in place after falling
	add_child(rigid_body)
	_collision_shapes.append(collision)


# ─────────────────────────────────────────────
# LOD Support
# ─────────────────────────────────────────────

func switch_to_lod(level: int) -> void:
	match level:
		0:  # Full detail - CSG tree
			_set_csge_visible(true)
			_hide_lod_meshes()
		1:  # Simplified mesh
			_set_csge_visible(false)
			_show_lod_mesh(_mesh_lod1)
			_hide_lod_mesh(_mesh_lod2)
		2:  # Billboard
			_set_csge_visible(false)
			_hide_lod_meshes()
			# TODO: Show billboard sprite
		3:  # Culled
			_set_csge_visible(false)
			_hide_lod_meshes()
			set_process(false)


func _set_csge_visible(visible: bool) -> void:
	for node in get_children():
		if node is CSGShape3D:
			node.visible = visible


func _show_lod_mesh(mesh: MeshInstance3D) -> void:
	if mesh:
		mesh.visible = true


func _hide_lod_mesh(mesh: MeshInstance3D) -> void:
	if mesh:
		mesh.visible = false


func _hide_lod_meshes() -> void:
	if _mesh_lod1:
		_mesh_lod1.visible = false
	if _mesh_lod2:
		_mesh_lod2.visible = false


func get_state() -> State:
	return _state


func get_hp_ratio() -> float:
	if max_hp <= 0:
		return 1.0
	return current_hp / max_hp


func is_harvestable() -> bool:
	return _state == State.STANDBY and current_hp > 0
