# Claude_Request-0024 — Monster Player UX Fixes

**Base commit:** 32dc04f  
**Wave:** 1 (two agents, different files — no merge conflicts)

---

## Mission

Two targeted UX corrections surfaced by code review of the current build:

1. **Agent A** — `src/client/UI/GameView.lua`: The Investigation and NightTransform phase HUD shows wrong text to the Murderer/Monster player. They see camper objectives instead of monster objectives. Fix with role-aware branches. Also fix the middle-dot separator that may not render in all Roblox font configurations.

2. **Agent B** — `src/client/UI/EffectsView.lua`: The "THE MONSTER IS ACTIVE" status banner fires for ALL players — including the monster player themselves. A monster player already has their dedicated monster panel with stamina and cooldown. They don't need the "MONSTER IS ACTIVE" banner on their own screen. Exclude them.

---

## Agent A — `src/client/UI/GameView.lua`

Three changes, all within or near the phase branch in `GameView:Update()`.

### A1. Middle dot separator fix (Day phase, line ~3920)

**Current:**
```lua
self.progressLabel.Text = string.format(
    "Camp work %d/%d · Witnesses %d/%d",
    objectiveDone, objectiveGoal, witnessFound, witnessTotal
)
```

**Replace with** (U+00B7 `·` is in Latin-1 Supplement and may not render in all Roblox Gotham variants — use ASCII `|`):
```lua
self.progressLabel.Text = string.format(
    "Camp work %d/%d  |  Witnesses %d/%d",
    objectiveDone, objectiveGoal, witnessFound, witnessTotal
)
```

### A2. NightTransform phase — add dedicated branch with Monster-aware text

Currently NightTransform falls into the generic `else` at the bottom of the phase chain and shows camper text like "Stay together. The town is awake." to all players including the Murderer.

Add a new `elseif` block **before the existing `else`** (after the `elseif phase == "MurderPlanning"` block):

```lua
elseif phase == "NightTransform" then
    local privateMonster = if type(state) == "table" then state.privateMonster else nil
    local isMonsterPlayer = type(privateMonster) == "table"
        and readBoolean(privateMonster, "active", false)
    if isMonsterPlayer then
        self.progressLabel.Text = "The transformation is complete. The town awaits."
        self.objectiveText.Text = "YOU ARE THE MONSTER\nThe town is yours. Hunt carefully — the campers will fight back."
        self.objectiveFill.Size = UDim2.fromScale(1, 1)
    else
        self.progressLabel.Text = "The town has appeared. Stay close to your group."
        self.objectiveText.Text = "NIGHT BEGINS\nThe abandoned town has merged with the camp. The monster is somewhere inside."
        self.objectiveFill.Size = UDim2.fromScale(0, 1)
    end
```

This block goes between the `elseif phase == "MurderPlanning"` block and the final `else` block.

### A3. Investigation phase — Monster-aware objective text

**Current Investigation branch:**
```lua
elseif phase == "Investigation" then
    local localRole = if type(player) == "table" and type(player.role) == "string"
        then player.role
        else ""
    if localRole == "Spectator" then
        self.progressLabel.Text = string.format("Observing. Evidence %d/%d collected.", evidenceFound, evidenceGoal)
        self.objectiveText.Text = "OBSERVING\nYou joined mid-round. Watch the investigation unfold."
    else
        self.progressLabel.Text = string.format("Evidence %d/%d - search the abandoned town.", evidenceFound, evidenceGoal)
        self.objectiveText.Text = string.format("NIGHT OBJECTIVE\nCollect and post clues: %d of %d", evidenceFound, evidenceGoal)
    end
    self.objectiveFill.Size = UDim2.fromScale(math.clamp(evidenceFound / evidenceGoal, 0, 1), 1)
```

**Replace with** (add monster player check before the Spectator check):
```lua
elseif phase == "Investigation" then
    local privateMonster = if type(state) == "table" then state.privateMonster else nil
    local isMonsterPlayer = type(privateMonster) == "table"
        and readBoolean(privateMonster, "active", false)
    local localRole = if type(player) == "table" and type(player.role) == "string"
        then player.role
        else ""
    if isMonsterPlayer then
        self.progressLabel.Text = "Hunt your targets. Don't get cornered."
        self.objectiveText.Text = "HUNT OBJECTIVE\nEliminate your designated target. Avoid discovery. Use your ability when the time is right."
        self.objectiveFill.Size = UDim2.fromScale(1, 1)
    elseif localRole == "Spectator" then
        self.progressLabel.Text = string.format("Observing. Evidence %d/%d collected.", evidenceFound, evidenceGoal)
        self.objectiveText.Text = "OBSERVING\nYou joined mid-round. Watch the investigation unfold."
        self.objectiveFill.Size = UDim2.fromScale(math.clamp(evidenceFound / evidenceGoal, 0, 1), 1)
    else
        self.progressLabel.Text = string.format("Evidence %d/%d - search the abandoned town.", evidenceFound, evidenceGoal)
        self.objectiveText.Text = string.format("NIGHT OBJECTIVE\nCollect and post clues: %d of %d", evidenceFound, evidenceGoal)
        self.objectiveFill.Size = UDim2.fromScale(math.clamp(evidenceFound / evidenceGoal, 0, 1), 1)
    end
```

**Important**: `objectiveFill.Size` is now set inside each branch (not after the `if/elseif/else`) because the monster player fill is `1` while the others use the clamp.

**Constraints for Agent A:**
- `state` is the first parameter of `GameView:Update()` and is in scope throughout.
- `readBoolean` is already defined in `GameView.lua` — use it, don't add a duplicate.
- `player` is already resolved earlier in `Update()` as `if type(state) == "table" then state.player else nil` — use the same local.
- Do not change any other functions. All changes are confined to the Investigation `elseif` block, the insertion of a new `NightTransform` `elseif` block, and the Day progress label format string.

---

## Agent B — `src/client/UI/EffectsView.lua`

One change: the local `readStatus` function near the top of the file.

### B1. Exclude the monster player from the MonsterActive banner

**Current `readStatus` tail (after all other status checks):**
```lua
if type(state.monster) == "table" and state.monster.active == true then
    return "MonsterActive"
end
return nil
```

**Replace with:**
```lua
if type(state.monster) == "table" and state.monster.active == true then
    -- Don't show the MonsterActive banner to the monster player themselves.
    -- They have a dedicated monster panel (stamina + cooldown) already.
    local privateMonster = if type(state) == "table" then state.privateMonster else nil
    local isSelf = type(privateMonster) == "table"
        and privateMonster.active == true
    if not isSelf then
        return "MonsterActive"
    end
end
return nil
```

**Constraints for Agent B:**
- The change is inside `local function readStatus(state: any): string?` — confirm the exact lines before editing.
- No other function in `EffectsView.lua` changes.
- Do not add a `--!strict` type annotation for `privateMonster` — the existing `any` inference for `state` is sufficient; no new local type declarations are needed.
- The fix must not affect non-monster players. Non-monster players have `state.privateMonster` as `nil` or absent, so `isSelf` will be `false` and "MonsterActive" will still return for them.

---

## Acceptance Criteria

- [ ] Day progressLabel shows `Camp work N/M  |  Witnesses N/M` (pipe separator, not middle dot)
- [ ] Monster player during NightTransform sees "YOU ARE THE MONSTER" objective text
- [ ] Non-monster players during NightTransform see "NIGHT BEGINS" objective text
- [ ] Monster player during Investigation sees "HUNT OBJECTIVE" text (not "NIGHT OBJECTIVE")
- [ ] Non-monster Spectator during Investigation still sees "OBSERVING"
- [ ] Non-monster campers during Investigation still see "NIGHT OBJECTIVE\nCollect and post clues: N of M"
- [ ] Monster player does NOT see "THE MONSTER IS ACTIVE" status banner on their own screen
- [ ] Non-monster players still see "THE MONSTER IS ACTIVE" banner when the monster is active
- [ ] `state.privateMonster` being nil (non-monster players) safely falls back — no crashes
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/UI/GameView.lua` | A | Middle dot → pipe, NightTransform branch, Investigation monster branch |
| `src/client/UI/EffectsView.lua` | B | Exclude self from MonsterActive status |
