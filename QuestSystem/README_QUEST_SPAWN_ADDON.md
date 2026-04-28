# Quest Spawn Addon - Death/Kill Tracking Fix

Drop this patch into the root of the Elementals project and allow overwrites.

## Fixes included

- Quest kills now track from actual `GameEvents.actor_died` events.
- Quest enemies are tracked by metadata, instance id, groups, and actor type fallback.
- Player/controlled actor death now fails the active quest and clears it from save state.
- Failed or abandoned quests despawn any remaining quest-spawned enemies.
- Quest enemies still spawn through `Components/Arena/ArenaSpawner.gd`.
- Random wild goats now spawn through `ArenaSpawner` during arena startup.
- Quest goblins remain hostile goblins and do not use the selected player/goat actor type.

## Test flow

1. Open the arena.
2. Confirm wild goats appear in the arena as wildlife.
3. Walk to the Quest Board near the farm/spawn.
4. Press `B`, accept Goblin Cleanup.
5. Kill the quest goblins.
6. The tracker should update `1/3`, `2/3`, `3/3` and pay gold.
7. Accept another quest, then let the player/controlled actor die.
8. The tracker should clear and the quest should not remain active on the next play.

© 2026 Micheal Chapin


FIX NOTES - SMALL BOARD/KILL PATCH:
- B only opens the quest board when the player is currently within board range.
- Goblin bounty objectives now count quest-spawned goblins and existing/random map goblins.
- Existing saved quests using the older quest_goblin target still receive goblin kill credit.
