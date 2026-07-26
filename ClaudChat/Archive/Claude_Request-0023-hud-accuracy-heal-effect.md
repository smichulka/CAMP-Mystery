# Claude_Request-0023 — HUD Accuracy, Witness Progress, Spectator Text, Heal Effect

**Base commit:** 6b9e51c  
**Wave:** 1 (three agents, different files — no merge conflicts)

---

## Mission

Three targeted improvements after Studio testing:

1. **Agent A** — `src/shared/Config/KeybindHints.lua`: The hint says "Tab  Map" but Tab now opens the Player Roster (not a map). Fix the label.
2. **Agent B** — `src/client/UI/GameView.lua`: Day HUD adds witness interview progress; Spectator role gets accurate objective text during Investigation and Campfire; MurderPlanning non-Murderer label corrected.
3. **Agent C** — `src/client/UI/EffectsView.lua` + `src/client/Controllers/RoundController.lua`: Add a brief green flash when the local player is healed (health state improves).

---

## Agent A — `src/shared/Config/KeybindHints.lua`

One file, two lines changed.

In the `HINTS` table, for both `Day` and `Investigation` keyboard entries, change:

```
"Tab  Map"
```

to:

```
"Tab  Players"
```

Also update the controller line that says `"View  Map"` to `"View  Players"` in both phases.

**Full result:**

```lua
local HINTS: { [string]: KeybindHints } = {
    Day = {
        keyboard   = { "E  Interact", "N  Notebook", "Tab  Players", "F  Equip item" },
        controller = { "A  Interact", "Y  Notebook", "View  Players", "X  Equip item" },
    },
    Investigation = {
        keyboard   = { "E  Interact", "N  Notebook", "Q  Role ability", "Tab  Players" },
        controller = { "A  Interact", "Y  Notebook", "LB  Role ability", "View  Players" },
    },
    Campfire = {
        keyboard   = { "E  Vote", "N  Evidence notebook" },
        controller = { "A  Vote", "Y  Evidence notebook" },
    },
}
```

No other changes to this file.

---

## Agent B — `src/client/UI/GameView.lua`

Three targeted changes to the phase branch in `GameView:Update()` (the block around lines 3915–3951). No other parts of the file change.

### B1. Day phase — add witness interview count

The `Day` branch currently reads:

```lua
if phase == "Day" then
    self.progressLabel.Text = string.format("Camp work %d/%d - prepare before sunset.", objectiveDone, objectiveGoal)
    self.objectiveText.Text = string.format("DAY OBJECTIVE\nComplete camp work: %d of %d", objectiveDone, objectiveGoal)
    self.objectiveFill.Size = UDim2.fromScale(math.clamp(objectiveDone / objectiveGoal, 0, 1), 1)
```

Replace with (add witness count from `state.mystery`):

```lua
if phase == "Day" then
    local mystery = if type(state) == "table" then state.mystery else nil
    local witnessFound = math.max(0, math.floor(readNumber(mystery, "revealedWitnessCount", 0)))
    local witnessTotal = math.max(1, math.floor(readNumber(mystery, "totalWitnessCount", 1)))
    self.progressLabel.Text = string.format(
        "Camp work %d/%d · Witnesses %d/%d",
        objectiveDone, objectiveGoal, witnessFound, witnessTotal
    )
    self.objectiveText.Text = string.format(
        "DAY OBJECTIVE\nCamp work: %d of %d\nInterview witnesses: %d of %d",
        objectiveDone, objectiveGoal, witnessFound, witnessTotal
    )
    self.objectiveFill.Size = UDim2.fromScale(math.clamp(objectiveDone / objectiveGoal, 0, 1), 1)
```

Note: `state` is already the first parameter in `Update(state, legacyRound, legacyPlayer)` and is in scope. `readNumber` is already defined in the file.

### B2. Investigation phase — Spectator-aware text

The `Investigation` branch currently reads:

```lua
elseif phase == "Investigation" then
    self.progressLabel.Text = string.format("Evidence %d/%d - search the abandoned town.", evidenceFound, evidenceGoal)
    self.objectiveText.Text = string.format("NIGHT OBJECTIVE\nCollect and post clues: %d of %d", evidenceFound, evidenceGoal)
    self.objectiveFill.Size = UDim2.fromScale(math.clamp(evidenceFound / evidenceGoal, 0, 1), 1)
```

Replace with:

```lua
elseif phase == "Investigation" then
    local localRole = if type(player) == "table" and type(player.role) == "string"
        then player.role else ""
    if localRole == "Spectator" then
        self.progressLabel.Text = string.format("Observing. Evidence %d/%d collected.", evidenceFound, evidenceGoal)
        self.objectiveText.Text = "OBSERVING\nYou joined mid-round. Watch the investigation unfold."
    else
        self.progressLabel.Text = string.format("Evidence %d/%d - search the abandoned town.", evidenceFound, evidenceGoal)
        self.objectiveText.Text = string.format("NIGHT OBJECTIVE\nCollect and post clues: %d of %d", evidenceFound, evidenceGoal)
    end
    self.objectiveFill.Size = UDim2.fromScale(math.clamp(evidenceFound / evidenceGoal, 0, 1), 1)
```

### B3. Campfire phase — Spectator-aware text

The `Campfire` branch currently reads:

```lua
elseif phase == "Campfire" then
    local cast = readNumber(round, "votesCast", 0)
    local eligible = math.max(1, readNumber(round, "eligibleVoters", 1))
    self.progressLabel.Text = string.format("Votes locked %d/%d - accuse carefully.", cast, eligible)
    self.objectiveText.Text = "FINAL OBJECTIVE\nReview the notebook and identify the Murderer."
    self.objectiveFill.Size = UDim2.fromScale(math.clamp(cast / eligible, 0, 1), 1)
```

Replace with:

```lua
elseif phase == "Campfire" then
    local cast = readNumber(round, "votesCast", 0)
    local eligible = math.max(1, readNumber(round, "eligibleVoters", 1))
    local localRole = if type(player) == "table" and type(player.role) == "string"
        then player.role else ""
    if localRole == "Spectator" then
        self.progressLabel.Text = string.format("Votes locked %d/%d - observing.", cast, eligible)
        self.objectiveText.Text = "OBSERVING\nThe campers are deliberating. The vote will reveal the verdict."
    else
        self.progressLabel.Text = string.format("Votes locked %d/%d - accuse carefully.", cast, eligible)
        self.objectiveText.Text = "FINAL OBJECTIVE\nReview the notebook and identify the Murderer."
    end
    self.objectiveFill.Size = UDim2.fromScale(math.clamp(cast / eligible, 0, 1), 1)
```

### B4. MurderPlanning non-Murderer label correction

The current non-Murderer text reads `"MURDERER OBJECTIVE\nWait for darkness..."` which is confusing to Campers. Change (in the existing `else` branch of the `MurderPlanning` check):

```lua
-- FROM:
self.objectiveText.Text = "MURDERER OBJECTIVE\nWait for darkness. Review your equipment."

-- TO:
self.objectiveText.Text = "PREPARATION\nSomething is coming. Secure your equipment and stay alert."
```

---

## Agent C — `src/client/UI/EffectsView.lua` + `src/client/Controllers/RoundController.lua`

Two files, both owned by Agent C.

### C1. EffectsView.lua — add `ShowHealedEffect()`

Add after `FlashEvidenceFound()` (which was added in 0021 — check the exact location):

```lua
function EffectsView:ShowHealedEffect()
    if self.destroyed then return end
    local flash = Instance.new("CanvasGroup")
    flash.Name = "HealFlash"
    flash.Size = UDim2.fromScale(1, 1)
    flash.BackgroundColor3 = Color3.fromRGB(60, 190, 90)
    flash.BackgroundTransparency = 0
    flash.GroupTransparency = 0.78
    flash.BorderSizePixel = 0
    flash.Active = false
    flash.ZIndex = 75
    flash.Parent = self.root

    local fadeOut = TweenService:Create(flash,
        TweenInfo.new(0.65, Enum.EasingStyle.Quint, Enum.EasingDirection.Out),
        { GroupTransparency = 1 })
    fadeOut.Completed:Connect(function()
        if flash.Parent then flash:Destroy() end
    end)
    fadeOut:Play()
end
```

**Important**: use the same `TweenService` reference already established in `EffectsView.lua` — check the existing requires at the top rather than assuming a name. Do not add a duplicate `local TweenService = ...` if one already exists.

### C2. RoundController.lua — detect health improvement and call `ShowHealedEffect`

**Add module-level variable** near existing `lastIsGhost` and similar state variables:

```lua
local lastHealthState: string? = nil
```

**In the main `refresh()` function**, after the existing `lastIsGhost` update block (around where ghost transition is detected), add health improvement detection:

```lua
local currentHealthState = if type(player) == "table" and type(player.healthState) == "string"
    then player.healthState
    else nil

local healthImproved = currentHealthState == "Healthy"
    and lastHealthState ~= nil
    and lastHealthState ~= "Healthy"
    and not reconnect

if healthImproved and currentEffects then
    currentEffects:ShowHealedEffect()
end

if currentHealthState ~= lastHealthState then
    lastHealthState = currentHealthState
end
```

**In the reset/cleanup** (find where `lastIsGhost = nil` is set on round stop or reconnect reset, around line 989), add:

```lua
lastHealthState = nil
```

**Important constraints:**
- `currentEffects` is the existing `local currentEffects = effects` variable pattern already used in `refresh()`. Use the same pattern.
- Do not call `ShowHealedEffect` on reconnect (the guard is already in `healthImproved`).
- Do not call it on the first state snapshot (when `lastHealthState == nil` — already guarded).
- Do not call it when health stays Healthy.
- Place the health check AFTER the `lastIsGhost` update, not before, to keep ordering consistent with other state trackers.

---

## Acceptance Criteria

- [ ] Keybind hint overlay shows "Tab  Players" (not "Tab  Map") during Day and Investigation
- [ ] Xbox hint shows "View  Players"
- [ ] Day phase progressLabel shows "Camp work N/M · Witnesses N/M"
- [ ] Day phase objectiveText shows both camp work and witness counts
- [ ] `state.mystery` may be nil — reads use `readNumber(mystery, ...)` with 0/1 defaults (safe)
- [ ] Spectator role during Investigation sees "OBSERVING" text, not "NIGHT OBJECTIVE"
- [ ] Spectator role during Campfire sees "OBSERVING" text, not "FINAL OBJECTIVE"
- [ ] Non-Murderer MurderPlanning objective says "PREPARATION" not "MURDERER OBJECTIVE"
- [ ] Healing from Injured/Incapacitated/Critical → Healthy shows a brief green screen flash
- [ ] Heal flash does not fire on first state snapshot or on reconnect
- [ ] Heal flash does not fire when health stays Healthy
- [ ] `lastHealthState` is reset to nil on round cleanup
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count — no new files)

---

## File Summary

| File | Status | Agent |
|------|--------|-------|
| `src/shared/Config/KeybindHints.lua` | Modified | A |
| `src/client/UI/GameView.lua` | Modified | B |
| `src/client/UI/EffectsView.lua` | Modified | C |
| `src/client/Controllers/RoundController.lua` | Modified | C |
