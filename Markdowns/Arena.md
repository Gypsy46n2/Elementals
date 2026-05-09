# Arena Overview

## Scene layout (`res://Play Space/Arena.tscn`)
- The root node is a `Node3D` named `Arena` with the `ArenaGrid` script (`res://Play Space/Arena.gd`). It collects camera, lighting, UI, and console layers for the playable encounter.
- Children include `Camera3D` (with the `CameraFollower` script), a directional light, a `CanvasLayer` named `UI` (quest tracker, minimap frame, options button, options menu), and a `PlayerConsole` UI layer that displays actor cards and controls.

## ArenaGrid responsibilities
- `ArenaGrid` manages the entire hexagonal battlefield: tile generation, rendering, physics, actor lifecycles, input orchestration, UI hooks, quest wiring, and modular components such as minimap and tile signals.
- It exposes export variables for grid width/height, hex size, tile scale, and noise parameters, and it preloads tile feature scenes (trees, houses, fences).
- Key data structures include `tile_data_grid` (list of `HexTileData`), `tile_counts` (state histogram), `actors` (spawned entities), and helpers like `farmstead_interior_tiles`, `farmstead_perimeter_tiles`, and `house_tile` (provided by `GridGenerator`).

### Initialization flow (`_ready`)
1. Reads persisted grid size from `/root/GameSettings` (if available).
2. Calls `_setup_components()` to instantiate clock, renderer, tile system, physics, tile interaction, tile signal, actor spawner, player input, UI handler, minimap handler, and grid generator.
3. Generates the grid (`grid_generator.initialize_grid()`), applies physics (`_setup_physics()`), builds the farmstead (`grid_generator.setup_farmstead()`), spawns initial actors, and registers the arena in the `arena` group.
4. Selects the initial controllable actor via `PlayerInputComponent`, hooks `GameEvents.actor_died` to `_on_actor_died`, wires quest HUD toggles, optionally loads the `QuestStarterKit`, and registers static obstacles with `TileSignalComponent` for AI awareness.

### Component summary
- **HexGridRenderer**: Renders tiles, updates fire effects, and works with `GrassPatchLayer` to display surface details.
- **TileSystem**: Schedules and processes tile reactions (fire spreads/extinguishes, mud dries, puddles drain) using timers rather than per-frame loops, and exposes `process_tiles`/`check_activeness` for the arena.
- **ArenaPhysics**: Builds a large base cylinder as the arena floor and creates per-tile `CollisionShape3D` cylinders to match tile height. Offers `update_tile_collision` to keep collisions in sync with state changes.
- **ArenaTileInteractionComponent**: Handles elemental applications (fire/water) on tiles and delegates to features via `DamageComponent` when needed.
- **TileSignalComponent**: Tracks actors per tile, lets other systems register triggers with radius checks, and emits `trigger_activated`/`trigger_deactivated` when actors enter/exit those zones. `ArenaGrid` registers static obstacles (trees, fences, stone) so enemies can query around them.
- **ArenaSpawnerComponent**: Controls spawning of goblins, goats, quest actors, scarecrows, and the player-selected unit. It randomizes spawn tiles while avoiding the farmstead interior/perimeter, configures faction membership, and logs each spawn.
- **PlayerInputComponent**: (Instantiated and configured in `_setup_components`) manages the currently controlled actor, selection cycling, and input handling (details reside in the component).
- **ArenaUIHandler**: Adds a reticle, hooks previous/next buttons to `PlayerInputComponent`, wires the options button to `OptionsMenu`, adds a "Finish Day" button that emits `GameEvents.day_finished`, updates the actor stats label, and reacts to actor health/mana changes.
- **ArenaMinimapHandler**: Captures the HexGridRenderer output via a dedicated `SubViewport`, lays out actor/quest markers, throttles updates, and responds to quest signals (`QuestEvents`) to highlight camps.
- **GridGenerator**: Builds the hex grid using noise (with seeds from `GameSettings`), caches neighbors, plans the farmstead/fence layout, places trees, and exposes helper APIs (`calculate_hex_position`, `get_neighbors`, `get_tiles_in_radius`, etc.). It also spawns the physical house feature and media (fences, scarecrow) for the yard.

### Tile & actor utilities
- `ArenaGrid` proxies utilities to `GridGenerator`: `_get_tile_surface_y`, `_get_neighbors`, `_has_adjacent_grass`, `_get_adjacent_dirt`, `get_tile_at_grid_coords`, and `get_tiles_in_radius`. These are used throughout `TreeFeature`, quest logic, and physics.
- `set_tile_state` updates renderer visuals, manages fire effects, recomputes `tile_counts`, emits `tile_counts_changed`, regenerates `GrassPatchLayer`, and wakes up `TileSystem` neighbors.
- `get_tile_data_at_world_position` converts world coordinates to hex tiles with axial math, supporting targeting/player placement.
- `apply_element_to_tile` on `ArenaGrid` delegates to `ArenaTileInteractionComponent` to keep actor/projectile code decoupled from the arena implementation.
- `_on_actor_died` removes actors from the list, checks for playable actor deaths to fail quests, advances to the next actor, and triggers game-over logic via `ArenaUIHandler` when all friendlies are gone.

## Visual polish & layers
- `GrassPatchLayer` (a child of `ArenaGrid`) populates organic grass patches after generation. It caches RNG seed data, scatters blobs across green tiles, and rebuilds when tile states change.
- The UI contains: `QuestTrackerHUD` (instanced quest tracker), `QuestTrackerToggle` (checkbox to show/hide the tracker), `MinimapFrame` (with `SubViewport`, debug toggle, and marker overlay managed by `ArenaMinimapHandler`), `OptionsButton/Menu` (with goat controls that query `get_tree().get_first_node_in_group("arena")`), and the `PlayerConsole` layer to monitor active actors.

## Integration points & helpers
- `GameEvents`: Actor death, day finished, and other global signals tie into the arena lifecycle (e.g., `_on_actor_died`, `_on_finish_day_pressed`).
- `QuestSystem`: `ArenaGrid` sets up the optional `QuestStarterKit`, `ArenaUIHandler` toggles the quest HUD, and `ArenaMinimapHandler` registers quest markers by listening to `QuestEvents`.
- `OptionsMenu` inspects the `arena` group to adjust goat-specific controls via `current_controlled_actor` metadata.
- `ArenaDebug` (a `VBoxContainer`) also grabs the first arena in the scene tree, listens to `tile_counts_changed`, exposes spawn buttons (fire/water/goat), and toggles visibility when the debug checkbox is pressed.
- `TreeFeature` and `TreeStates` rely on `ArenaGrid` (via `get_parent() as ArenaGrid`) to look up tile neighbors, set tile states, and spawn pinecones.

## Summary
The arena is a self-contained hex field powered by `ArenaGrid` and its modular subcomponents. It handles generation, rendering, tile/actor state, physics collisions, AI triggers, minimap/UI wiring, and quest integration. Every system that needs tile data, actor context, or global events can look up the `ArenaGrid` instance (typically via the `arena` group) and rely on its helpers (`get_tiles_in_radius`, `set_tile_state`, `actors`, `tile_signals`, etc.). With this architecture, the rest of the game (actors, quests, items) can remain focused on behavior instead of grid bookkeeping.
