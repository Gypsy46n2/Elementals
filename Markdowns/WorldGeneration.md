# World Generation — Hex Grid Generation System

This document describes the procedural hex grid generation system used to create the arena battlefield. It covers coordinate systems, terrain generation via noise, height mapping, farmstead layout planning, and the caching architecture that keeps neighbor lookups fast.

---

## 1. Overview

The `GridGenerator` class (`res://Components/Arena/GridGenerator.gd`) is responsible for:

- **Hex grid creation** with coordinate system conversion (offset ↔ axial)
- **Terrain generation** using Perlin noise to determine grass vs. dirt tiles
- **Height mapping** using noise to assign height levels to tiles
- **Farmstead planning** using flood-fill to designate interior and perimeter tiles
- **Feature placement data** exposing tile arrays used by `setup_farmstead()` to spawn house, fences, and the player actor
- **Neighbor and radius queries** with multi-level caching for O(1) lookups

The `GridGenerator` is instantiated by `ArenaGrid` during initialization and works alongside `HexGridRenderer`, `TileSystem`, and `ArenaPhysics` to produce the playable arena.

---

## 2. Coordinate Systems

The grid uses two coordinate systems that are converted back and forth throughout generation and runtime.

### 2.1 Offset Coordinates (Grid Space)

The grid is stored in **offset coordinates** (odd-Q variant), where:
- `column` increases rightward
- `row` increases downward
- Odd columns are offset by +0.5 rows relative to even columns

This matches Godot's visual layout and is what tiles store in `HexTileData.grid_coords`.

### 2.2 Axial Coordinates (Storage/Logic)

Internally, the generator converts offset coordinates to **axial coordinates** `(q, r)` for neighbor computation and radius queries:

```gdscript
# Offset to axial (odd-Q)
func offset_to_axial(col: int, row: int) -> Vector2i:
    var q = col
    var r = row - (col - (col & 1)) / 2
    return Vector2i(q, r)

# Axial to offset
func axial_to_offset(q: int, r: int) -> Vector2i:
    var col = q
    var row = r + (q - (q & 1)) / 2
    return Vector2i(col, row)
```

### 2.3 World Position (3D Space)

Hex tiles are positioned in 3D world space using flat-topped hexagon math:

```gdscript
func calculate_hex_position(column: int, row: int) -> Vector2:
    var offset = float(column % 2) * 0.5
    var x_position = (1.5 * float(column)) * arena.hex_size
    var z_position = (SQRT3 * (float(row) + offset)) * arena.hex_size
    return Vector2(x_position, z_position)
```

The `y` position is computed separately via `get_tile_surface_y()`, which factors in height level and whether the tile is stone.

---

## 3. Grid Initialization Flow

```
ArenaGrid._ready()
  └─ grid_generator.initialize_grid()
        ├─ Clear tile_data_grid, tile_counts, caches
        ├─ Initialize FastNoiseLite if not present
        ├─ Loop over grid bounds:
        │    ├─ Skip tiles outside the circular radius
        │    ├─ Assign GRASS/DIRT based on noise threshold
        │    ├─ Assign height_level from noise
        │    └─ Create HexTileData and add to renderer
        ├─ plan_farmstead()
        ├─ Post-process stone tiles (adjust for height)
        └─ Emit tile_counts_changed signal
```

### 3.1 Circular Arena Boundary

Tiles are generated in a rectangular loop but excluded if they fall outside the **circular radius** from center:

```gdscript
var radius = min(grid_width, grid_height) / 2
var center_axial = offset_to_axial(total_w / 2, total_h / 2)
...
if axial_distance(center_axial, tile_axial) > radius:
    continue  # Skip this tile
```

The edge tiles (distance == radius) become **STONE** walls, creating a natural circular boundary.

### 3.2 Terrain Assignment

Terrain type is determined by a **noise threshold** against Perlin noise:

```gdscript
if noise.get_noise_2d(float(x), float(y)) > _get_dirt_threshold():
    state = TileConstants.State.DIRT
else:
    state = TileConstants.State.GRASS
```

The threshold is read from `GameSettings` (default: 0.2). Lower threshold = more dirt; higher threshold = more grass.

### 3.3 Height Mapping

Height levels (0–3) are computed from the same noise field:

```gdscript
var nv = noise.get_noise_2d(float(x), float(y))
h_val = int(clamp(floor((nv + 1.0) * 2.0), 0, 3))
```

This maps the [-1, 1] Perlin range to [0, 3] height levels. Each level raises the tile surface by `height_step` units.

### 3.4 Stone Height Post-Processing

Stone tiles (the arena boundary) are post-processed to ensure smooth cliffs:

```gdscript
for tile in arena.tile_data_grid:
    if tile.current_state == TileConstants.State.STONE:
        # Find highest non-stone neighbor
        max_neighbor_h = max(max_neighbor_h, float(n.height_level) * arena.height_step)
        # Set stone height to match or exceed neighbors
        tile.set_meta("stone_height", max_neighbor_h + 2.0)
```

This prevents floating walls and ensures the stone perimeter flows naturally from the terrain.

---

## 4. Farmstead Planning

The farmstead is a player-controlled area where the house and fences are placed. Planning happens **before** features are spawned.

### 4.1 Flood-Fill Interior Tiles

`plan_farmstead()` uses BFS to carve out 10 interior tiles starting from the grid center:

```gdscript
var queue: Array[HexTileData] = [center_tile]
while farmstead_interior_tiles.size() < 10:
    var neighbors = get_neighbors(current)
    neighbors.shuffle()  # Randomize blob shape
    for n in neighbors:
        if n not in interior and n.current_state != STONE:
            farmstead_interior_tiles.append(n)
```

Shuffling neighbors produces a slightly irregular farmstead shape rather than a perfect blob.

### 4.2 Perimeter Tile Collection

Perimeter tiles are collected by checking all neighbors of interior tiles:

```gdscript
farmstead_perimeter_tiles = []
for tile in farmstead_interior_tiles:
    for n in get_neighbors(tile):
        if n not in interior and n not in perimeter and n.current_state != STONE:
            farmstead_perimeter_tiles.append(n)
```

### 4.3 House Placement

A random perimeter tile is selected for the house:

```gdscript
var house_idx = randi() % farmstead_perimeter_tiles.size()
house_tile = farmstead_perimeter_tiles[house_idx]
```

The remaining perimeter tiles receive fences in `setup_farmstead()`.

---

## 5. Farmstead Setup (Feature Spawning)

`setup_farmstead()` is called **after** grid generation and spawns physical features:

| Feature | Placement | Notes |
|---------|-----------|-------|
| **House** | `house_tile` | Player home; has `set_tile()` method |
| **Fences** | All perimeter tiles except house | Connect to neighbors via `update_connections()` |
| **Player Actor** | First interior tile | Spawned via `actor_spawner` at interior center |
| **Scarecrow** | Just outside yard | Training dummy for combat practice |

### 5.1 House Spawning

```gdscript
var house = arena.house_feature_scene.instantiate()
house.transform.origin = house_tile.position + Vector3(0, get_tile_surface_y(house_tile), 0)
arena.add_child(house)
house_tile.feature = house
```

### 5.2 Fence Spawning

```gdscript
for n in farmstead_perimeter_tiles:
    if n != house_tile and not n.feature:
        var fence = arena.fence_feature_scene.instantiate()
        fence.transform.origin = n.position + Vector3(0, get_tile_surface_y(n), 0)
        arena.add_child(fence)
        n.feature = fence
        fences.append(fence)
```

### 5.3 Connection Updates

After all fences are placed, `update_connections(arena)` is called on each to orient fence sprites visually:

```gdscript
for f in fences:
    if f.has_method("update_connections"):
        f.update_connections(arena)
```

---

## 6. Caching Architecture

Neighbor and radius lookups are hot paths used by AI, fire spread, and area effects. The generator uses **three levels of caching** to keep these O(1).

### 6.1 Neighbor Cache

`_neighbor_cache` stores neighbor arrays keyed by tile reference:

```gdscript
func get_neighbors(tile: HexTileData) -> Array[HexTileData]:
    if _neighbor_cache.has(tile):
        # Return a shallow copy — callers may shuffle/mutate
        var cached: Array = _neighbor_cache[tile]
        var result: Array[HexTileData] = []
        result.assign(cached)
        return result
    
    # Compute on miss and cache result
    var result: Array[HexTileData] = []
    var offsets = TileConstants.get_neighbor_offsets(tile.grid_coords.x)
    for offset in offsets:
        var n = get_tile_at_grid_coords(tile.grid_coords + offset)
        if n: result.append(n)
    
    _neighbor_cache[tile] = result
    return result
```

### 6.2 Tile Lookup Dictionary

`_tile_lookup` maps `Vector2i(grid_coords)` to `HexTileData` for O(1) random access:

```gdscript
func get_tile_at_grid_coords(x: int, y: int) -> HexTileData:
    return _tile_lookup.get(Vector2i(x, y), null)
```

### 6.3 Radius Offset Cache

`_radius_cache` precomputes axial offset patterns for radii 0–20:

```gdscript
func _build_radius_cache() -> void:
    for r in range(0, 21):
        _radius_cache[r] = _compute_radius_offsets(r)

func _compute_radius_offsets(radius: int) -> Array[Vector2i]:
    # Spiral outward using axial coordinate generation
    offsets.append(Vector2i(0, 0))  # Center always included
    if radius == 0: return offsets
    
    for dq in range(-radius, radius + 1):
        var r_start: int = max(-radius, -dq - radius)
        var r_end: int = min(radius, -dq + radius)
        for dr in range(r_start, r_end + 1):
            if dq == 0 and dr == 0: continue
            offsets.append(Vector2i(dq, dr))
    return offsets
```

`get_tiles_in_radius()` uses these precomputed offsets for O(radius) tile collection:

```gdscript
func get_tiles_in_radius(center: HexTileData, radius: int) -> Array[HexTileData]:
    var offsets = _radius_cache[radius]  # O(1) lookup
    for offset in offsets:
        var tile = _tile_lookup[center.axial + offset]
        if tile: results.append(tile)
    return results
```

---

## 7. Noise Configuration

Noise parameters are read from `GameSettings` when available:

| Parameter | Source | Default | Purpose |
|-----------|--------|---------|---------|
| `noise_seed` | `GameSettings.noise_seed` | `randi()` | Deterministic noise |
| `noise_frequency` | `GameSettings.noise_frequency` | `0.05` | Terrain chunk size |
| `height_step` | `GameSettings.height_step` | `1.0` | Height units per level |
| `dirt_threshold` | `GameSettings.dirt_threshold` | `0.2` | Grass/dirt boundary |

If `GameSettings` is not present, the generator falls back to random seed and defaults.

```gdscript
if not arena.noise:
    arena.noise = FastNoiseLite.new()
    arena.noise.noise_type = FastNoiseLite.TYPE_PERLIN
    if gs:
        arena.noise.seed = gs.noise_seed
        arena.noise.frequency = gs.noise_frequency
    else:
        arena.noise.seed = randi()
        arena.noise.frequency = 0.05
```

---

## 8. HexTileData Structure

Each tile is represented by a `HexTileData` object:

| Property | Type | Description |
|----------|------|-------------|
| `current_state` | `int` | `TileConstants.State` — GRASS, DIRT, MUD, FIRE, PUDDLE, STONE |
| `tile_type` | `int` | `TileConstants.Type` — derived from state, kept in sync |
| `position` | `Vector3` | World position (X, Z from hex math; Y from height) |
| `axial_coords` | `Vector2i` | Internal (q, r) coordinate |
| `grid_coords` | `Vector2i` | Visible (col, row) coordinate |
| `height_level` | `int` | 0–3, multiplied by `height_step` for surface Y |
| `feature` | `Node3D` | Tree, fence, house, etc. on this tile |
| `fire_duration` | `float` | Tracks fire spread timing |
| `mud_duration` | `float` | Tracks mud drying timing |
| `puddle_duration` | `float` | Tracks puddle drainage timing |

State-to-type synchronization happens automatically in `_sync_type()`:

```gdscript
match current_state:
    TileConstants.State.GRASS: tile_type = TileConstants.Type.GRASS
    TileConstants.State.DIRT: tile_type = TileConstants.Type.DIRT
    TileConstants.State.MUD: tile_type = TileConstants.Type.MUD
    TileConstants.State.FIRE: tile_type = TileConstants.Type.FIRE
    TileConstants.State.PUDDLE: tile_type = TileConstants.Type.PUDDLE
    TileConstants.State.STONE: tile_type = TileConstants.Type.STONE
```

---

## 9. ArenaGrid Export Variables

`ArenaGrid` exposes configuration values that control generation:

| Export | Default | Range | Purpose |
|--------|---------|-------|---------|
| `grid_width` | `20` | 1+ | Number of hex columns |
| `grid_height` | `20` | 1+ | Number of hex rows |
| `hex_size` | `1.5` | 0.1–10 | World units per hex center-to-center |
| `tile_scale` | `1.5` | 0.25–3.0 | Visual scale multiplier for tile meshes |
| `height_step` | `1.0` | any | World units per height level |
| `noise` | `null` | — | FastNoiseLite instance (created if null) |

`grid_width` and `grid_height` are overwritten by `GameSettings` if present.

---

## 10. Helper APIs

`GridGenerator` exposes utility methods used by `ArenaGrid`, features, and quest logic:

### 10.1 `get_tile_surface_y(tile: HexTileData) -> float`
Returns the Y position of a tile's surface. Stone tiles use the `stone_height` meta if set; otherwise they are raised by `height_step + 2.0`.

### 10.2 `has_adjacent_grass(tile: HexTileData) -> bool`
Returns `true` if any neighbor tile has `tile_type == GRASS`. Used by tree spawning and fire spread.

### 10.3 `get_adjacent_dirt(tile: HexTileData) -> HexTileData`
Returns the first neighboring dirt tile, or `null` if none exist. Used by feature placement rules.

### 10.4 `get_tiles_in_radius(center: HexTileData, radius: int) -> Array[HexTileData]`
Returns all tiles within `radius` hex steps of `center`. Uses precomputed offsets for O(radius) performance.

---

## 11. Integration Points

| System | Integration | Data Exchanged |
|--------|-------------|----------------|
| `ArenaGrid` | Owns `GridGenerator` instance | Grid size, hex size, noise config |
| `HexGridRenderer` | Receives tiles after generation | `tile_data_grid`, tile counts |
| `ArenaPhysics` | Builds collision from tile heights | Reads `height_level`, `stone_height` |
| `TileSystem` | Initializes tile timers | `check_activeness()` per tile |
| `ArenaSpawnerComponent` | Spawns player and enemies | Avoids farmstead interior/perimeter |
| `TreeSpawner` | Runs after grid is ready | Filters by `has_adjacent_grass()` |
| `TreeFeature` | Queries neighbors for pinecone spawning | `get_neighbors()`, `get_tile_surface_y()` |
| `QuestSpawnManager` | Places quest camps away from farmstead | Avoids interior/perimeter tiles |

---

## 12. Data Model Summary

| Variable | Type | Purpose |
|---------|------|---------|
| `farmstead_interior_tiles` | `Array[HexTileData]` | Core yard area (~10 tiles) |
| `farmstead_perimeter_tiles` | `Array[HexTileData]` | Fence/house placement ring |
| `house_tile` | `HexTileData` | Where the house feature is placed |
| `_neighbor_cache` | `Dictionary` | Tile → neighbors lookup |
| `_tile_lookup` | `Dictionary` | `Vector2i` → `HexTileData` lookup |
| `_radius_cache` | `Dictionary` | Radius → axial offset patterns |

---

## 13. Known Limitations

- **Grid shape**: Always circular due to radius culling. Future work (per `MapExpansion.md`) will support rectangular biomes and region transitions.
- **Farmstead size**: Fixed at 10 interior tiles. This should eventually be configurable via `GameSettings`.
- **Noise type**: Hardcoded to `TYPE_PERLIN`. Other noise types (simplex, cellular) are not exposed but could be added.
- **Height levels**: Capped at 0–3. The formula `(nv + 1.0) * 2.0` is hardcoded; it should be parameterized.

---

_End of document_