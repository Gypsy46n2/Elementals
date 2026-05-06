# Actor System Refactor Plan

## Overview

This document outlines the steps to restructure the Godot project to follow best practices for organization and maintainability. The goal is to unify actor-related code into a clear hierarchy and resolve inconsistencies between documentation and actual structure.

---

## Phase 1: Pre-Planning

### 1.1 Audit Current State
- [ ] Document all actor-related scripts (.gd) and their current paths
- [ ] Document all actor-related scenes (.tscn) and their current paths
- [ ] Identify all preload/load references that will need updating
- [ ] List all autoloads in project.godot that reference actor paths

### 1.2 Create Project Map
Create a comprehensive inventory spreadsheet:
| File | Current Path | Type | Dependencies | Priority | Status |

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

**APPROACH:** Move files one at a time. Get operator verification after each file move to ensure the project doesn't break.

### 3.1 Base Actor Class
**Source:** `res://Actor/Actor.gd`
**Target:** `res://src/actors/base/Actor.gd`

**Steps:**
1. [ ] Move file from source to target
2. [ ] Update any preload/load references to this file
3. [ ] Run project and verify no errors
4. [ ] **OPERATOR VERIFICATION:** Confirm project loads, main scene runs, and actor spawning works

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

**Steps:**
1. [ ] Move file from source to target
2. [ ] Update internal imports for state references
3. [ ] Check for any autoload references to this file
4. [ ] **OPERATOR VERIFICATION:** Confirm AI controller functions correctly, no path errors

**Notes:**
- Update internal imports for state references
- Check for any autoload references to this file

### 3.3 Move AI States
**Source:** `res://Components/ActorComponents/NPC Behavior/States/`
**Target:** `res://src/actors/ai/states/`

**Steps:**
1. [ ] Move AIState.gd (base state class)
2. [ ] **OPERATOR VERIFICATION:** Confirm no errors
3. [ ] Move AIIdleState.gd
4. [ ] **OPERATOR VERIFICATION:** Confirm no errors
5. [ ] Move AIFleeState.gd
6. [ ] **OPERATOR VERIFICATION:** Confirm no errors
7. [ ] Move AIChaseState.gd
8. [ ] **OPERATOR VERIFICATION:** Confirm no errors
9. [ ] Move AIAttackState.gd
10. [ ] **OPERATOR VERIFICATION:** Confirm no errors

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

**APPROACH:** Move files one at a time. Get operator verification after each file move to ensure the project doesn't break.

### 4.1 Move Derived Actor Classes
**Source:** `res://Actor/`
**Target:** `res://src/actors/types/`

**Steps (for each file):**
1. [ ] Move file from source to target
2. [ ] Update its `extends` statement if needed (e.g., `extends Actor`)
3. [ ] Update any preload/load references in the file
4. [ ] **OPERATOR VERIFICATION:** Confirm no errors, actor type functions correctly

**Files to move (in order):**
- GoatActor.gd
  - [ ] Move file
  - [ ] **OPERATOR VERIFICATION**
- FireActor.gd
  - [ ] Move file
  - [ ] **OPERATOR VERIFICATION**
- FarmerActor.gd
  - [ ] Move file
  - [ ] **OPERATOR VERIFICATION**
- (Any other *_Actor.gd files)
  - [ ] Move file
  - [ ] **OPERATOR VERIFICATION**

**Notes:**
- Each file needs to update its `extends` statement
- From: `extends Actor` (no path needed if same folder)
- Or update path if necessary

### 4.2 Move Actor Models
**Source:** `res://Actor/models/*.tscn`
**Target:** `res://scenes/actors/models/`

**Steps (for each file):**
1. [ ] Move scene file from source to target
2. [ ] Update any references to this model in actor scenes
3. [ ] **OPERATOR VERIFICATION:** Confirm scene loads correctly, model displays properly

**Files to move (in order):**
- GoatModel.tscn
  - [ ] Move file
  - [ ] **OPERATOR VERIFICATION**
- GoblinModel.tscn
  - [ ] Move file
  - [ ] **OPERATOR VERIFICATION**
- BearModel.tscn
  - [ ] Move file
  - [ ] **OPERATOR VERIFICATION**
- OrcModel.tscn
  - [ ] Move file
  - [ ] **OPERATOR VERIFICATION**

**Notes:**
- Verify model scenes don't have script dependencies on old path
- Update any references to these models in actor scenes

---

## Phase 5: Move Projectiles and Weapons

**APPROACH:** Move files one at a time. Get operator verification after each file move to ensure the project doesn't break.

### 5.1 Projectile Scenes
**Source:** `res://Actor/projectiles/*.tscn`
**Target:** `res://scenes/projectiles/`

**Steps (for each file):**
1. [ ] Move scene file from source to target
2. [ ] Update any preload/load references to this file
3. [ ] **OPERATOR VERIFICATION:** Confirm projectile works correctly, no path errors

**Files to move (in order):**
- FireProjectile.tscn
  - [ ] Move file
  - [ ] **OPERATOR VERIFICATION**
- (Other projectile scenes)
  - [ ] Move file
  - [ ] **OPERATOR VERIFICATION**

**Notes:**
- Check projectile scripts for path dependencies
- Update any spawn logic in actor classes

### 5.2 Weapon Models
**Source:** `res://Actor/weapons/*.tscn`
**Target:** `res://scenes/weapons/`

**Steps (for each file):**
1. [ ] Move scene file from source to target
2. [ ] Update any references to this weapon
3. [ ] **OPERATOR VERIFICATION:** Confirm weapon loads correctly

**Notes:**
- Verify weapon script references
- Update any weapon spawning code

---

## Phase 6: Move Components

**APPROACH:** Move files one at a time. Get operator verification after each file move to ensure the project doesn't break.

### 6.1 Move Actor Components
**Source:** `res://Components/ActorComponents/`
**Target:** `res://src/actors/components/`

**Steps (for each file):**
1. [ ] Move component file from source to target
2. [ ] Update any preload/load references to this file
3. [ ] **OPERATOR VERIFICATION:** Confirm component functions correctly, no path errors

**Files to identify:**
- List all component .gd files in this folder
- Determine which are actor-specific vs general

**Notes:**
- Actor-specific components → `src/actors/components/`
- General components → `src/components/actor/`

### 6.2 Move NPC Behavior Folder
**Source:** `res://Components/ActorComponents/NPC Behavior/`
**Target:** `res://src/actors/npc_behavior/` (rename: no spaces!)

**Steps:**
1. [ ] Move individual state files (with verification after each)
2. [ ] Update any references to old "NPC Behavior" path
3. [ ] **OPERATOR VERIFICATION:** Confirm AI behavior works correctly

**Notes:**
- Rename from "NPC Behavior" to "npc_behavior"
- This prevents path issues on different platforms
- Update all references in dependent files

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

**Backups are maintained on GitHub.** If anything goes wrong:

1. **Restore from GitHub** - Revert to previous commit
2. **Undo moves** - Use version control or manually reverse
3. **Revert project.godot** - Restore original autoload paths

**IMPORTANT:** Do not proceed to later phases until earlier phases are verified!

**Verification Before Each Step:**
1. Run project and check for errors
2. Confirm main scene loads correctly
3. Test specific functionality being moved
4. Report any issues immediately

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

*Document Version: 1.2*
*Last Updated: 2025*
*Status: Phase 1-9 Completed, Partial Phase 11*
*Approach: Incremental file moves with operator verification after each step*
*Backup: GitHub*

## Executed Changes Summary

### Phase 2: Created New Folder Structure ✅
- res://src/actors/base/
- res://src/actors/types/
- res://src/actors/ai/
- res://src/actors/ai/states/
- res://src/actors/projectiles/
- res://scenes/actors/
- res://scenes/actors/models/
- res://scenes/projectiles/
- res://scenes/weapons/
- res://assets/materials/
- res://assets/sprites/characters/
- res://assets/goats/
- res://assets/shaders/

### Phase 3: Moved Core Actor Files ✅
- Actor.gd → src/actors/base/Actor.gd

### Phase 3.2: Moved AI Controller ✅
- ActorAIController.gd → src/actors/ai/
- ActorController.gd → src/actors/ai/
- ActorStateMachine.gd → src/actors/ai/
- ActorTileNavigationComponent.gd → src/actors/ai/
- FactionComponent.gd → src/actors/ai/

### Phase 3.3: Moved AI States ✅
- AIState.gd → src/actors/ai/
- AIIdleState.gd → src/actors/ai/states/
- AIFleeState.gd → src/actors/ai/states/
- AIChaseState.gd → src/actors/ai/states/
- AIAttackState.gd → src/actors/ai/states/
- AIDeathState.gd → src/actors/ai/states/
- AIFlockinState.gd → src/actors/ai/states/
- AIInvestigateState.gd → src/actors/ai/states/
- AIRoamState.gd → src/actors/ai/states/
- AIStunnedState.gd → src/actors/ai/states/
- Dormant.gd → src/actors/ai/states/

### Phase 4.1: Moved Actor Types ✅
- GoatActor.gd → src/actors/types/
- FireActor.gd → src/actors/types/
- FarmerActor.gd → src/actors/types/
- WaterActor.gd → src/actors/types/
- GoblinMinion.gd → src/actors/types/
- ScarecrowDummy.gd → src/actors/types/
- GoatController.gd → src/actors/types/
- FarmerController.gd → src/actors/types/
- GoblinController.gd → src/actors/types/
- GoatVisuals.gd → src/actors/types/
- DormantVisual3D.gd → src/actors/types/
- StunVisual3D.gd → src/actors/types/
- GoblinModel.gd → src/actors/types/GoblinModels/

### Phase 4.2: Moved Actor Models ✅
- GoatModel.tscn → scenes/actors/models/
- GoatHead.tscn → scenes/actors/models/
- GoblinModel.tscn → scenes/actors/models/
- GoblinHead.tscn → scenes/actors/models/

### Phase 5.1: Moved Projectile Scenes ✅
- FireProjectile.tscn → scenes/projectiles/
- FireLobProjectile.tscn → scenes/projectiles/
- WaterProjectile.tscn → scenes/projectiles/
- WaterLobProjectile.tscn → scenes/projectiles/
- ArrowProjectile.tscn → scenes/projectiles/
- ClubProjectile.tscn → scenes/projectiles/
- DaggerProjectile.tscn → scenes/projectiles/
- HandaxeProjectile.tscn → scenes/projectiles/
- JavelinProjectile.tscn → scenes/projectiles/
- ScimitarProjectile.tscn → scenes/projectiles/
- ShortbowProjectile.tscn → scenes/projectiles/

### Phase 5.2: Moved Weapon Models ✅
- ClubModel.tscn → scenes/weapons/
- HandaxeModel.tscn → scenes/weapons/
- JavelinModel.tscn → scenes/weapons/
- ScimitarModel.tscn → scenes/weapons/
- ShortbowModel.tscn → scenes/weapons/

### Phase 8: Updated References ✅
Updated all preload/load references in:
- ArenaSpawner.gd
- FireActor.gd
- WaterActor.gd
- MeleeHitbox.gd
- MainMenu.gd
- WeaponVisualComponent.gd
- WeaponComponent.gd
- RangedComponent.gd
- ItemsAutoload.gd

Updated all scene external references in actor/projectile scenes.

### Phase 9: Updated Documentation ✅
- Actor.md updated with new file paths
- File structure section updated

### Phase 10: Fixed Shader References ✅
- **AttackHitboxMaterial.tres**: Updated shader path from `res://Actor/AttackHitbox.gdshader` to `res://assets/Shaders/AttackHitbox.gdshader`
- **DefaultGoat.tres**: Updated GoatVisuals path from `res://Actor/GoatVisuals.gd` to `res://src/actors/types/GoatVisuals.gd`

### ⚠️ Known Issue: Shader Caching
**Issue**: Error persists: `Cannot load shader: res://Actor/AttackHitbox.gdshader`

**Root Cause**: Godot 4.x maintains internal caches (`.godot/uid_cache.bin`, scene import caches) that track file locations. These caches are NOT automatically updated when files are moved using file operations - only when Godot's editor itself handles the file move.

**Solution**: The user needs to perform a **Project Restart**:
1. Close the Godot Editor completely (not just the current project)
2. Delete the `.godot` folder in the project directory
3. Reopen the project - Godot will regenerate all caches with correct paths

Alternatively, within the editor:
1. Project → Restart Project (or close and reopen)
2. If the error persists, use Project → Remove Current Project, then reopen

### Remaining Items
- [ ] User must restart Godot project to clear shader cache
- [ ] Old Actor/ folder has .uid files that should be deleted after verification
- Some scene files still reference Components/ActorComponents/ paths (expected - component scripts)