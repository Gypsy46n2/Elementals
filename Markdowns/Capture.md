# Capture System Design Document

## Overview
Capture is a multi-stage loop: **encounter → restrain → drag → tame**. Wild actors can be subdued with nets, ropes, chains, manacles, and traps, then physically hauled back to a friendly base for taming/petting. Nets are already referenced in `ItemsAutoload`, so we build off that existing asset and its attack-style interaction.

> Net reference (adapted from D&D): When you take the Attack action you can throw a Net (range 15 feet). The target must make a Dexterity save (DC 8 + Dex modifier + proficiency) or become Restrained until it escapes. Huge+ creatures succeed automatically. Destroying the Net also frees the target instantly.

We translate this into a capture tool with short range (5/15), hit points (5 HP, AC 10), and a Restraint Rating that makes following steps possible.

## Restraint Tiers & Items

1. **Net (Tier 2)**: Launches the encounter. Grants Restraint Rating 2, base Escape DC 10 STR (Athletics). Creature stays Restrained (cannot move) but can escape with repeated checks.
2. **Ropes/snare/lasso (Tier 1)**: Soft binds. Add Restraint Rating +1 each when applied, raise escape DC, but easy to break. Useful when approaching restrained targets.
3. **Chains & Manacles (Tier 3-4)**: Applied while netted. Chains (iron, hemp, silk) raise Restraint Rating +2-4 and add penalties to escape. Manacles add +4-6, lock wrists, and may require keys or Thieves' Tools to remove.
4. **Traps (Tier 5)**: Pit traps, cages, bear traps, magical snares. They preemptively constrain a creature entering the trigger tile and stack with later bindings.

**Stacking rule:** Each restraint item contributes its Restraint Rating to a total. Escape DC = base DC + (Restraint Rating × 2) + size modifier + trait bonuses.

## Escape + Containment

Actors have an `ActorState`: WILD, RESTRAINED, CONFINED, TAMING, TAMED, FLED. While restrained they can spend their turn to roll Escape (d20 + modifiers) against Escape DC. Adding ropes/chains/manacles increases the DC dramatically, so nets alone are easy to break but high-tier bindings make escape rare.

Trait bonuses: high Strength, Escape Artist, amorphous forms, magical resistance. Exhausted or bound creatures take penalties.

## Dragging Back to Base

When Restraint Rating ≥ the creature's **Confinement Threshold** (base 2 + size modifier), the player can drag it. Dragging:
- Slows player movement (50% speed).
- Forces the actor to share the same tile (prevents enemy movement).
- Requires a base destination (stable, ranch pen, etc.).
- If the player is hit while dragging, they must pass a save (e.g., DC 10 CON) or drop the creature (it remains Restrained in place).
- Dragging continues until the creature reaches base or the player releases it.

At base the creature transitions to **CONFINED** state.

## Taming & Loyalty

Taming happens inside a safe zone once the creature is confined. The player spends taming sessions (time, items, food) to raise `loyalty` (0–1.0). Higher Restraint Rating increases loyalty gains, but enchanted manacles can block escape rolls entirely. If loyalty falls to 0 the creature may fight free again; reaching 1.0 makes it a herd member (`ActorState.TAMED`).

Taming sessions consume items and time, and the creature must stay confined long enough to finish the progress bar. Breaking the restraints gives it a chance to escape, so stacking ropes/chains/manacles/traps during this phase protects the effort.

## CaptureComponent Responsibilities

1. Track `ActorState` transitions and emit signals when a state changes.
2. Store applied restraint items and compute total Restraint Rating.
3. Provide escape checks (roll + modifiers vs escape DC) and notify the system when a creature breaks free.
4. Allow drag eligibility, taming progress, loyalty modifications, and taming session bookkeeping.
5. Integrate with `HerdManager` when a creature becomes TAMED or returns to WILD/FLED.

## Capture Flow Summary

1. **Encounter** wild actor in WILD state.
2. **Restrained** via Net, trap, or binding.
3. **Bind** with ropes/chains/manacles; stack rating.
4. **Drag** creature back to base once threshold reached.
5. **Tame** through sessions/items; loyalty → 1.0.
6. **Herd** the new member once TAMED, enabling breeding and arena use.

By planning the capture tools, stacking mechanic, escape formulas, drag mechanics, and taming progression we can implement the references to nets and expand to ropes, chains, manacles, and traps.
