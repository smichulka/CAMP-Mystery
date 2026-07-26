# Claude_Request-0026 — Monster Kill Confirmation + Day Objectives Complete

**Base commit:** a896c66
**Wave:** 1 (two agents, different files — no merge conflicts)

---

## Preamble — 0025 Review

Request 0025 is accepted as implemented. The CI run passed (83 strict files), all acceptance criteria are met, and the two-file boundary was preserved. No follow-up test harness is needed — Roblox Studio multiplayer testing is the right venue for runtime proof of severity degradation and vote-modal interaction.

---

## Mission

Two feedback gaps remain in the monster and camper gameplay loops:

1. **Agent A** — `src/client/Controllers/RoundController.lua`: When the local player is the monster and their designated target transitions from alive to dead (via snapshot), they receive no visual confirmation that the kill succeeded. The monster is left guessing whether their attack landed. Add participant alive-state tracking to `updateReleaseExperience` so the monster sees a "TARGET ELIMINATED" notification exactly once per death transition.

2. **Agent B** — `src/client/UI/GameView.lua`: When campers complete all day objectives (camp work done AND all witnesses interviewed), there is no positive acknowledgement. The progress bar fills and numbers match, but nothing signals "well done." Add a one-time per-round notification when all Day phase objectives are satisfied so campers know that phase is now optimally complete.

---

## Agent A — `src/client/Controllers/RoundController.lua`

### A1. Add module-level alive-state tracker

Near the top of the file, alongside the existing `lastConnectedState` variable, add:

```lua
local lastParticipantAliveStates: { [string]: boolean } = {}
```

### A2. Extend the participant loop in `updateReleaseExperience`

The existing participant loop (which already tracks connect/disconnect transitions) begins after the `local reconnect = isReconnectSnapshot == true` line. It iterates `participants` and ends with `lastConnectedState[participantId] = connected`.

Add a `monsterTargetId` derivation BEFORE the participant loop:

```lua
local monsterTargetId: string? = nil
local privateMonsterSnap = if type(snapshot) == "table" then snapshot.privateMonster else nil
if type(privateMonsterSnap) == "table"
    and type(privateMonsterSnap.participantId) == "string"
    and privateMonsterSnap.participantId ~= ""
then
    monsterTargetId = privateMonsterSnap.participantId
end
```

Then, INSIDE the existing participant loop, add alive-state tracking alongside the existing connect/disconnect tracking. The `displayName` local is already derived earlier in the loop. After the existing `lastConnectedState[participantId] = connected` line, add:

```lua
local alive = participant.alive == true
local previousAlive = lastParticipantAliveStates[participantId]
if previousAlive == true
    and not alive
    and not reconnect
    and phaseName ~= "Rewards"
    and phaseName ~= "Lobby"
then
    if monsterTargetId ~= nil and monsterTargetId == participantId and currentView then
        currentView:Notify(
            "TARGET ELIMINATED",
            displayName .. " has been eliminated.",
            "Success"
        )
    end
end
lastParticipantAliveStates[participantId] = alive
```

### A3. Reset in Stop() cleanup

In `RoundController.Stop()`, alongside the existing `lastConnectedState = {}` reset, add:

```lua
lastParticipantAliveStates = {}
```

**Constraints for Agent A:**
- `lastParticipantAliveStates` is module-level — declare it alongside `lastConnectedState`, not inside a function.
- `monsterTargetId` is derived once before the participant loop, not inside it.
- The notification fires only when `previousAlive == true` (known alive last tick) AND `not alive` (dead this tick). If `previousAlive == nil` (first snapshot), the condition is false — no notification on reconnect or initial state.
- `not reconnect` suppresses notifications from the initial reconnect snapshot.
- `phaseName ~= "Rewards" and phaseName ~= "Lobby"` suppresses the notification during end-of-round phases. Use `phaseName` which is already derived near the top of `updateReleaseExperience`.
- `monsterTargetId == participantId` means only the monster player sees this notification — other players have no `privateMonsterSnap`, so `monsterTargetId` is nil and the inner `if` never fires for them.
- `displayName` is already derived in the existing participant loop body — do not re-read it.
- `"Success"` is the correct toast variant here — it confirms goal achievement (the elimination).
- If `monsterTargetId` is nil (player is not the monster, or private snapshot is absent), the inner check is skipped silently.

---

## Agent B — `src/client/UI/GameView.lua`

### B1. Add `dayObjectiveNotifiedRound` to the type and state

In the `GameViewState` type definition block, alongside other per-round tracking fields, add:

```lua
dayObjectiveNotifiedRound: number?,
```

In `GameView.new()` (inside the `setmetatable({...}, GameView)` table), initialize it:

```lua
dayObjectiveNotifiedRound = nil,
```

In `GameView:Destroy()`, reset it:

```lua
self.dayObjectiveNotifiedRound = nil
```

### B2. Fire once-per-round when all Day objectives are complete

In `GameView:Update()`, the Day phase block already computes:
- `objectiveDone = readNumber(round, "objectivesCompleted", 0)`
- `objectiveGoal = math.max(1, readNumber(round, "objectiveGoal", 1))`
- `witnessFound` from `readNumber(mystery, "revealedWitnessCount", 0)`
- `witnessTotal` from `readNumber(mystery, "totalWitnessCount", 1)`

After setting `self.objectiveFill.Size` (currently the last line of the `if phase == "Day"` block), add:

```lua
local roundNum = readNumber(round, "roundNumber", 0)
if objectiveDone >= objectiveGoal
    and witnessFound >= witnessTotal
    and roundNum > 0
    and self.dayObjectiveNotifiedRound ~= roundNum
then
    self.dayObjectiveNotifiedRound = roundNum
    self:Notify(
        "Day objectives complete",
        "All camp work done and witnesses interviewed. Investigation begins soon.",
        "Success"
    )
end
```

**Constraints for Agent B:**
- `dayObjectiveNotifiedRound` is a `number?` instance field — not module-level.
- `readNumber(round, "roundNumber", 0)` is the correct way to read the round number — use the same helper already in scope.
- `roundNum > 0` guards against firing on invalid/zero state before the round is initialized.
- `self.dayObjectiveNotifiedRound ~= roundNum` is the dedup guard — it sticks for the rest of that round's Day phase but naturally resets when `roundNum` changes (next round).
- This check lives INSIDE the `if phase == "Day"` branch so it only fires during Day phase, not on later snapshots from other phases.
- Do not fire this notification for the monster player specifically — all living campers should see it. No role check needed: the Day phase branch is only reached for players who have a Day phase view anyway.
- `mystery` is already derived earlier in the Day phase block as `local mystery = if type(state) == "table" then state.mystery else nil`. Use it directly; do not re-read `state.mystery`.
- Do NOT add this notification to the ghost/spectator path — only living campers participating in the Day phase will be in this branch.

---

## Acceptance Criteria

### Agent A
- [ ] When the monster's designated target participant transitions from `alive=true` to `alive=false` via snapshot (not from an action result), the monster player sees a "TARGET ELIMINATED" toast
- [ ] Other players (campers, spectators) do NOT see the toast when a participant dies
- [ ] No toast fires on the first snapshot (when `previousAlive == nil`)
- [ ] No toast fires on reconnect snapshots
- [ ] No toast fires during Lobby or Rewards phase
- [ ] `lastParticipantAliveStates` is cleared in `Stop()`
- [ ] The existing disconnect/reconnect notifications are unaffected

### Agent B
- [ ] When all camp work objectives AND all witness interviews are done during Day phase, a "Day objectives complete" notification appears for the local player
- [ ] The notification fires only once per round (not every update tick)
- [ ] In the next round, the notification fires again when that round's Day objectives complete
- [ ] No notification fires during other phases (Investigation, Campfire, etc.)
- [ ] No notification fires when `roundNum == 0` or round is not yet initialized
- [ ] `dayObjectiveNotifiedRound` resets in `Destroy()`

### Both
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/Controllers/RoundController.lua` | A | Participant alive tracking + monster target-eliminated notification |
| `src/client/UI/GameView.lua` | B | Day objectives complete notification (once per round) |
