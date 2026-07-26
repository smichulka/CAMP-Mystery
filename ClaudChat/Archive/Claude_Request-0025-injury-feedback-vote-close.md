# Claude_Request-0025 — Passive Injury Feedback + Post-Vote Modal Close

**Base commit:** 482ad4d  
**Wave:** 1 (two agents, different files — no merge conflicts)

---

## Mission

Two UX gaps identified in code review:

1. **Agent A** — `src/client/Controllers/RoundController.lua`: When a monster attacks a camper who is not pressing anything, no visual feedback fires. The impact flash and screen shake in `handleActionResult` only cover action-triggered state changes. Passive damage from snapshot updates is silent. Add health severity degradation detection to `refresh()` so getting attacked always triggers sensory feedback.

2. **Agent B** — `src/client/UI/GameView.lua`: The vote modal force-opens during Campfire and cannot be closed — even after the player has already voted. The close button shows "Vote required" regardless of vote state. After voting, the player is stuck staring at the disabled vote list instead of observing the campfire. Fix the close behavior so post-vote players can dismiss the panel.

---

## Agent A — `src/client/Controllers/RoundController.lua`

### A1. Add health severity map and module variable

Near the top of the file, alongside the existing module-level state variables (`lastIsGhost`, `lastHealthState`, etc.), add:

```lua
local HEALTH_SEVERITY: { [string]: number } = {
    Healthy = 0,
    Injured = 1,
    Incapacitated = 2,
    Critical = 2,
}
local lastHealthSeverity: number? = nil
```

### A2. Add degradation detection in `refresh()`

In `refresh()`, the existing block currently ends with:

```lua
if currentHealthState ~= lastHealthState then
    lastHealthState = currentHealthState
end
```

Add immediately after it (before `currentEffects:SetGhostTint(isGhost)`):

```lua
local currentSeverity = if currentHealthState ~= nil
    then HEALTH_SEVERITY[currentHealthState]
    else nil
local severityDegraded = currentSeverity ~= nil
    and lastHealthSeverity ~= nil
    and currentSeverity > lastHealthSeverity
    and not reconnect
    and not roundEnded
if severityDegraded then
    local currentCinematics = cinematics
    if currentCinematics then
        currentCinematics:PlayImpactFlash()
        if currentSeverity >= 2 then
            currentCinematics:PlayScreenShake(0.5)
        end
    end
end
if currentSeverity ~= lastHealthSeverity then
    lastHealthSeverity = currentSeverity
end
```

### A3. Reset in Stop() cleanup

Find the block in `RoundController.Stop()` where `lastIsGhost = nil` and `lastHealthState = nil` are reset (around line 1005). Add alongside them:

```lua
lastHealthSeverity = nil
```

**Constraints for Agent A:**
- `HEALTH_SEVERITY` is a module-level constant — add near the top, not inside a function.
- `lastHealthSeverity` is a module-level variable — add alongside `lastHealthState`.
- `cinematics` is already the module-level variable for `CinematicsController` — use it directly.
- `reconnect` and `roundEnded` are already in scope within `refresh()` — use them directly.
- `PlayImpactFlash()` and `PlayScreenShake()` already exist in CinematicsController — no new methods needed.
- The guard `lastHealthSeverity ~= nil` prevents the flash on the very first snapshot (same pattern as `lastHealthState ~= nil` for the heal effect).
- `currentSeverity` being nil means dead/spectator/unknown state — no flash fires for nil → nil or nil → something.
- Do not call `PlayScreenShake` for Injured (severity 1) — only for Incapacitated/Critical (severity ≥ 2). Getting injured should feel like a hit (flash only); getting incapacitated/critical should feel severe (flash + shake).

---

## Agent B — `src/client/UI/GameView.lua`

Two changes needed, both within `GameView`.

### B1. Add `localVoteHasLocked` to the GameView type and state

In the type definition block near the top of `GameView.lua`, add the field:

```lua
localVoteHasLocked: boolean,
```

In `GameView.new()` (inside the `setmetatable({...}, GameView)` table), initialize it:

```lua
localVoteHasLocked = false,
```

In `GameView:Destroy()`, reset it:

```lua
self.localVoteHasLocked = false
```

### B2. Change the vote modal header close callback

Find where the vote modal header is built (currently `_buildVote`, around this block):

```lua
makeHeader(self.voteModal, "CAMPFIRE ACCUSATION", function()
    self:Notify("Vote required", "Choose one suspect before the fire goes out.", "Warning")
end)
```

Replace the close callback:

```lua
makeHeader(self.voteModal, "CAMPFIRE ACCUSATION", function()
    if self.localVoteHasLocked then
        setModalVisible(self.voteModal, false)
    else
        self:Notify("Vote required", "Choose one suspect before the fire goes out.", "Warning")
    end
end)
```

### B3. Stop force-reopening the modal after a vote has been locked

In `GameView:_updateVote()`, find this line:

```lua
setModalVisible(self.voteModal, true)
```

Replace with:

```lua
self.localVoteHasLocked = self.localVoteHasLocked or hasVoted
if not self.localVoteHasLocked then
    setModalVisible(self.voteModal, true)
end
```

This means:
- The modal auto-opens when entering Campfire as a living non-ghost player who hasn't voted.
- Once `hasVoted` flips to true, `localVoteHasLocked` sticks true for the rest of the phase.
- The modal is no longer force-reopened on subsequent updates after voting.
- The player can now close the panel using the header X button after their vote is locked.

**Note on `localVoteHasLocked` reset across rounds:**
In `_updateVote()`, the very first check already handles phase exit:
```lua
if phase ~= "Campfire" or not alive or isGhost then
    setModalVisible(self.voteModal, false)
    self.currentVoteSignature = ""
    return
end
```

Add `self.localVoteHasLocked = false` alongside `self.currentVoteSignature = ""` in that branch so the flag resets when the Campfire phase ends. This ensures the next Campfire in the next round starts fresh.

**Constraints for Agent B:**
- `localVoteHasLocked` is a boolean on the GameView instance, not a module-level variable.
- `setModalVisible` is a module-level local function in `GameView.lua` — it is accessible from all `GameView` methods.
- The `hasVoted` local is already derived from `player.vote` or `player.hasVoted` in `_updateVote` — use it directly, do not re-read the player snapshot.
- The `or self.localVoteHasLocked` in the sticky assignment is intentional — once voted, cannot un-vote.
- Do not close the modal automatically after voting — only allow the player to close it themselves via the header button.

---

## Acceptance Criteria

### Agent A
- [ ] When a player's health drops from Healthy → Injured via snapshot (not action result), `PlayImpactFlash()` fires
- [ ] When health drops to Incapacitated or Critical via snapshot, `PlayImpactFlash()` AND `PlayScreenShake(0.5)` fire
- [ ] No impact flash fires on the first snapshot (when `lastHealthSeverity` is nil)
- [ ] No impact flash fires on reconnect snapshots
- [ ] No impact flash fires at round end (Lobby/Rewards phase)
- [ ] `lastHealthSeverity` is nil after `RoundController.Stop()`
- [ ] Healing (covered by existing `ShowHealedEffect`) is unaffected

### Agent B
- [ ] Vote modal auto-opens at Campfire entry for living, non-ghost, non-voted players
- [ ] After locking a vote, the X button closes the modal (not a toast warning)
- [ ] Before locking a vote, the X button still shows "Vote required" warning
- [ ] After closing post-vote, the modal does not reopen on the next update tick
- [ ] At the end of Campfire (phase changes), `localVoteHasLocked` resets to false
- [ ] The next round's Campfire starts with auto-open behavior restored

### Both
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/Controllers/RoundController.lua` | A | Health severity degradation detection + passive impact feedback |
| `src/client/UI/GameView.lua` | B | Post-vote modal close permission + localVoteHasLocked flag |
