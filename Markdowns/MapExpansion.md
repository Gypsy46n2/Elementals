# Map Expansion — Formal Plan

**Version:** 1.0  
**Date:** 2023‑11‑XX  
**Prepared by:** Level Design & Engine Integration Team  

---

## 1. Introduction

The current world map is enclosed by uniform, tall stone walls that limit exploration. This plan outlines a comprehensive approach for enabling map expansion through procedural terrain, dynamic edges, region transitions, and quest-driven unlocks. The intention is to provide designers with the tools to open new territories on demand while maintaining narrative and mechanical consistency.

---

## 2. Objectives

1. **Dynamic Boundary Representation**  
   Replace or supplement the existing stone walls with a variety of edge types (mountains, oceans, and open frontier passages) that can be configured per region edge.

2. **Consistent Edge‑to‑Edge River Systems**  
   Guarantee that rivers traverse from one edge of a region to another at a coherent elevation to reinforce geographic continuity.

3. **Height Variation and Verticality**  
   Introduce pronounced elevation changes—such as ravines, canyons, plateaus, and cliffs—by leveraging procedural height maps and slope analysis.

4. **Expandable Map Edges**  
   Allow regions to specify variable openable edges (up to four cardinal directions) that can spawn adjacent map areas, enabling potentially unlimited expansion.

5. **Region Transition Handling**  
   Implement a handler that manages player movement, camera transitions, and data streaming between neighboring regions.

6. **Quest-Driven Expansion**  
   Tie the unlocking of new edges to quest milestones (e.g., destroying a bandit-built wall) so expansion feels earned and narratively grounded.

---

## 3. Feature Breakdown

### 3.1. Edge Typology

- **Stone Walls:** The default impassable barrier remains as a visual reference.
- **Mountains:** Rugged, impassable edges that reinforce natural boundaries.
- **Oceans:** Water bodies acting as edges requiring specialized traversal.
- **Frontier Gates:** Configurable passages that can be toggled open via quest completion, triggering region generation.

Each edge stores metadata indicating whether it is solid, passable, or queued for expansion.

### 3.2. Terrain Variation

- **Height Map Generator:** Uses layered noise, erosion passes, and parameterized profiles to produce diverse elevation.
- **Cliff Detection:** Identify high slope transitions to place cliffs and vertical features.
- **Ravines/Canyons:** Controlled modules that carve deep, narrow depressions for added drama.

Designers can adjust amplitude, frequency, and erosion parameters to dial the desired amount of verticality.

### 3.3. River Generation

- **Edge-to-Edge Flow:** Rivers are algorithmically routed between two chosen edges while maintaining consistent water height for their entire length.
- **Cross-Region Consistency:** When rivers reach an expandable edge, their continuity is preserved through metadata so adjacent regions can align waterways.

Analytical checks ensure rivers remain monotonic and do not stall mid-region.

### 3.4. Expansion Framework

- **Region Data Asset:** A serializable resource defines seed values, terrain modifiers, edge flags, and expansion status for each cardinal direction.
- **Region Manager:** Singleton responsible for loading adjacent regions (`RegionManager.load_adjacent_region(region_id, direction)`), keeping track of active regions, and caching or unloading distant ones.
- **Edge Markers:** Data-binding for each edge to specify whether it currently presents a wall, a natural barrier, or an unlockable gateway.

This framework enables "infinite" growth via on-demand generation and streaming.

### 3.5. Region Transitions

- **Transition Handler:** Manages fade effects, camera handoff, and player state preservation when crossing edges.
- **State Synchronization:** Player position, orientation, and elevation are transferred between region contexts to avoid disorientation.

Transitions are decoupled from map generation to permit reuse across future region types.

### 3.6. Quest Integration

- **Quest Hook:** Quests such as "Eliminate the Bandit Wall" trigger callbacks upon completion that update edge states.
- **Wall Removal Process:** Animates stone wall destruction, updates `RegionData`, and marks the associated direction as open.
- **Progress Feedback:** UI notifications (e.g., "Northern wall breached") inform the player when expansion becomes available.

By coupling expansion to quests, new territory feels like a consequence of the player's actions.

### 3.7. Road Generation

**Primary Roads (Edge-to-Edge)**
- When a new map is generated, the system selects two (or more) map edges as road endpoints
- A primary road is calculated between these edges using pathfinding or pre-defined waypoints
- The road is planned **before** the settlement layout is finalized, ensuring buildings and features route around it
- Primary roads serve as the main thoroughfares for trade, travel, and expansion

**Multi-Edge Roads (Extensibility)**
- Initial implementation supports 2-edge roads (e.g., north-to-south or east-to-west)
- Architecture must support N-edge roads for future complex maps where:
  - A single road connects three or more edges
  - Multiple independent roads cross the map
  - Roads form intersection networks (T-junctions, crossroads)
- The road generation system should store edge connections in `RegionData` as a flexible array of edge pairs

**Dead-End Roads**
- Some primary roads branch toward **dead-end maps** — adjacent regions that exist but are not connected to the main road network
- Dead-end maps are generated with their own road stubs that align with the parent region's planned road endpoints
- Dead-end connections are flagged in `RegionData.edge_connections` for both regions
- This allows future expansion (quests, unlocks) to connect dead ends to the main road network

**Building Access Roads**
- As the settlement is planned, secondary roads are generated to connect buildings to the primary road network
- Building roads use a simpler path algorithm (grid-aligned or direct connection)
- Small paths may connect individual buildings or building clusters to the nearest road segment
- Building roads should not intersect primary roads at sharp angles; pathfinding should prefer gentle intersections

**Road Rendering**
- Roads are rendered on a separate layer above terrain
- Road width can vary: primary roads (wider) vs. building paths (narrower)
- Visual styling includes road texture, borders, and optional details (ruts, wear patterns)

**Edge Metadata for Roads**
Each map edge stores road connection data:
```
edge_metadata = {
  direction: "north" | "south" | "east" | "west",
  road_connection: RoadConnection | null,
  dead_end_to: RegionData | null
}
```

---

## 4. Data Model & Architecture

| Component | Role |
| --- | --- |
| `RegionData` (Resource) | Stores procedural seeds, edge flags, road endpoints, and generation parameters. |
| `MapGenerator` (GDScript) | Produces height/elevation data, places cliffs/rivers, and assembles the visual map. |
| `RoadGenerator` (GDScript) | Calculates primary roads between edges, plans dead-end routes, generates building access paths. |
| `RegionManager` (AutoLoad) | Coordinates active regions, loads neighbors, and contains expansion APIs. |
| `QuestWallBreaker` (Script) | Listens for quest completion and triggers wall removal or expansion unlock. |
| `TransitionController` | Orchestrates camera transitions and player handover between regions. |

Each component exposes clearly typed interfaces (per GDScript conventions) to allow designers to hook into the system.

---

## 5. Implementation Roadmap

1. **Define Region Data Schema (Week 1)**  
   Create `RegionData.tres` resource with edge states, seeds, and generation parameters; provide a simple editor inspector.

2. **Prototype Height Variation (Week 2)**  
   Build a standalone generator that demonstrates ravines, cliffs, and hill profiles; visualize slopes for tuning.

3. **River Routing Prototype (Week 3)**  
   Implement an edge-to-edge river for a single region, verifying consistent heights and edge metadata.

4. **Region Loading Infrastructure (Week 4)**  
   Develop `RegionManager` and adjacent-region loading stub scenes; ensure player transitions can be simulated.

5. **Road Generation Prototype (Week 4-5)**  
   Build `RoadGenerator` that selects two map edges, calculates primary road paths, and plans dead-end routes. Integrate with `MapGenerator` to ensure roads are generated before building placement.

6. **Building Access Roads (Week 5)**  
   Implement secondary road generation connecting buildings to primary roads. Validate pathfinding avoids sharp road intersections.

7. **Quest-Driven Expansion (Week 6)**  
   Integrate a quest that triggers wall destruction; hook into the edge metadata to flip an edge from "wall" to "gateway."

8. **Full Integration & QA (Week 7)**  
   Connect all subsystems, test multiple regions with roads, dead-end connections, and validate performance and user feedback.

---

## 6. Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Procedural generation performance degradation | Pre-generate regions off the main thread, stream in pieces, and cache results. |
| Transition jank when loading adjacent regions | Employ fade transitions plus asynchronous loading; pre-warm adjacent tiles. |
| Quest hooks and region states getting out of sync | Implement clear event contracts and unit tests for quest-triggered state changes. |
| Unbounded region growth leading to memory pressure | Limit active regions with an LRU cache and unload distant areas automatically. |
| Road pathfinding conflicts with building placement | Plan roads before settlement layout; validate paths don't intersect critical building zones. |
| Dead-end region alignment mismatches when connecting roads later | Store alignment metadata in both parent and dead-end `RegionData`; validate on load. |

---

## 7. Next Actions

- Finalize `RegionData` structure and integrate into the editor.
- Begin procedural height-map experimentation with adjustable cliff/ravine parameters.
- Align quest requirements with localization/story teams to define "wall-breaking" scenarios.
- Design `RoadGenerator` algorithm for primary edge-to-edge paths and building connections.
- Define dead-end map connection format and alignment validation logic.

---

*End of Document*
