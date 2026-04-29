# Quest Goblin Camp Patch for Elementals / Goatlandia

Drop this zip into the root of the Godot project and allow overwrite.

## What this patch changes

- Quest board bounties no longer scatter loose goblins randomly.
- Accepting a goblin quest now creates one or more visible goblin camps.
- Goblins spawn clustered around the camp through `Components/Arena/ArenaSpawner.gd`.
- Each camp gets a floating `QUEST CAMP` marker.
- The marker updates with how many spawned camp goblins are still alive.
- The marker disappears once that camp is wiped out.
- Quest completion/failure clears leftover quest camp markers, props, and spawned quest goblins.
- Existing non-quest goblins still count toward goblin kill objectives so the last fix is not regressed.

## Files patched

- `Components/Arena/ArenaSpawner.gd`
- `QuestSystem/QuestSpawnManager.gd`
- `QuestSystem/quests.json`

## Test

1. Open the arena.
2. Walk to the Quest Board.
3. Accept `Small Goblin Camp`.
4. Follow the gold quest marker.
5. Kill the camp goblins.
6. The camp marker should disappear when the camp is dead.
7. The quest should complete and pay gold when the objective count is met.

No `.ziva` files are included.
