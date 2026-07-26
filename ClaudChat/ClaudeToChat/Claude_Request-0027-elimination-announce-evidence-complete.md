# Claude_Request-0027 — Elimination Announcement + Evidence Collection Complete

**Base commit:** a2f17ea
**Wave:** 1 (two agents, different files — no merge conflicts)

---

## Preamble — 0026 Review

Request 0026 is accepted as implemented, including both live-contract corrections:
- `snapshot.murderPlan.victimParticipantId` is the correct path for the monster's designated victim (not `privateMonster.participantId`).
- Day objectives toast correctly requires `team == "Campers"`, alive, and non-ghost to avoid showing to monster or spectator players.

No automated runtime harness needed — Roblox Studio multiplayer is the right venue.

---

## Mission

Two feedback gaps remain for surviving and searching players:

1. **Agent A** — `src/client/Controllers/RoundController.lua`: When any participant is eliminated (alive → dead transition during Investigation), surviving players receive no notification. The monster already gets "TARGET ELIMINATED" for their specific target. All other players — including the monster (for non-target deaths) and all surviving campers — should see a public "[Name] has been eliminated" announcement. The eliminated player themselves should not receive this toast (they have the death cinematic).

2. **Agent B** — `src/client/UI/GameView.lua`: When all required evidence is collected during Investigation, campers get no acknowledgement. The progress label updates silently. Add a once-per-round notification for living camper-team players when `evidenceFound >= evidenceGoal`, so they know to return for the Campfire vote.

---

## Agent A — `src/client/Controllers/RoundController.lua`

### A1. Derive local participant ID before the participant loop

Near the top of `updateReleaseExperience`, `player` is already derived. Before the existing participant loop, add:

```lua
local localParticipantId = readString(player, "participantId", "")
```

### A2. Extend the alive-transition block with a public announcement

The existing participant loop already contains an alive-state transition block (from 0026) structured as:

```lua
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
```

Change the inner `if` to `if ... elseif ...` so the public announcement fires for every other death:

```lua
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
    elseif participantId ~= localParticipantId and currentView then
        currentView:Notify(
            displayName .. " has been eliminated",
            "A player has been taken out.",
            "Warning"
        )
    end
end
```

**Constraints for Agent A:**
- `localParticipantId` is derived once before the loop, using `readString(player, "participantId", "")` — do not re-read inside the loop.
- The `elseif` structure ensures the monster player sees "TARGET ELIMINATED" (not the generic announcement) for their specific target, while seeing the generic announcement for any other deaths.
- `participantId ~= localParticipantId` suppresses the toast for the eliminated player themselves — they already have the death cinematic.
- Camper-team players, ghost observers, and spectators all receive the generic announcement (no team or alive filter here — all surviving observers benefit from knowing).
- The existing connect/disconnect notifications (`displayName .. " left"` and `displayName .. " reconnected"`) are completely unchanged — do not touch them.
- Phase guards (`phaseName ~= "Rewards"` and `phaseName ~= "Lobby"`) already suppress end-of-round and lobby deaths.
- `not reconnect` already suppresses first-snapshot bulk transitions.
- No new module-level variables are needed for this change — `localParticipantId` is a local inside `updateReleaseExperience`.

---

## Agent B — `src/client/UI/GameView.lua`

### B1. Add `evidenceNotifiedRound` to the type and state

In the `GameViewState` type definition, alongside `dayObjectiveNotifiedRound`, add:

```lua
evidenceNotifiedRound: number?,
```

In `GameView.new()`, initialize it:

```lua
evidenceNotifiedRound = nil,
```

In `GameView:Destroy()`, reset it:

```lua
self.evidenceNotifiedRound = nil
```

### B2. Fire once-per-round when evidence collection is complete

In `GameView:Update()`, the Investigation phase block has three branches:
1. `if isMonsterPlayer` — monster HUD
2. `elseif localRole == "Spectator"` — spectator observing text
3. `else` — living camper evidence objective

Inside the `else` branch (living camper evidence objective), after the existing `self.objectiveFill.Size = ...` line, add:

```lua
local roundNum = readNumber(round, "roundNumber", 0)
if evidenceFound >= evidenceGoal
    and roundNum > 0
    and self.evidenceNotifiedRound ~= roundNum
then
    self.evidenceNotifiedRound = roundNum
    self:Notify(
        "Evidence complete",
        "All clues collected. Return for the Campfire.",
        "Success"
    )
end
```

**Constraints for Agent B:**
- `evidenceNotifiedRound` is a `number?` instance field — same pattern as `dayObjectiveNotifiedRound`.
- `evidenceFound` and `evidenceGoal` are already computed before the `if phase == "Day"` / `elseif phase == "Investigation"` branches — use them directly; do not re-read from round.
- `round` is already in scope in the `Update` call — `readNumber(round, "roundNumber", 0)` is the correct helper call.
- `roundNum > 0` guards against firing on uninitialized state.
- `self.evidenceNotifiedRound ~= roundNum` deduplicates within a round; a new `roundNum` re-arms for the next round automatically.
- This fires ONLY in the living-camper `else` branch — monster players (`isMonsterPlayer`) and spectators (`localRole == "Spectator"`) are excluded by branch structure.
- Do NOT fire this notification in the Day or Campfire branches.
- `"Success"` is the correct toast variant — completion of a collection goal.

---

## Acceptance Criteria

### Agent A
- [ ] When a camper participant dies during Investigation, all other surviving and observing players see "[Name] has been eliminated" (Warning toast)
- [ ] The eliminated player themselves does NOT receive the public announcement
- [ ] The monster player sees "TARGET ELIMINATED" for their specific target (not the generic announcement)
- [ ] The monster player sees "[Name] has been eliminated" for any non-target participant death
- [ ] No announcement fires on reconnect snapshots
- [ ] No announcement fires in Lobby or Rewards phase
- [ ] Existing disconnect/reconnect notifications are unaffected

### Agent B
- [ ] When `evidenceFound >= evidenceGoal` for the first time in a round during Investigation (living camper path), a "Evidence complete" notification fires
- [ ] The notification fires only once per round
- [ ] The next round re-arms the notification (new round number)
- [ ] Monster players and spectators do NOT receive the evidence notification
- [ ] No notification fires when `roundNum == 0`
- [ ] `evidenceNotifiedRound` resets in `Destroy()`

### Both
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/Controllers/RoundController.lua` | A | Public elimination announcement for all surviving players |
| `src/client/UI/GameView.lua` | B | Evidence collection complete notification (once per round, living campers) |
