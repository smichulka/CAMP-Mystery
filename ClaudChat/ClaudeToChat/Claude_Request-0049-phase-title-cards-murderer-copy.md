# Claude_Request-0049 — Phase Title Cards Murderer-Specific Copy

**Base commit:** 48919fe
**Wave:** 3 (Agent A: GameView.lua; Agent B: RoundController.lua; Agent C: PhaseTitles.lua)

---

## Preamble — 0048 Review

Request 0048 is accepted. Monster panel shows during NightTransform; PlayWinReveal is role-aware; PlayRoleReveal has Murderer header; "ROUND X" toast is role-branched. All 83 checks passed.

---

## Mission

Phase title cards — the full-width cinematic band that animates in at each phase transition — show third-person or Camper-perspective copy to ALL players including the Murderer:

- MurderPlanning: **"THE NIGHT IS CHOSEN / A hidden plan takes shape."** — tip: "Stay calm and move with purpose. The monster is choosing its plan."
- NightTransform: **"NIGHT FALLS / The monster awakens."** — tip: "Stick to lit paths and keep teammates in sight."

The Murderer is reading a news bulletin about themselves. These two phases are the most charged moments for the Murderer and deserve first-person copy.

---

## Agent C — `src/shared/Config/PhaseTitles.lua`

### C1. Add Murderer-specific entries

**Context:** The current module is a single flat table `{ [string]: { title, subtitle } }` plus a separate `PhaseTips` table. Add a parallel `PhaseTitlesMurderer` and `PhaseTipsMurderer` table (or embed into the existing structure with a `murderer` sub-key — Agent C should choose whichever is cleaner given the actual file structure).

**Proposed approach (parallel tables, cleanest separation):**

```lua
-- Existing (unchanged):
local PhaseTitles = {
    MurderPlanning = { title = "THE NIGHT IS CHOSEN", subtitle = "A hidden plan takes shape." },
    NightTransform = { title = "NIGHT FALLS",          subtitle = "The monster awakens." },
    -- ... all other phases unchanged
}

-- New murderer-specific overrides:
local PhaseTitlesMurderer = {
    MurderPlanning = { title = "YOUR PREY IS CHOSEN",      subtitle = "Strike before dawn." },
    NightTransform = { title = "YOU ARE THE MONSTER NOW",  subtitle = "The hunt begins. Move in shadow." },
}

local PhaseTipsMurderer = {
    MurderPlanning = "Study your target now. Your window is short.",
    NightTransform = "Your ability is your greatest weapon. Use it wisely.",
}
```

Export both tables so they are accessible to GameView (or expose a helper function).

**Constraints:**
- All existing phases in `PhaseTitles` and `PhaseTips` are completely unchanged.
- `PhaseTitlesMurderer` only needs entries for phases where the copy would differ. Missing entries fall through to the default table.
- Keep the same data shape as the existing tables so GameView can use them with identical access patterns.

---

## Agent B — `src/client/Controllers/RoundController.lua`

### B1. Pass roleName to PlayPhaseTitleCard

**Context:** The call to `currentView:PlayPhaseTitleCard(phaseName, reconnect)` (inside the phase-entry block). Add `roleName` as a third argument:

```lua
    currentView:PlayPhaseTitleCard(phaseName, reconnect, roleName)
```

**Constraints:** `roleName` is in scope at this call site. If `PlayPhaseTitleCard` is called from multiple locations, pass `roleName` at each. The third argument is optional so existing two-arg call sites still compile.

---

## Agent A — `src/client/UI/GameView.lua`

### A1. PlayPhaseTitleCard — accept roleName and branch on Murderer entries

**Context:** `PlayPhaseTitleCard(phaseName: string, isReconnect: boolean)` (approximately line 5772). The function reads `PhaseTitles[phaseName]` for its title/subtitle and `PhaseTips[phaseName]` for its tip.

**Requires:** `PhaseTitlesMurderer` and `PhaseTipsMurderer` must be imported from the same `PhaseTitles` config module (Agent C will export them).

New signature:

```lua
function GameView:PlayPhaseTitleCard(phaseName: string, isReconnect: boolean, localRole: string?)
```

Entry resolution:

```lua
    local resolvedRole = localRole or ""
    local entry = if resolvedRole == "Murderer" and PhaseTitlesMurderer[phaseName]
        then PhaseTitlesMurderer[phaseName]
        else PhaseTitles[phaseName]
    local tipText = if resolvedRole == "Murderer" and PhaseTipsMurderer[phaseName]
        then PhaseTipsMurderer[phaseName]
        else PhaseTips[phaseName]
    if self.destroyed or isReconnect or self.roleRevealActive or type(entry) ~= "table" then
        return
    end
```

Everything after entry resolution — animation, layout, text rendering, timing — is completely unchanged.

**Constraints:**
- `localRole` is optional (`string?`) — existing two-arg call sites remain valid and fall through to default entries.
- The require for `PhaseTitlesMurderer` and `PhaseTipsMurderer` must be added at the top of GameView alongside the existing `PhaseTitles` require. Agent A must inspect the existing require to use the exact same path/pattern.
- No other function in GameView is changed.

---

## Acceptance Criteria

**PhaseTitles.lua — C1:**
- [ ] `PhaseTitlesMurderer.MurderPlanning` exists with `title` and `subtitle`
- [ ] `PhaseTitlesMurderer.NightTransform` exists with `title` and `subtitle`
- [ ] `PhaseTipsMurderer.MurderPlanning` exists
- [ ] `PhaseTipsMurderer.NightTransform` exists
- [ ] All existing default entries unchanged

**RoundController — B1:**
- [ ] `PlayPhaseTitleCard` called with three arguments including `roleName`

**GameView — A1 phase title card:**
- [ ] Murderer entering MurderPlanning: title `"YOUR PREY IS CHOSEN"`, subtitle `"Strike before dawn."`, tip `"Study your target now. Your window is short."`
- [ ] Murderer entering NightTransform: title `"YOU ARE THE MONSTER NOW"`, subtitle `"The hunt begins. Move in shadow."`, tip `"Your ability is your greatest weapon. Use it wisely."`
- [ ] All other roles: MurderPlanning and NightTransform title cards unchanged
- [ ] All other phases: title cards unchanged for all roles

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|------|-------|---------|
| `src/shared/Config/PhaseTitles.lua` | C | Add `PhaseTitlesMurderer` and `PhaseTipsMurderer` tables |
| `src/client/Controllers/RoundController.lua` | B | Pass `roleName` to `PlayPhaseTitleCard` call |
| `src/client/UI/GameView.lua` | A | `PlayPhaseTitleCard` accepts `localRole`; branches to Murderer config entries |
