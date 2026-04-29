# Goatlandia / Elementals Goblin Camp Fire Smoke Marker Patch

Drop this patch into the root of the Godot project and allow overwrite.

## What this changes

- Replaces the simple procedural campfire cylinder in goblin quest camps with the uploaded 3D fire/smoke scene.
- Keeps the existing camp layout, goblin spawning, QUEST CAMP marker label, kill tracking, and camp cleanup behavior.
- The fire/smoke scene is stored under `QuestSystem/CampMarkerFire/` so it will not collide with the project's root `Scenes`, `Models`, or `Shaders` folders.
- If the fire/smoke scene fails to load, the old simple campfire cylinder is used as a fallback so camp spawning does not break.

## Patched files

- `QuestSystem/QuestSpawnManager.gd`
- `QuestSystem/CampMarkerFire/QuestCampFireSmoke.tscn`
- `QuestSystem/CampMarkerFire/Scenes/3d_fire.tscn`
- `QuestSystem/CampMarkerFire/Scenes/smoke_particle_1.tscn`
- `QuestSystem/CampMarkerFire/Scenes/smoke_particle_2.tscn`
- `QuestSystem/CampMarkerFire/Shaders/ToonFire.gdshader`
- `QuestSystem/CampMarkerFire/Shaders/ToonSmoke.gdshader`
- `QuestSystem/CampMarkerFire/Shaders/ToonSmokeOutline.gdshader`
- `QuestSystem/CampMarkerFire/Models/timber.obj`

## Test

1. Open the arena.
2. Go to the quest board.
3. Accept a goblin camp quest.
4. Follow the QUEST CAMP marker.
5. The camp center should now have animated 3D fire/smoke instead of the old simple fire cylinder.
6. Kill the camp goblins. The marker and camp should still clear normally.
