# Claude_Request-0062 — RoundController Witness/Task Notifications + TutorialView Header Role-Aware

**Base commit:** (updated after 0061 lands)
**Wave:** 2 (Agent A: RoundController.lua "Witness interviewed" + "Camp task complete" notifications; Agent B: TutorialView.lua "NEW CAMPER BRIEFING" header role-aware)

---

## Preamble — 0061 Review

Request 0061 is accepted. GameView "Day objectives complete" and "Evidence complete" show Warning-tone adversarial copy for Murderer; "Vote required" uses Murderer-specific framing; "No selectable target" body text changed to "another living player." All 83 checks passed.

---

## Mission

Two remaining notification call-sites in `RoundController.lua` fire during Day phase with no Murderer guard, and `TutorialView.lua` shows "NEW CAMPER BRIEFING" as the panel header for every tutorial step including the Murderer-specific ones added in 0056:

1. **"Witness interviewed"** (RoundController.lua ~lines 531–545) — `"Info"` (neutral blue) notification fires each time a counselor is interviewed during Day phase. The Murderer receives it with no role branch. Each witness interviewed is a threat event for the Murderer — a counselor may provide testimony that implicates them. The tone and body should be adversarial, not neutral.

2. **"Camp task complete"** (RoundController.lua ~lines 549–561) — `"Info"` notification fires each time a Day-phase camp task is completed. Mildly Camper-framed ("Camp task complete" reads as a progress celebration). For the Murderer, each completed task advances the campers' Day-phase objectives — bringing investigation closer. The body is numeric/neutral but the framing and tone are wrong.

3. **TutorialView.lua header** — Lines 78 and 158 hardcode the progress banner as `"NEW CAMPER BRIEFING"`. TutorialController (updated in 0056) is fully Murderer-aware and routes to steps titled "YOU ARE CHOOSING" and "YOU ARE THE MONSTER." The Murderer sees a step card reading "YOU ARE THE MONSTER" under a header that says "NEW CAMPER BRIEFING." This is a direct contradiction.

---

## Agent A — `src/client/Controllers/RoundController.lua` (Witness interviewed + Camp task)

### A1. Pre-implementation inspection

Agent A must read the file and confirm:

1. Find "Witness interviewed" block (~lines 531–545). Confirm:
   - The full guard condition above the `Notify` call (currently: `revealedWitnessCount > lastRevealedWitnessCount and not isGhost and not reconnect and phaseName == "Day" and currentView`).
   - Whether `roleName` is in scope — it should be, derived at function scope.
   - The exact `currentView:Notify(title, body, style)` call and style string used.
   - The format of `revealedWitnessCount` and `totalWitnessCount` in the body string.

2. Find "Camp task complete" block (~lines 549–561). Confirm:
   - The guard condition above it (similar to above — `not isGhost` and `not reconnect` guards expected).
   - Whether `roleName` is in scope at this line.
   - The exact format string for `objectivesCompleted` / `objectiveGoal`.
   - The style string used (confirm `"Info"`).

### A2. "Witness interviewed" — Murderer branch

**Current (approximate):**
```lua
currentView:Notify(
    "Witness interviewed",
    string.format("%d of %d witnesses spoken to.", revealedWitnessCount, totalWitnessCount),
    "Info"
)
```

**Target:**
```lua
if roleName == "Murderer" then
    currentView:Notify(
        "Witness interviewed",
        string.format("A witness has been questioned — %d of %d counselors spoken to.", revealedWitnessCount, totalWitnessCount),
        "Warning"
    )
else
    currentView:Notify(
        "Witness interviewed",
        string.format("%d of %d witnesses spoken to.", revealedWitnessCount, totalWitnessCount),
        "Info"
    )
end
```

**Constraints:**
- The existing outer guard (`revealedWitnessCount > lastRevealedWitnessCount and not isGhost and not reconnect and phaseName == "Day"`) is completely unchanged — Ghosts and reconnecting players are still excluded.
- `roleName` must be the same variable already in scope (no new state reads).
- Style `"Warning"` must match casing used elsewhere in this file.

### A3. "Camp task complete" — Murderer framing

**Current (approximate):**
```lua
currentView:Notify(
    "Camp task complete",
    string.format("%d of %d tasks done.", objectivesCompleted, objectiveGoal),
    "Info"
)
```

**Target:**
```lua
if roleName == "Murderer" then
    currentView:Notify(
        "Camp task progress",
        string.format("Campers advancing: %d of %d tasks done.", objectivesCompleted, objectiveGoal),
        "Warning"
    )
else
    currentView:Notify(
        "Camp task complete",
        string.format("%d of %d tasks done.", objectivesCompleted, objectiveGoal),
        "Info"
    )
end
```

**Constraints:**
- Existing Ghost/reconnect guards unchanged.
- Variable names `objectivesCompleted` and `objectiveGoal` are placeholders — use whatever variable names the existing code uses for the same values.
- Style `"Warning"` for Murderer, `"Info"` for others.

---

## Agent B — `src/client/UI/TutorialView.lua` (progress header role-aware)

### B1. Pre-implementation inspection

Agent B must read TutorialView.lua and confirm:

1. Find the "NEW CAMPER BRIEFING" string at line ~78 (constructor, where the progress label is created) and line ~158 (where it is updated with step count). Note:
   - Whether the progress label is created with a hardcoded string in the constructor or if the string is set via `self.progress.Text` in the update path.
   - Whether `Show` or the update method already accepts a `step` parameter that includes any role context.

2. Read TutorialController.lua and find the call to `TutorialView:Show(...)` or `TutorialView:Update(...)`. Note:
   - The exact arguments passed (step object, index, total, etc.).
   - Whether `currentContext()` returns the step ID (e.g., `"nighttransform_murderer"`) that is then passed to the view, or whether the view only receives the resolved step copy.
   - Whether there is a way for the view to know the step's role from what it already receives.

### B2. Role-aware progress header

**Target behavior:**

| Step type | Progress banner |
|---|---|
| Any `_murderer` step (`murderplanning_murderer`, `nighttransform_murderer`, `investigation_murderer`, `vote_murderer`) | `"MURDERER BRIEFING  •  N OF N"` |
| All other steps (lobby, rolereveal, day, etc.) | `"NEW CAMPER BRIEFING  •  N OF N"` (unchanged) |

**Implementation options (choose based on what B1 inspection reveals):**

**Option 1 — Pass header label from TutorialController:**
If TutorialController already calls `TutorialView:Show(step, index, total)`, add a `header: string?` optional parameter:

```lua
-- TutorialController.lua (caller):
local isMurdererStep = string.find(stepId, "_murderer") ~= nil
local header = if isMurdererStep then "MURDERER BRIEFING" else "NEW CAMPER BRIEFING"
tutorialView:Show(step, index, total, header)

-- TutorialView.lua (receiver):
function TutorialView:Show(step, index, total, header: string?)
    local h = header or "NEW CAMPER BRIEFING"
    self.progress.Text = string.format("%s  •  %d OF %d", h, index, total)
    ...
end
```

**Option 2 — Derive header from step ID in TutorialView:**
If the view already receives the step ID (or step table that includes an `id` field):

```lua
local isMurdererStep = step.id and string.find(step.id, "_murderer") ~= nil
local header = if isMurdererStep then "MURDERER BRIEFING" else "NEW CAMPER BRIEFING"
self.progress.Text = string.format("%s  •  %d OF %d", header, index, total)
```

Agent B must choose the cleanest option based on what they find in B1. Do not add a parameter to the Show signature if the step object already carries the ID.

**Constraints:**
- The constructor still sets `"NEW CAMPER BRIEFING"` as the initial label (before any step is shown) — the role-aware text only applies when a step is actively displayed.
- Non-Murderer steps are completely unchanged.
- If the progress label uses `Components.SetLetterspacedText`, use that function rather than direct `.Text` assignment — match the existing pattern.
- Step content (body, title, tip), scroll layout, skip button, and step indicator are unchanged.

---

## Acceptance Criteria

**A2 — Witness interviewed:**
- [ ] Murderer: `"Warning"` — "A witness has been questioned — N of N counselors spoken to."
- [ ] Living camper: `"Info"` — "N of N witnesses spoken to." (unchanged)
- [ ] Ghost / reconnect: suppressed (unchanged)

**A3 — Camp task complete:**
- [ ] Murderer: `"Warning"` — "Camp task progress" / "Campers advancing: N of N tasks done."
- [ ] Living camper: `"Info"` — "Camp task complete" / "N of N tasks done." (unchanged)

**B2 — Tutorial progress header:**
- [ ] Murderer steps: progress banner = `"MURDERER BRIEFING  •  N OF N"`
- [ ] All other steps: progress banner = `"NEW CAMPER BRIEFING  •  N OF N"` (unchanged)
- [ ] Constructor initial state: `"NEW CAMPER BRIEFING"` (unchanged — role not yet known)
- [ ] Step content, layout, skip, and indicator unchanged

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|---|---|---|
| `src/client/Controllers/RoundController.lua` | A | "Witness interviewed": Murderer→Warning "A witness has been questioned"; "Camp task complete": Murderer→Warning "Campers advancing" |
| `src/client/UI/TutorialView.lua` | B | Progress header: `"MURDERER BRIEFING"` for Murderer steps, `"NEW CAMPER BRIEFING"` otherwise |
| `src/client/Controllers/TutorialController.lua` | B | (if Option 1) Pass `header` string to `TutorialView:Show` |
