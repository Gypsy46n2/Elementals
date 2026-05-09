# Settlement — Implementation Plan

> **Current state:** Single-file React component (`Settlement.jsx`) with core goat management loop — breeding, milking, selling, stamina, and basic SVG rendering. All state lives in one component via `useState`.

---

## Vision

Transform Settlement from a single-screen manager into a light simulation game with a **dependency graph** at its core — buildings unlock from goat outputs, outputs feed the economy, and the settlement grows organically from a small pasture into a functioning homestead. Inspired by Fantasy Town Generator's two-phase approach: *build the data model first, render second.*

---

## Proposed File Hierarchy

```
Settlement/
├── Settlement.jsx                  # Root component — layout, tab routing, global state
│
├── constants/
│   ├── goats.js                   # COAT_COLORS, PATTERN_COLORS, HORN_TYPES, BODY_TYPES
│   ├── buildings.js               # Building definitions, costs, unlock conditions
│   ├── events.js                  # Random event pool, weighted triggers
│   └── economy.js                 # Item prices, market rates, resource values
│
├── engine/
│   ├── goatFactory.js             # makeGoat(), createOffspring(), blendStat()
│   ├── dependencyGraph.js         # Building unlock logic, resource tracking
│   ├── simulation.js              # nextDay() logic, pregnancy, aging, events
│   └── economy.js                 # Gold calculations, market fluctuation
│
├── state/
│   ├── useSettlementState.js      # Master state hook — herd, gold, buildings, day
│   ├── useSelection.js            # Doe/buck selection state
│   └── useToast.js                # Toast queue management
│
├── components/
│   ├── goat/
│   │   ├── GoatCard.jsx           # Card tile with stats and status badges
│   │   ├── GoatIcon.jsx           # SVG goat renderer
│   │   ├── StatBars.jsx           # STR/TGH/INT/SPD/STA/BRD bars
│   │   ├── ColorChip.jsx          # Coat color label chip
│   │   └── OffspringPreview.jsx   # Blended color preview for breeding pair
│   │
│   ├── buildings/
│   │   ├── BuildingSlot.jsx       # Unlocked/locked building tile
│   │   ├── BuildingPanel.jsx      # Detail panel for a selected building
│   │   └── DependencyTree.jsx     # Visual unlock tree (optional, later phase)
│   │
│   ├── map/
│   │   ├── SettlementMap.jsx       # Top-down pasture/building layout view
│   │   ├── Pasture.jsx            # SVG pasture zone with goats placed in it
│   │   └── BuildingSprite.jsx     # SVG building icons for map view
│   │
│   ├── ui/
│   │   ├── Toast.jsx              # Toast notification
│   │   ├── Btn.jsx                # Shared button component
│   │   ├── StatBar.jsx            # Generic single stat bar
│   │   └── TabBar.jsx             # Tab navigation bar
│   │
│   └── panels/
│       ├── HerdPanel.jsx          # Current herd tab — does/bucks/selected columns
│       ├── BuildingsPanel.jsx     # Settlement buildings tab
│       ├── MarketPanel.jsx        # Buy/sell/trade tab
│       ├── JournalPanel.jsx       # Log/journal tab
│       └── DevPanel.jsx           # Developer options panel
│
└── utils/
    ├── color.js                   # hexToRgb(), lerpHex(), closestColorKey(), luminance(), contrastColor()
    └── random.js                  # rnd(), pick(), weighted picks
```

---

## Phase 1 — Refactor & Extract *(no new features)*

**Goal:** Break the monolithic JSX into the structure above without changing any behavior. Ship a cleaner foundation before adding systems.

### Tasks

- Extract all utility functions into `utils/color.js` and `utils/random.js`
- Move constants to `constants/goats.js`
- Extract `makeGoat()`, `createOffspring()`, `blendStat()` into `engine/goatFactory.js`
- Pull `GoatIcon`, `GoatCard`, `StatBars`, `ColorChip`, `OffspringPreview` into `components/goat/`
- Pull `Toast`, `Btn` into `components/ui/`
- Pull `HerdPanel` and `JournalPanel` content out of the root component
- Move `nextDay()` and milking/selling/breeding logic into `engine/simulation.js`
- Create `useSettlementState.js` as a single custom hook exposing all state + actions

**Exit criteria:** App behaves identically, all logic is testable in isolation.

---

## Phase 2 — Dependency Graph & Buildings

**Goal:** Introduce a building system where goat outputs (milk, kids, fiber) unlock structures, which in turn produce new resources and economic options.

### Building Definitions (`constants/buildings.js`)

Each building is an object:

```js
{
  id: "dairy_shed",
  name: "Dairy Shed",
  description: "Increases milk yield and unlocks cheese making.",
  cost: { gold: 60 },
  requires: {
    buildings: [],          // must exist first
    resources: { milk: 20 } // cumulative threshold to unlock
  },
  produces: { cheese: true },
  modifiers: { milkYieldMultiplier: 1.5 },
  maxCount: 1,
}
```

Planned building tree (rough):

```
Pasture (default)
├── Dairy Shed          — requires 20 cumulative milk
│   └── Creamery        — requires Dairy Shed + 10 cheese
│       └── Market Stall — requires Creamery, unlocks price boosts
├── Breeding Pen        — requires 3 successful breeds
│   └── Kid Nursery     — reduces kid mortality/loss events
│       └── Stud Service — sell breeding access to other settlements (gold/day)
├── Hay Barn            — reduces stamina loss on bad-weather days
│   └── Feed Mill       — converts grain→feed, boosts all stamina recovery
└── Tannery             — requires selling 5+ goats
    └── Leatherworks    — converts hides to leather goods (high gold value)
```

### Dependency Graph Engine (`engine/dependencyGraph.js`)

- Tracks cumulative resource totals (milk ever produced, kids ever born, goats ever sold)
- On each `nextDay()`, re-evaluates which buildings are newly unlocked
- Returns ordered list of "available to build" based on what player can afford + has unlocked

---

## Phase 3 — Economy & Market

**Goal:** Replace flat `goldValue` sell prices with a living market.

### Features

- **Market tab** (`panels/MarketPanel.jsx`) — lists available goods with current prices
- **Price fluctuation** — each `nextDay()` slightly adjusts prices within a range per item
- **Supply/demand** — selling a lot of milk in short succession drives its price down
- **Processed goods** — cheese, leather, yarn sell for 3–5× raw material value
- **Buy feed/supplies** — gold sinks to prevent hoarding (feed improves stamina recovery rate)

### Economy constants (`constants/economy.js`)

```js
export const BASE_PRICES = {
  milk:    2,   // per liter
  cheese:  8,   // per unit
  kid:     30,  // base (modified by stats)
  hide:    6,
  leather: 22,
  yarn:    12,
};
```

---

## Phase 4 — Settlement Map View

**Goal:** Add a top-down visual map of the settlement — pasture zones, building footprints, goats wandering.

Inspired by Fantasy Town Generator's two-phase approach: generate the data first, then render the map from it.

### Approach

- `SettlementMap.jsx` reads from settlement state (buildings built, herd count, day/time)
- Buildings are placed into static zones (not procedural yet — fixed layout grid)
- Goats rendered as small SVG icons scattered in the pasture zone
- Time-of-day indicator: goats cluster near barn at night, spread out during day
- Buildings animate slightly when "active" (dairy shed pulses when milk is ready)

### Map zones (initial layout)

```
┌─────────────────────────────────┐
│  [Forest edge / outer border]   │
│  ┌──────────┐  ┌─────────────┐  │
│  │ Pasture  │  │  Buildings  │  │
│  │ (goats)  │  │   (grid)    │  │
│  └──────────┘  └─────────────┘  │
│       [Road / path]             │
│  ┌──────────────────────────┐   │
│  │  Outer fields / farmland  │  │
│  └──────────────────────────┘   │
└─────────────────────────────────┘
```

---

## Phase 5 — Events & Simulation Depth

**Goal:** Make days feel meaningful with weighted random events and seasonal cycles.

### Event types (`constants/events.js`)

```js
{ id: "wild_herbs",   weight: 3, effect: "does_toughness_+1",   msg: "Wild herbs! Does gain +1 toughness." },
{ id: "coyote_raid",  weight: 1, effect: "random_kid_lost",      msg: "A coyote raided the pen overnight!" },
{ id: "good_weather", weight: 5, effect: "stamina_bonus_day",    msg: "Beautiful day. All goats recover +1 stamina." },
{ id: "merchant",     weight: 2, effect: "market_price_boost",   msg: "A merchant raises cheese prices for 3 days." },
{ id: "disease",      weight: 1, effect: "herd_toughness_-1",    msg: "A mild illness spreads through the herd." },
```

### Seasons

- 4 seasons × ~30 days each
- Winter: milk yields drop, stamina recovery slows, feed costs increase
- Spring: breeding chance boost, kid survival up
- Summer: milk peak, market prices for dairy up
- Autumn: harvest bonus, good time to sell

---

## Phase 6 — Persistence

**Goal:** Save/load settlement state so progress survives page refresh.

### Approach

- Use `localStorage` with a versioned save schema
- `useSettlementState.js` initializes from saved state if present
- Manual "Save" button + auto-save on `nextDay()`
- Export save as JSON (for backup / sharing)

```js
const SAVE_SCHEMA_VERSION = 1;

const saveState = {
  version: SAVE_SCHEMA_VERSION,
  day, gold, milkTotal,
  herd: herd.map(serializeGoat),
  buildings: buildings.map(serializeBuilding),
  resources,
  marketPrices,
};
```

---

## Implementation Priority

| Phase | Effort | Value | Do When |
|-------|--------|-------|---------|
| 1 — Refactor | Medium | High (foundation) | First |
| 2 — Buildings | High | High (core loop) | Second |
| 6 — Persistence | Low | High (retention) | After Phase 2 |
| 3 — Economy | Medium | Medium | After Phase 6 |
| 5 — Events | Low | High (feel) | Alongside Phase 3 |
| 4 — Map | High | Medium (visual) | Last |

---

## Open Questions

- **Fiber/wool system?** Some goat breeds produce fiber — could be a parallel resource track to milk.
- **Named lineages?** Tracking bloodlines (doe A → kid B → kid C) for breeding optimization UI.
- **Multiplayer / leaderboard?** Out of scope for now but the persistent save format should not foreclose it.
- **Mobile layout?** Current 3-column herd view gets tight on narrow screens — Phase 1 refactor is a good time to audit.

---

*Last updated: Day 1 of the settlement.*
