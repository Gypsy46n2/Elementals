# Elementals: Arena & Ranch

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
2.  **The Ranch**: Select your team of up to 4 goats. Check their stats and ensure they are ready for combat.
3.  **Enter Arena**: Battle against enemies like Goblins. Use the environment to your advantage—lure enemies into fire or use height for better positioning.
4.  **Advance the Day**: Back at the ranch, advance the day to process pregnancies and recover.

---

## 🗺️ Roadmap
*   **Creature Capture**: Tools and mechanics to tame wild creatures encountered in the arena.
*   **Expanded Ranching**: More buildings (Fences, Barns) and interaction types.
*   **Deeper Genetic Traits**: More complex inheritance patterns and unique mutations.
*   **Elemental Magic**: More elemental types (Earth, Air) and complex tile reactions.


