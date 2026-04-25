class_name ArenaPhysics
extends StaticBody3D

func setup_physics(tile_data_grid: Array[HexTileData], hex_size: float, tile_scale: float, height_step: float, grid_width: int, grid_height: int) -> void:
	# Clear existing children if any
	for child in get_children():
		child.queue_free()
		
	# 1. Main Floor (One large primitive for stability)
	var w_total = grid_width + 2
	var h_total = grid_height + 2
	
	# Calculate approximate arena dimensions
	var center_x = (1.5 * (float(w_total - 1) * 0.5)) * hex_size
	var center_z = (sqrt(3.0) * (float(h_total - 1) * 0.5 + 0.25)) * hex_size
	# Radius that covers the hexagonal area
	var radius = max(w_total * 1.5 * hex_size, h_total * sqrt(3.0) * hex_size) * 0.55 * tile_scale
	
	var floor_shape = CylinderShape3D.new()
	floor_shape.radius = radius
	floor_shape.height = 1.0 # Thick floor to prevent tunneling
	
	var floor_col = CollisionShape3D.new()
	floor_col.shape = floor_shape
	floor_col.position = Vector3(center_x, -2.0, center_z) # Deep fallback
	add_child(floor_col)
	
	# 2. Individual Tile Colliders
	var wall_radius = 1.0 * tile_scale * 0.95
	var bottom_y = -10.0
	for tile in tile_data_grid:
		var surface_y = _get_tile_surface_y(tile, height_step)
		
		var height = surface_y - bottom_y
		var center_y = (surface_y + bottom_y) / 2.0
		
		var tile_shape = CylinderShape3D.new()
		tile_shape.radius = wall_radius
		tile_shape.height = height
		
		var tile_col = CollisionShape3D.new()
		tile_col.shape = tile_shape
		tile_col.position = tile.position + Vector3(0, center_y, 0)
		add_child(tile_col)

func _get_tile_surface_y(tile: HexTileData, height_step: float) -> float:
	if tile.current_state == TileConstants.State.STONE:
		if tile.has_meta("stone_height"):
			return tile.get_meta("stone_height")
		return (float(tile.height_level) * height_step) + 3.0
	return float(tile.height_level) * height_step
