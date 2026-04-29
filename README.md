# Elementals: Arena & Ranch
<img width="1152" height="648" alt="image" src="https://github.com/user-attachments/assets/4e340b84-57d7-4a75-a1d4-c8f0fc56fdb0" />


**Elementals** is an arena combat simulator that blends tactical hex-based combat with creature ranching and breeding mechanics. Lead your team of specialized goats (and other actors) through elemental battlefields, manage your herd back at the ranch, and breed the ultimate champions.

Weapons are working, I have thrown weapon mechanics in play that allow actors to pick up thrown weapons or shot arrows to use themselves.
A few abilities have been implemented and the stat system seems to be working as intended (so far).

Actual breeding and capture mechanics are broken at the moment.

---

## 🎮 Core Gameplay Loops

### 🏟️ Arena Combat Simulator
Step into a procedurally generated hexagonal arena where the environment is as dangerous as your enemies.
*   **Tactical Hex-Grid**: Navigate diverse terrain including grass, dirt, and height-varied tiles.
*   **Elemental Interactions**: Utilize a dynamic tile system. Set grass ablaze with fire, douse flames with water, or watch fire spread naturally across the grid.
*   **Dynamic Actors**: Control a variety of units from **Farmers** to specialized **Goats**, each with their own stats, abilities (like *Goat Charge* or *Nimble Escape*), and equipment.
*   **Physics-Based Interaction**: Projectiles and abilities interact with the 3D environment and tile states.

### 🚜 Ranching & Breeding
Between battles, return to your ranch to manage your growing herd.
*   **Herd Management**: Track your goats' levels, stats (Strength, Dexterity, Constitution, etc.), and health.
*   **Breeding System**: Pair Does and Bucks to produce offspring. Kids inherit traits and stats from their parents, allowing for long-term progression and optimization.
*   **Economy & Progression**: Sell goats for gold, advance through days, and build up your ranch's resources.
*   **Planned Mechanics**: Future updates will include **Creature Capture** mechanics to expand your herd from the wild.

---

## 🛠️ Technical Features

*   **Component-Based Architecture**: Actors and systems are built using modular components (Health, Mana, AI, Movement, etc.) for easy extensibility.
*   **Advanced Hexagonal Grid**: Custom-built `ArenaGrid` handles noise-based generation, feature placement (trees, fences, houses), and efficient world-to-grid coordinate conversion.
*   **Centralized Data Management**: `GoatManager` orchestrates sub-systems for Breeding, Economy, Herd state, and Persistence.
*   **Robust Save System**: Automatic state preservation for your herd, gold, and world progress.

---

## 🚀 Getting Started

1.  **Main Menu**: Start a new game or continue your progress.
2.  **Character Select** Farmers and Goblins are currently working, playing farmer is for masochists.
3.  **The Ranch**: [Currently Busted] Select your team of up to 4 goats. Check their stats and ensure they are ready for combat.
4.  **Enter Arena**: Battle against enemies like Goblins. Use the environment to your advantage—lure enemies into fire or use height for better positioning.
5.  **Advance the Day**: Back at the ranch, advance the day to process pregnancies and recover.

---

## 🗺️ Roadmap
*   **Creature Capture**: Tools and mechanics to tame wild creatures encountered in the arena.
*   **Expanded Ranching**: More buildings (Fences, Barns) and interaction types.
*   **Deeper Genetic Traits**: More complex inheritance patterns and unique mutations.
*   **Elemental Magic**: More elemental types (Earth, Air) and complex tile reactions.
*   **Expanded Map Generation** I plan to rework the basic map generation to create a tesselating pattern with varying noisemaps for different biomes and map types to explore

Here’s what I learned about how the goblin camp spawning system works in this project:

---

### 1. **Bootstrapping the quest/camp system**
- The `QuestStarterKit` node (installed on the arena via `setup`) is the entry point. It clears any previous `QuestState.active_quests`, makes sure the arena has the supporting nodes (`QuestSpawnManager`, `TileSignalComponent`, quest HUD/UI layers, and the 3D World Board), and then calls `setup` on each so they can wire themselves to the arena.
- The `QuestSpawnManager` registers listeners for `QuestEvents` (spawn requested, failed, completed, etc.) and `GameEvents.actor_died`, and defers a call to `_designate_all_camp_tiles` so camps can be pre-placed once the arena is ready.

---

### 2. **Designating camps ahead of time**
- `_designate_all_camp_tiles` pulls every quest definition from `QuestDatabase`, reads each quest’s spawn data (`count`, `camp_count`, `camp_size`, etc.), and assigns the camps to tiles near each map edge (north, south, east, west) in a round-robin order.
- For each designated tile it:
  - Records the tile, world center, quest ID, and spawn metadata in `_designated_camps`.
  - Registers a proximity trigger with `TileSignalComponent.register_trigger` (radius 8) so the camp is “discovered” the moment the player gets close enough.
  - Calls `_register_camp_data` to populate `camp_records_by_id` with the camp’s center, expected goblin count, size, and placeholders for future visuals/marker nodes.
- Once all quests have camps placed, `QuestEvents.camps_designated` is emitted so other systems (minimap, UI) can refresh.

---

### 3. **Discovery, visual effects, and spawning**
- When the player hits a trigger, `_on_camp_trigger_activated` calls `_activate_camp_for_quest`. That method:
  - Ensures the camp is still list­ed in `_designated_camps` and hasn’t been “visualized” yet.
  - Builds the camp visuals (`_build_goblin_camp_visual`): a `Node3D` root with rocks, tents, crates, optional banners, plus a `QuestCampMarker` (a billboarded beacon and label) and a campfire (smoke effect or fallback geometry).
  - Stores the visual root/marker in `camp_records_by_id` and toggles marker visibility based on whether the quest is active (`QuestState.active_quests`).
  - Calls `_spawn_enemies_at_designated_camp`, which uses the quest’s spawn metadata to determine the actor type (usually “goblin”), how many goblins per camp, and the spawn radius.
- `_spawn_enemies_at_designated_camp` delegates to `_spawn_camp_actor`, which prefers `ArenaSpawnerComponent.spawn_quest_actor_near` (and falls back to `spawn_quest_actor` or `spawn_actor_at_tile`) so quest enemies obey the arena’s “safe” spawning rules and faction setup.
- Every spawned actor is configured via `_configure_spawned_actor`: metadata tags (`quest_id`, `camp_id`, etc.), quest-related groups, a human-readable name, and faction setup (GOBLINS/WILDLIFE/MONSTERS). Records are stored in `spawned_records_by_instance_id` and `spawned_by_quest` for cleanup/credit.
- `_add_actor_to_camp` keeps the camp’s actor list up to date, and `_update_camp_marker` updates the world marker label with the number of remaining goblins. When a camp is cleared (actors list empty), the marker is queued to `queue_free` and `record["cleared"]` is set so the minimap/UI stop showing it.

---

### 4. **Quest activation and notification**
- When a quest spawn is requested (`QuestEvents.quest_spawn_requested`), `_on_quest_spawn_requested`:
  - Sets `_active_quest_id`, sends a “Quest accepted” banner via `QuestEvents.message`, and toggles world marker visibility (`_update_all_camp_marker_visibility`).
  - Calls `_check_for_pre_cleared_camps` to turn already-cleared camps into kill credit (`QuestState.notify_kill`) if the player had previously cleared the camp before accepting the quest.
  - Forces the `TileSignalComponent` to evaluate the player’s current tile so the camp they’re standing near is activated immediately if applicable.
- The quests hook into `_on_quest_failed`/_`completed` to despawn actors, reset designated camps (`spawned`/`visuals_spawned` flags), and restore `_active_quest_id`. This keeps the system ready for the next attempt.

---

### 5. **Actor lifecycle, kill tracking, and credit**
- `_on_actor_died` listens for every actor death. It:
  - Detects player deaths and fails the active quest if necessary.
  - Looks up the dead actor using `_record_for_actor`, which consults `spawned_records_by_instance_id`, actor metadata, or group membership to determine the quest target ID/camp.
  - Calls `_kill_target_candidates` to build a prioritized list of candidate kill IDs (the actor’s `target_id`, `actor_type`, faction names, etc.) and feeds those into `QuestState.notify_kill`, ensuring kill credit works even if actors have varying metadata.
  - Updates camp markers via `_update_camp_marker` to reflect how many goblins remain, and cleans up the record via `_cleanup_actor_record`.
- Clean‑up helpers (`_despawn_live_quest_actors`, `_remove_quest_camps`, `_cleanup_actor_record`, `_clear_old_dead_refs`) keep `spawned_by_quest` and `camp_records_by_id` free of stale entries when quests end.

---

### 6. **Minimap and UI integration**
- `ArenaMinimapHandler` listens for the same quest events and `QuestEvents.camps_designated` so it can refresh/minimap markers that represent each camp. It grabs the camp records via `_get_camp_records(spawn_manager)` and spawns `MinimapQuestMarker` controls that track the camp centers.
- Each minimap marker is updated every `_process` tick, clamped to the minimap container, and hidden when the camp is marked “cleared”.
- The world marker created by `_build_goblin_camp_visual` contains a `Label3D` showing “QUEST CAMP\nN goblins left”, which is kept in sync by `_update_camp_marker`.

---

### 7. **Tile-based discovery triggers**
- `TileSignalComponent` is instantiated by `QuestStarterKit` and hooks into the current player actor’s `tile_changed` signal.
- When the player moves, `_on_player_tile_changed` checks triggers stored on the tile and any proximity-based triggers (via hex distance computation). Each quest camp registers a trigger with `radius = 8` and metadata (`quest_id`, `camp_index`, `camp_id`), so approaching a camp automatically fires `_on_camp_trigger_activated`.
- On quest acceptance, `QuestSpawnManager` explicitly nudges `TileSignalComponent` with the current tile to ensure immediate detection.

---

### 8. **Additional spawning path**
- `spawn_quest_enemies` is a more “on-demand” path that clears any existing quest actors/camps for the quest, then spawns new camps around the player within configurable `radius_min`, `radius_max`, and spacing constraints. It uses `_get_camp_tile` (which leverages `ArenaSpawnerComponent.get_quest_camp_tile`) to respect spacing, avoid blocked tiles, and avoid reusing existing camp centers.
- This method is useful if a quest needs to spawn camps dynamically instead of relying on pre-designated edge camps. It still calls `_create_camp_record`, `_spawn_camp_actor`, and `_update_camp_marker` so all UI/tracking code works the same way.

---

### Summary
The goblin camp system is built around `QuestSpawnManager`, which pre-places camp trigger data, spawns visuals and enemies on discovery, tracks quest-specific actors, and reports progress via `QuestEvents`/`QuestState`. `QuestStarterKit` ensures the manager, tile signal component, and HUD/UI are present. `TileSignalComponent` detects the player’s proximity to camp tiles and fires the spawn logic, while `ArenaMinimapHandler` and the camp marker nodes surface that information in the HUD/world. Cleanup hooks tied to quest completion/failure keep the system reusable. All actor spawning routes through `ArenaSpawnerComponent`’s quest-safe APIs so goblins respect the arena’s rules. No code or asset changes were made for this report.
