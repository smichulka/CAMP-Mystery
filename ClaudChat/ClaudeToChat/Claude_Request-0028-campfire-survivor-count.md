# Claude_Request-0028 — Campfire Survivor Count

**Base commit:** cfe41de
**Wave:** 1 (two agents, different files — no merge conflicts)

---

## Preamble — 0027 Review

Request 0027 is accepted as implemented, including the live-contract correction: the evidence completion notification requires the same living-Camper guard (`team == "Campers"`, `alive`, non-ghost) as the day objectives notification, because the Investigation `else` branch is not inherently limited to living campers.

No automated runtime harness needed — Studio multiplayer testing covers both changes.

---

## Mission

When players transition to the Campfire phase, they have no immediate sense of how many people survived the Investigation. The vote modal opens and the objective panel reads "FINAL OBJECTIVE — Review the notebook and identify the Murderer." — generic text that gives no situational context. Two complementary changes address this:

1. **Agent A** — `src/client/Controllers/RoundController.lua`: Fire a one-time toast when the phase enters Campfire, reporting how many participants are still alive. All players (living, ghost, spectator) see this toast — it summarises the round's cost at exactly the right dramatic moment.

2. **Agent B** — `src/client/UI/GameView.lua`: Update the Campfire `objectiveText` (and the spectator equivalent) to show the live participant count so the information persists beyond the toast.

---

## Agent A — `src/client/Controllers/RoundController.lua`

### A1. Add survivor count notification on Campfire entry

In `updateReleaseExperience`, the phase-transition block begins with:

```lua
if phaseName and phaseName ~= lastCinematicPhase then
    local previousPhase = lastCinematicPhase
    lastCinematicPhase = phaseName
```

and ends (before the closing `end`) with the keybind hint and Resolution vote reveal logic. Somewhere after `currentView:PlayPhaseTitleCard(phaseName, reconnect)` and before the `if phaseName == "Resolution"` block, add:

```lua
if phaseName == "Campfire" and currentView and not reconnect then
    local aliveCount = 0
    for _, participant in participants do
        if type(participant) == "table" and participant.alive == true then
            aliveCount += 1
        end
    end
    local body = if aliveCount == 1
        then "One player remains. Cast your vote."
        else string.format("%d players remain. Cast your vote.", aliveCount)
    currentView:Notify("CAMPFIRE VOTE", body, "Warning")
end
```

**Constraints for Agent A:**
- `participants` is already derived earlier in `updateReleaseExperience` (the table of all participant snapshots from the snapshot) — use it directly; do not re-derive.
- `not reconnect` suppresses the toast when a player connects mid-round directly into Campfire.
- Count ALL alive participants (`participant.alive == true`) regardless of role, team, or bot status — the count intentionally includes the Murderer since they are alive and the campers do not yet know who they are.
- The singular/plural branch ("One player" vs "N players") avoids awkward "1 players remain" text.
- `aliveCount == 0` produces "0 players remain. Cast your vote." — this edge case is acceptable (round is already over in practice).
- Place this block AFTER `PlayPhaseTitleCard` so it does not interrupt the phase title cinematic.
- The "Warning" variant is appropriate — Campfire is the moment of accountability, not celebration.

---

## Agent B — `src/client/UI/GameView.lua`

### B1. Count alive participants in the Campfire branch of Update

In `GameView:Update(state, legacyRound, legacyPlayer)`, the Campfire block begins with:

```lua
elseif phase == "Campfire" then
    local cast = readNumber(round, "votesCast", 0)
    local eligible = math.max(1, readNumber(round, "eligibleVoters", 1))
    local localRole = ...
```

After deriving `cast` and `eligible` (but before the `if localRole == "Spectator"` branch), add a participant count:

```lua
local campfireParticipants = if type(state) == "table"
        and type(state.participants) == "table"
    then state.participants
    else {}
local aliveCount = 0
for _, p in campfireParticipants do
    if type(p) == "table" and p.alive == true then
        aliveCount += 1
    end
end
local survivorPhrase = if aliveCount == 1
    then "1 player remains"
    else string.format("%d players remain", aliveCount)
```

### B2. Update objectiveText for living player path

Change the non-spectator `objectiveText` from:

```lua
self.objectiveText.Text = "FINAL OBJECTIVE\nReview the notebook and identify the Murderer."
```

to:

```lua
self.objectiveText.Text = string.format(
    "FINAL VOTE\n%s. Review your notebook and identify the Murderer.",
    survivorPhrase
)
```

### B3. Update objectiveText for spectator path

Change the spectator `objectiveText` from:

```lua
self.objectiveText.Text = "OBSERVING\nThe campers are deliberating. The vote will reveal the verdict."
```

to:

```lua
self.objectiveText.Text = string.format(
    "OBSERVING\n%s. The vote will reveal the verdict.",
    survivorPhrase
)
```

**Constraints for Agent B:**
- `state` is the first parameter of `GameView:Update(state, legacyRound, legacyPlayer)` and is in scope throughout the method — use it directly to derive `state.participants`.
- Name the local `campfireParticipants` (not `participants`) to avoid shadowing any enclosing scope.
- Count `p.alive == true` — same condition used everywhere else in the codebase for alive checks.
- `survivorPhrase` is a local derived once before the `if localRole == "Spectator"` branch and used in both branches.
- The phrase "FINAL VOTE" replaces "FINAL OBJECTIVE" in the non-spectator path — it is more action-oriented and matches the actual task.
- The `progressLabel` lines (`"Votes locked X/Y - accuse carefully."` and `"Votes locked X/Y - observing."`) are unchanged.
- `objectiveFill.Size` is unchanged.
- Do not add the survivor count to any phase other than Campfire.

---

## Acceptance Criteria

### Agent A
- [ ] When transitioning into Campfire phase (not reconnect), a "CAMPFIRE VOTE" Warning toast appears with the alive participant count
- [ ] The count uses singular "1 player" phrasing when exactly one participant is alive
- [ ] The toast does NOT fire on reconnect into a mid-round Campfire
- [ ] The toast fires for all player types (living, ghost, spectator) — it is not role-gated
- [ ] The existing round-start "ROUND N" and disconnect/reconnect toasts are unaffected

### Agent B
- [ ] During Campfire, the non-spectator `objectiveText` reads "FINAL VOTE\nN players remain. Review your notebook and identify the Murderer."
- [ ] During Campfire, the spectator `objectiveText` reads "OBSERVING\nN players remain. The vote will reveal the verdict."
- [ ] Singular form ("1 player remains") is used when `aliveCount == 1`
- [ ] The `progressLabel` and `objectiveFill` in the Campfire block are unchanged
- [ ] No other phase's `objectiveText` or `progressLabel` is modified

### Both
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/Controllers/RoundController.lua` | A | One-time Campfire entry toast with alive participant count |
| `src/client/UI/GameView.lua` | B | Campfire objectiveText updated with persistent survivor count |
