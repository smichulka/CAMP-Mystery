# Claude_Request-0056 — TutorialController Murderer Branch + PlayerStatusView Roster Header

**Base commit:** 3ab74d5
**Wave:** 2 (Agent A: TutorialController.lua Murderer step copy + currentContext branch; Agent B: PlayerStatusView.lua role-aware header)

---

## Preamble — 0055 Review

Request 0055 is accepted. EffectsView phase card PHASE_COPY branches by role — Murderer sees first-person copy during MurderPlanning, NightTransform, Investigation, Campfire, Resolution. PhaseTitles now has murderer sub-keys for all six in-round phases. All 83 checks passed.

---

## Mission

Two high-impact role-naive surfaces discovered by audit:

1. **`TutorialController.lua` `STEP_COPY`** is entirely camper-framed and `currentContext()` has no Murderer branch. On their first time as Murderer, a player reads "Someone in the group is choosing a victim right now. Use this moment to prepare…" on their own planning screen. During NightTransform, they read "The monster is somewhere out there. Stay near teammates." — when they ARE the monster. The tutorial is the most explicit guidance the game gives players; wrong-role tutorial copy is the highest-priority framing failure.

2. **`PlayerStatusView.lua`** header is hardcoded to `"CAMP ROSTER"` for all roles. The Murderer opens the roster to scan for voting blocs and high-suspicion targets — it is their hunting intelligence panel, not a fellowship directory. The title is set once in the constructor and never role-updated.

---

## Agent A — `src/client/Controllers/TutorialController.lua`

### A1. Pre-implementation inspection

**Agent A must read the file before writing any code.** Specifically:

1. Find the `STEP_COPY` table (approximately lines 47–118). Note all step IDs present and the exact fields used (id, title, body, tip, etc.).
2. Find `currentContext()` (approximately lines 151–195). Note how it maps `phase → step ID`, and where the `role == "Spectator"` branch is.
3. Note whether `currentContext` accepts `role` as a parameter or reads it from state internally.
4. Check if there is an existing `displayStep(id)` or equivalent that renders the copy. Note whether it accepts a context key or looks up by step ID.

### A2. Add Murderer step copy entries

**Add parallel step entries for the Murderer** for the four phases where the framing is role-breaking:

| Existing step ID | New Murderer step ID | Murderer title | Murderer body |
|---|---|---|---|
| `murderplanning` | `murderplanning_murderer` | "YOU ARE CHOOSING" | "Select your target and monster form before the night falls. Your choice is final." |
| `nighttransform` | `nighttransform_murderer` | "YOU ARE THE MONSTER" | "Your form has changed. Hunt your target and avoid detection. Use your ability wisely." |
| `investigation` | `investigation_murderer` | "STAY HIDDEN" | "The camp is searching for evidence. Blend in. Steer suspicion. Isolation is your tool — and their downfall." |
| `vote` | `vote_murderer` | "THE VOTE" | "You are being considered. Redirect suspicion. A tie breaks in your favor." |

**Implementation note:** Inspect the actual field names used in `STEP_COPY` entries and replicate them exactly. Do not invent new field names.

### A3. Branch `currentContext()` by role for Murderer

**Context:** `currentContext` currently maps phases to step IDs, with a Spectator redirect. Add a Murderer redirect using the same pattern:

```lua
local function currentContext(phase, role)
    -- if role == "Spectator", return Spectator step ID (existing logic)
    -- NEW: if role == "Murderer", return Murderer-specific step ID
    if role == "Murderer" then
        local murdererMap = {
            MurderPlanning = "murderplanning_murderer",
            NightTransform = "nighttransform_murderer",
            Investigation  = "investigation_murderer",
            Campfire       = "vote_murderer",
        }
        local murdererStep = murdererMap[phase]
        if murdererStep then return murdererStep end
        -- fall through to camper copy for phases not in the map (Day, Lobby, etc.)
    end
    -- existing phase→step mapping unchanged
end
```

**Constraints:**
- `role` must be whatever the existing `currentContext` signature uses. If it reads role from a module-level state variable rather than a parameter, use the same mechanism — do not add a new parameter if the existing design passes state differently.
- Phases not in `murdererMap` (Day, Lobby, Rewards, Resolution) fall through to camper copy — the Murderer sees standard copy for those.
- Spectator redirect is completely unchanged.
- All camper step IDs and copy are completely unchanged.
- If the tutorial renders at all (some sessions may have tutorial disabled), only the text is changed — no show/hide, timing, or layout changes.

---

## Agent B — `src/client/UI/PlayerStatusView.lua`

### B1. Pre-implementation inspection

**Agent B must read the file before writing any code.** Specifically:

1. Find where `"CAMP ROSTER"` is set (approximately line 299–300 in the constructor). Note whether this is a `Components.SetLetterspacedText` call or a direct `.Text` assignment.
2. Find the `Update` method. Note whether it already receives `localPlayer` (with `.role`) and whether it re-renders the title on each call.
3. Check if there is a `self.rosterTitle` or similar handle to the title label stored on `self`.

### B2. Role-aware roster header

**Target behavior:**

| Role | Header text |
|---|---|
| Murderer | `"SUSPECTS"` |
| Ghost (isGhost == true) | `"SPIRIT VIEW"` |
| Spectator | `"CAMP ROSTER"` |
| Living camper (default) | `"CAMP ROSTER"` |

**Implementation:** Move the header-text assignment from the constructor into `Update` (or add a role-check update alongside the constructor call). On each `Update` call, derive `localRole` and `localIsGhost` from `localPlayer`, then set the label:

```lua
local localRole   = readString(localPlayer, "role", "")
local localIsGhost = readBoolean(localPlayer, "isGhost", false)

local headerText = if localRole == "Murderer"
    then "SUSPECTS"
    elseif localIsGhost
    then "SPIRIT VIEW"
    else "CAMP ROSTER"

-- set the header label using the same mechanism as the constructor
-- (Components.SetLetterspacedText(self.titleLabel, headerText) or self.titleLabel.Text = headerText)
```

**Constraints:**
- If `readString` and `readBoolean` are not already in scope in this file, add them as local helpers at the top of the file using the same pattern as GameView.lua (one-liner with default fallback).
- The label handle must be stored on `self` if not already — inspect whether the constructor already does this. If the label is a local variable that goes out of scope, it must be assigned to `self.titleLabel` (or whatever name fits the existing pattern).
- Only the header text changes. All other roster layout, participant rows, scroll behavior, and update logic are completely unchanged.
- If `Update` is called on every tick and the text setting is expensive, guard it with a `if lastHeader ~= headerText then` cache check — but only if the existing code has similar guards; don't add a new pattern if the file doesn't use it.

---

## Acceptance Criteria

**TutorialController — A2/A3:**
- [ ] Murderer in MurderPlanning: tutorial step reads "YOU ARE CHOOSING" / "Select your target and monster form before the night falls."
- [ ] Murderer in NightTransform: "YOU ARE THE MONSTER" / "Your form has changed. Hunt your target…"
- [ ] Murderer in Investigation: "STAY HIDDEN" / "The camp is searching for evidence…"
- [ ] Murderer in Campfire: "THE VOTE" / "You are being considered. Redirect suspicion."
- [ ] Murderer in Day/Lobby/Rewards: sees standard camper copy (no Murderer override for these phases)
- [ ] Spectator redirect unchanged
- [ ] All camper step copy unchanged

**PlayerStatusView — B2:**
- [ ] Murderer: roster header = `"SUSPECTS"`
- [ ] Ghost camper: roster header = `"SPIRIT VIEW"`
- [ ] Living camper: roster header = `"CAMP ROSTER"` (unchanged)
- [ ] Spectator: roster header = `"CAMP ROSTER"` (unchanged)
- [ ] All other roster behavior unchanged

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|------|-------|---------|
| `src/client/Controllers/TutorialController.lua` | A | Add Murderer step copy entries; branch currentContext by role |
| `src/client/UI/PlayerStatusView.lua` | B | Role-aware header: Murderer→"SUSPECTS", Ghost→"SPIRIT VIEW", others→"CAMP ROSTER" |
