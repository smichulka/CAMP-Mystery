# Claude_Request-0037 — All Votes Cast Notification

**Base commit:** 9daa47e
**Wave:** 1 (single agent, single file)

---

## Preamble — 0036 Review

Request 0036 is accepted as implemented. The Rewards phase objective panel now shows role-specific and winner-specific outcome text (CAUGHT / ESCAPED / VICTORY / DEFEAT / ROUND OVER) with the fill bar reflecting the outcome. Lobby and Resolution fallback text unchanged. All checks pass.

---

## Mission

During the Campfire phase, the vote count label shows "X/Y VOTED" continuously but there is no moment of tension when the last vote locks in. Adding a single "All votes are in" notification — fired exactly once per round at the moment `votesCast` reaches `eligibleVoters` — gives players a clear signal that the verdict is sealed and coming.

---

## Agent A — `src/client/Controllers/RoundController.lua`

### A1. Add module-level round tracker

Near line 89–90, alongside `lastRoleRevealRound` and `lastWinnerAnnounced`, add:

```lua
local lastVoteCompleteRound: number? = nil
```

### A2. Reset in Stop()

In `RoundController.Stop()`, alongside the other `= nil` resets, add:

```lua
lastVoteCompleteRound = nil
```

### A3. Initialize on reconnect

In the reconnect initialization block (where `lastRoleRevealRound = round.roundNumber` is set at line ~1027), add immediately after:

```lua
local reconnectVotesCast = math.floor(readNumber(reconnectRound, "votesCast", 0))
local reconnectEligible = math.floor(readNumber(reconnectRound, "eligibleVoters", 0))
if reconnectEligible > 0
    and reconnectVotesCast >= reconnectEligible
    and type(round) == "table"
    and type(round.roundNumber) == "number"
then
    lastVoteCompleteRound = round.roundNumber
end
```

This silently marks the current round as complete-voted on reconnect so the notification does not fire spuriously on the first post-reconnect snapshot.

Note: `reconnectRound` is already in scope at that point (declared earlier in the reconnect block as `local reconnectRound = if type(payload) == "table" then payload.round else nil`). Use it directly.

### A4. Fire notification in `updateReleaseExperience`

In `updateReleaseExperience`, `round`, `roundNumber`, `phaseName`, `reconnect`, and `currentView` are all derived near the top of the function. `votesCast` and `eligibleVoters` are not yet derived in RoundController — derive them locally in this block.

After the witness interview block and the camp task block (i.e., after `lastObjectivesCompleted = objectivesCompleted`), add:

```lua
if phaseName == "Campfire" and not reconnect and roundNumber ~= nil and currentView then
    local votesCast = math.floor(readNumber(round, "votesCast", 0))
    local eligibleVoters = math.floor(readNumber(round, "eligibleVoters", 0))
    if eligibleVoters > 0
        and votesCast >= eligibleVoters
        and roundNumber ~= lastVoteCompleteRound
    then
        currentView:Notify(
            "All votes are in",
            "The campfire vote is sealed. The verdict is coming.",
            "Warning"
        )
        lastVoteCompleteRound = roundNumber
    end
end
```

**Constraints for Agent A:**
- `readNumber(round, "votesCast", 0)` and `readNumber(round, "eligibleVoters", 0)` — the same field names used in `GameView:Update` for the vote count label.
- `math.floor` — consistent with GameView's own use; guards against fractional server values.
- `eligibleVoters > 0` — prevents a false-complete when the server has not yet set the eligible count.
- `roundNumber ~= lastVoteCompleteRound` — dedup: fires exactly once per round, matching the `lastRoleRevealRound` pattern at line ~634.
- `not reconnect` — suppresses on reconnect snapshots.
- `phaseName == "Campfire"` — restricts to the active vote phase only.
- `lastVoteCompleteRound = roundNumber` — set only inside the `if eligibleVoters > 0 and votesCast >= eligibleVoters` block, not unconditionally, so a partial-vote snapshot does not pre-mark the round as complete.
- The reconnect init uses `reconnectRound` (already in scope) and `round` for `roundNumber`; both are available in that block.
- No other changes to this file.

---

## Acceptance Criteria

- [ ] During Campfire phase, when `votesCast >= eligibleVoters` and `eligibleVoters > 0` and this is the first time in this round, an "All votes are in" Warning notification fires
- [ ] The notification fires exactly once per round even if multiple Campfire snapshots arrive after all votes are cast
- [ ] No notification fires on reconnect snapshots (`not reconnect` guard)
- [ ] No notification fires when `eligibleVoters == 0`
- [ ] On reconnect during an already-complete Campfire vote, `lastVoteCompleteRound` is initialized to suppress the notification on the next snapshot
- [ ] `lastVoteCompleteRound` is reset to `nil` in `Stop()`
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/Controllers/RoundController.lua` | A | Once-per-round "All votes are in" notification when Campfire vote is complete |
