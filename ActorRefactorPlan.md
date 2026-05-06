# Actor System Refactor Plan

## Overview

This document outlines the steps to restructure the Godot project to follow best practices for organization and maintainability. The goal is to unify actor-related code into a clear hierarchy and resolve inconsistencies between documentation and actual structure.

---

## Phase 1: Pre-Planning (Safety First)

### 1.1 Backup Project
- [ ] Copy entire project folder to a backup location
- [ ] Verify backup integrity before proceeding

### 1.2 Audit Current State
- [ ] Document all actor-related scripts (.gd) and their current paths
- [ ] Document all actor-related scenes (.tscn) and their current paths
- [ ] Identify all preload/load references that will need updating
- [ ] List all autoloads in project.godot that reference actor paths

### 1.3 Create Project Map
Create a comprehensive inventory spreadsheet:
| File | Current Path | Type | Dependencies | Priority |

---

## Phase 2: Create New Folder Structure

### 2.1 Create Top-Level Source Directory
```
res://src/
```

### 2.2 Create Actor Subdirectories
```
res://src/actors/
res://src/actors/base/          # Base classes (Actor.gd, etc.)
res://src/actors/components/   # Actor-specific components
res://src/actors/ai/          # AI controllers
res://src/actors/ai/states/    # AI state classes
res://src/actors/types/        # Derived actor types
res://src/actors/models/       # Visual model scenes
```

### 2.3 Create Scene Directory
```
res://scenes/
res://scenes/actors/          # Actor scenes
res://scenes/projectiles/     # Projectile scenes
res://scenes/weapons/         # Weapon model scenes
res://scenes/ui/              # UI scenes
res://scenes/arena/           # Arena scenes
res://scenes/quests/          # Quest scenes
```

### 2.4 Reorganize Assets Directory
```
res://assets/
res://assets/sprites/
res://assets/sprites/characters/
res://assets/sprites/tiles/
res://assets/audio/
res://assets/audio/sfx/
res://assets/audio/music/
res://assets/shaders/
res://assets/models/
res://assets/external/
```

---

## Phase 3: Move Actor Files (Core)

### 3.1 Base Actor Class
**Source:** `res://Actor/Actor.gd`
**Target:** `res://src/actors/base/Actor.gd`

**Notes:**
- This is the foundational class for all game entities
- Update class_name to: `class_name Actor` (already correct)
- Verify all derived classes update their `extends` path

**Dependencies to update:**
- GoatActor.gd
- FireActor.gd
- FarmerActor.gd
- Any component that extends Actor

### 3.2 Move AI Controller
**Source:** `res://Components/ActorComponents/NPC Behavior/ActorAIController.gd`
**Target:** `res://src/actors/ai/ActorAIController.gd`

**Notes:**
- Update internal imports for state references
- Check for any autoload references to this file

### 3.3 Move AI States
**Source:** `res://Components/ActorComponents/NPC Behavior/States/`
**Target:** `res://src/actors/ai/states/`

**Files to move:**
- AIState.gd
- AIIdleState.gd
- AIFleeState.gd
- AIChaseState.gd
- AIAttackState.gd

**Notes:**
- Update all `preload()` paths for sibling states
- Verify state transition logic still works

---

## Phase 4: Move Actor Type Files

### 4.1 Move Derived Actor Classes
**Source:** `res://Actor/`
**Target:** `res://src/actors/types/`

**Files to move:**
- GoatActor.gd
- FireActor.gd
- FarmerActor.gd
- Any other *_Actor.gd files

**Notes:**
- Each file needs to update its `extends` statement
- From: `extends Actor` (no path needed if same folder)
- Or update path if necessary

### 4.2 Move Actor Models
**Source:** `res://Actor/models/*.tscn`
**Target:** `res://scenes/actors/models/`

**Files to move:**
- GoatModel.tscn
- GoblinModel.tscn
- BearModel.tscn
- OrcModel.tscn

**Notes:**
- Verify model scenes don't have script dependencies on old path
- Update any references to these models in actor scenes

---

## Phase 5: Move Projectiles and Weapons

### 5.1 Projectile Scenes
**Source:** `res://Actor/projectiles/*.tscn`
**Target:** `res://scenes/projectiles/`

**Files to move:**
- FireProjectile.tscn
- Other projectile scenes

**Notes:**
- Check projectile scripts for path dependencies
- Update any spawn logic in actor classes

### 5.2 Weapon Models
**Source:** `res://Actor/weapons/*.tscn`
**Target:** `res://scenes/weapons/`

**Notes:**
- Verify weapon script references
- Update any weapon spawning code

---

## Phase 6: Move Components

### 6.1 Move Actor Components
**Source:** `res://Components/ActorComponents/`
**Target:** `res://src/actors/components/`

**Files to identify:**
- List all component .gd files in this folder
- Determine which are actor-specific vs general

**Notes:**
- Actor-specific components → `src/actors/components/`
- General components → `src/components/actor/`

### 6.2 Move NPC Behavior Folder
**Source:** `res://Components/ActorComponents/NPC Behavior/`
**Target:** `res://src/actors/npc_behavior/` (rename: no spaces!)

**Notes:**
- Rename from "NPC Behavior" to "npc_behavior"
- This prevents path issues on different platforms

---

## Phase 7: Update Autoloads

### 7.1 Identify Autoloads
Check `project.godot` for:
- [ ] GameEvents
- [ ] GameSettings
- [ ] ItemsAutoload
- [ ] Any other autoloaded scripts referencing actor paths

### 7.2 Update Autoload Paths
For each autoload, update the path to new location:
```
[autoload]
GameEvents="res://Core/GameEvents.gd" → res://src/systems/core/GameEvents.gd
```

### 7.3 Verify Autoload Functionality
After each autoload move, test:
- Project runs without errors
- Autoload signals work correctly
- No "Could not load script" errors

---

## Phase 8: Update Script References

### 8.1 Find All Preload/Load References
Search all .gd files for old paths:
```gdscript
# Search patterns:
preload("res://Actor/")
preload("res://Components/ActorComponents/")
load("res://Actor/")
```

### 8.2 Update All References
For each found reference, update to new path:
```gdscript
# Before
preload("res://Actor/Actor.gd")

# After
preload("res://src/actors/base/Actor.gd")
```

### 8.3 Verify No Orphan References
After all moves, run grep to confirm no old paths remain:
```bash
# Search for any remaining references to old paths
```

---

## Phase 9: Update Documentation

### 9.1 Update Actor.md
**Current path:** `res://Actor.md`

Update the file structure section to match new layout:
```markdown
## File Structure

res://src/actors/
├── base/
│   └── Actor.gd           # Base actor class
├── types/
│   ├── GoatActor.gd
│   ├── FireActor.gd
│   └── FarmerActor.gd
├── ai/
│   ├── ActorAIController.gd
│   └── states/
│       ├── AIState.gd
│       ├── AIIdleState.gd
│       └── ...
└── components/
    └── ...

res://scenes/
├── actors/
│   ├── GoatActor.tscn
│   └── ...
└── projectiles/
    └── FireProjectile.tscn
```

### 9.2 Create Architecture Docs
Create `docs/ARCHITECTURE.md` with:
- Overview of folder structure
- Explanation of each directory's purpose
- Guidelines for adding new files

---

## Phase 10: Clean Up

### 10.1 Remove Empty Folders
After all files are moved, delete:
- `res://Actor/` (if empty)
- `res://Components/ActorComponents/NPC Behavior/` (if empty)
- Any other empty directories

### 10.2 Remove Duplicate Files
- `res://CharacterUIComponent.gd` (root level)
- Compare with `res://Components/Arena/CharacterUIComponent.gd`
- Keep the one with more recent updates or better location

### 10.3 Clean Up assets/experimental
Review contents:
- Move stable assets to appropriate subfolders
- Remove test/temporary files
- Document any assets that should be deleted

---

## Phase 11: Testing

### 11.1 Manual Testing Checklist
- [ ] Project loads without errors
- [ ] Main scene runs without crashes
- [ ] Actor spawning works
- [ ] AI states function correctly
- [ ] Projectile creation works
- [ ] UI elements load properly
- [ ] Quest system works (if applicable)

### 11.2 Common Error Patterns
Watch for:
```
Parser Error: Could not resolve path ...
Parser Error: Class not found: ...
Runtime Error: Invalid call. Nonexistent function ...
```

### 11.3 Edge Cases
- Test with a fresh run (no cached data)
- Test on different OS (paths may differ)
- Test after project.godot is edited

---

## Rollback Plan

If anything goes wrong:

1. **Restore from backup** - Copy backup folder over project
2. **Undo moves** - Use version control or manually reverse
3. **Revert project.godot** - Restore original autoload paths

**IMPORTANT:** Do not proceed to later phases until earlier phases are verified!

---

## Timeline Suggestion

| Phase | Estimated Time | Can Skip If |
|-------|----------------|-------------|
| Phase 1: Pre-Planning | 30 minutes | No |
| Phase 2: Create Folders | 5 minutes | No |
| Phase 3: Move Core | 20 minutes | No |
| Phase 4: Move Types | 15 minutes | No |
| Phase 5: Move Projectiles | 10 minutes | No |
| Phase 6: Move Components | 20 minutes | No |
| Phase 7: Update Autoloads | 15 minutes | No |
| Phase 8: Update References | 45 minutes | No |
| Phase 9: Update Docs | 15 minutes | No |
| Phase 10: Clean Up | 15 minutes | Yes |
| Phase 11: Testing | 30-60 minutes | No |

**Total: ~3-4 hours if done carefully**

---

## Notes for Specific Changes

### Renaming "NPC Behavior" Folder
**Why:** Spaces in paths can cause issues with some systems and make command-line work difficult.

**How:**
```bash
# Old path
res://Components/ActorComponents/NPC Behavior/

# New path
res://src/actors/npc_behavior/
```

**Impact:** All internal references to this path must be updated.

### Why Move Scenes to Separate Folder?
**Benefits:**
- Clear separation between code (.gd) and structure (.tscn)
- Easier to find scene files for level designers
- Better organization in version control
- Standard practice in professional Godot projects

### Why Create `src/` Prefix?
**Benefits:**
- Clearly marks source code directory
- Prevents confusion with assets
- Makes path grepping easier: `res://src/` vs `res://`
- Standard convention in many Godot projects

---

## Questions to Answer Before Starting

1. Are there any actor-related scripts in `Core/` or other folders that need moving?
2. Do any external assets reference the current `Actor/` folder?
3. Is there a version control system in place (Git)?
4. Are there any build scripts that might break with path changes?
5. What is the critical path - what must work for the game to run at all?

---

## Appendix: File Manifest

### Current Actor Files (Source Inventory)

**Scripts in res://Actor/:**
- Actor.gd
- GoatActor.gd
- FireActor.gd
- FarmerActor.gd
- (and others)

**Scenes in res://Actor/:**
- models/ (GoatModel.tscn, etc.)
- projectiles/ (FireProjectile.tscn, etc.)
- weapons/

**AI Files:**
- ActorAIController.gd
- States/ (AIState.gd, AIIdleState.gd, etc.)

**Component Files:**
- Various .gd files in Components/ActorComponents/

---

*Document Version: 1.0*
*Last Updated: 2025*
*Status: Ready for Implementation*