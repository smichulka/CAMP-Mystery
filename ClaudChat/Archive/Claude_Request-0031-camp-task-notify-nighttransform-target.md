# Claude_Request-0031 — Camp Task Completion + NightTransform Target Name

**Base commit:** e64df71
**Wave:** 1 (two agents, different files — no merge conflicts)

---

## Preamble — 0030 Review

Request 0030 is accepted as implemented, including the ordering correction: `phaseName` and `reconnect` were already declared earlier in `updateReleaseExperience`, so the witness tracking block inserts cleanly after the evidence block. The Investigation monster hunt target lookup uses `huntMurderPlan` / `huntVictimId` / `huntVictimName` / `huntParticipants` with direct `state.participants` access (no `asTable`).

No automated runtime harness needed — Studio multiplayer testing covers both changes.

---

## Mission

Two feedback gaps remain in the Day and NightTransform phases:

1. **Agent A** — `src/client/Controllers/RoundController.lua`: When a camper completes a camp work task during Day phase and `round.objectivesCompleted` increments, no notification fires. The witness interview notification (0030) covers the social objective; this covers the task objective. Add tracking and a notification each time the completed count increases during Day phase — same pattern as witness interviews.

2. **Agent B** — `src/client/UI/GameView.lua`: During NightTransform, the monster player sees "YOU ARE THE MONSTER — The town is yours. Hunt carefully — the campers will fight back." The target's name is not included. MurderPlanning (0029) and Investigation (0030) both now show the target name. Apply the same lookup to NightTransform so the monster sees their target at every phase of the hunt.

---

## Agent A — `src/client/Controllers/RoundController.lua`

### A1. Add module-level camp task tracker

Near the top of the file, alongside `lastRevealedWitnessCount`, add:

```lua
local lastObjectivesCompleted = 0
```

### A2. Initialize on reconnect

In the reconnect initialization block (where `lastRevealedWitnessCount` is initialized from `reconnectMystery`), add alongside it:

```lua
local reconnectRound = if type(payload) == "table" then payload.round else nil
lastObjectivesCompleted = readNumber(reconnectRound, "objectivesCompleted", 0)
```

### A3. Detect task completion and notify in `updateReleaseExperience`

Immediately after the witness block (the `lastRevealedWitnessCount = revealedWitnessCount` line), add:

```lua
local objectivesCompleted = readNumber(round, "objectivesCompleted", 0)
local objectiveGoal = math.max(1, readNumber(round, "objectiveGoal", 1))
if objectivesCompleted > lastObjectivesCompleted
    and not reconnect
    and phaseName == "Day"
    and currentView
then
    currentView:Notify(
        "Camp task complete",
        string.format("%d of %d tasks done.", objectivesCompleted, objectiveGoal),
        "Info"
    )
end
lastObjectivesCompleted = objectivesCompleted
```

### A4. Reset in Stop() cleanup

In `RoundController.Stop()`, alongside the reset of `lastRevealedWitnessCount = 0`, add:

```lua
lastObjectivesCompleted = 0
```

**Constraints for Agent A:**
- `lastObjectivesCompleted` is a module-level number initialized to `0` — add it directly alongside `lastRevealedWitnessCount`.
- `round` is already derived near the top of `updateReleaseExperience` as `local round = if type(snapshot) == "table" then snapshot.round else nil` — use it directly; do not re-read from snapshot.
- `phaseName == "Day"` restricts the notification to Day phase; `lastObjectivesCompleted` is still updated unconditionally so subsequent phases do not produce stale comparisons.
- `not reconnect` suppresses the notification on the first reconnect snapshot.
- `objectivesCompleted > lastObjectivesCompleted` fires once per increment and handles multiple increments in one snapshot (rare but possible).
- `readNumber(round, "objectivesCompleted", 0)` is the same helper already used throughout this file.
- The reconnect initialization uses `payload.round` (not `snapshot.round`) because the reconnect block operates on the raw `payload` before it is assigned to `state`. Match the pattern of `reconnectMystery` one line above it.
- The witness notification block is unchanged.

---

## Agent B — `src/client/UI/GameView.lua`

### B1. Add victim name lookup in the NightTransform monster branch

The NightTransform `isMonsterPlayer` branch currently is:

```lua
if isMonsterPlayer then
    self.progressLabel.Text = "The transformation is complete. The town awaits."
    self.objectiveText.Text = "YOU ARE THE MONSTER\nThe town is yours. Hunt carefully — the campers will fight back."
    self.objectiveFill.Size = UDim2.fromScale(1, 1)
```

Before setting the text fields, add a victim name lookup using the same pattern as the Investigation monster branch (0030), but prefixed with `night` to avoid any scope collision with that branch's `hunt` locals:

```lua
local nightMurderPlan = if type(state) == "table" then state.murderPlan else nil
local nightVictimId = if type(nightMurderPlan) == "table"
        and type(nightMurderPlan.victimParticipantId) == "string"
        and nightMurderPlan.victimParticipantId ~= ""
    then nightMurderPlan.victimParticipantId
    else nil
local nightVictimName = "your target"
if nightVictimId ~= nil then
    local nightParticipants = if type(state) == "table"
            and type(state.participants) == "table"
        then state.participants
        else {}
    for _, p in nightParticipants do
        if type(p) == "table" and p.participantId == nightVictimId then
            nightVictimName = readString(p, "displayName", "your target")
            break
        end
    end
end
```

### B2. Update objectiveText to include the target name

Replace:

```lua
self.objectiveText.Text = "YOU ARE THE MONSTER\nThe town is yours. Hunt carefully — the campers will fight back."
```

with:

```lua
self.objectiveText.Text = string.format(
    "YOU ARE THE MONSTER\nThe town is yours. Hunt %s — the campers will fight back.",
    nightVictimName
)
```

Leave `progressLabel.Text` and `objectiveFill.Size` unchanged.

**Constraints for Agent B:**
- Use the `night` prefix for all locals (`nightMurderPlan`, `nightVictimId`, `nightVictimName`, `nightParticipants`) to avoid shadowing the `hunt*` locals declared in the Investigation branch above.
- Follow the exact same lookup structure as the Investigation branch (lines ~3967–3984): `if type(state) == "table" then state.murderPlan else nil` for the plan, direct `state.participants` table check for the participants (no `asTable` call).
- Fallback `"your target"` produces "Hunt your target — the campers will fight back." — safe degradation when `murderPlan` or the participant is absent.
- `progressLabel.Text = "The transformation is complete. The town awaits."` is unchanged.
- `objectiveFill.Size = UDim2.fromScale(1, 1)` is unchanged.
- The `else` branch (camper NightTransform text) is unchanged.

---

## Acceptance Criteria

### Agent A
- [ ] When `round.objectivesCompleted` increases during Day phase (not reconnect), a "Camp task complete" Info notification fires with "X of Y tasks done."
- [ ] No notification fires on reconnect snapshots
- [ ] No notification fires outside Day phase
- [ ] `lastObjectivesCompleted` is initialized in the reconnect block alongside `lastRevealedWitnessCount`
- [ ] `lastObjectivesCompleted` is reset to 0 in `Stop()`
- [ ] The witness interview notification block is unchanged

### Agent B
- [ ] During NightTransform, the monster player's `objectiveText` reads "YOU ARE THE MONSTER\nThe town is yours. Hunt [Name] — the campers will fight back."
- [ ] If `murderPlan`, `victimParticipantId`, or the matching participant is absent, the text reads "Hunt your target — the campers will fight back."
- [ ] `progressLabel` and `objectiveFill` in the NightTransform monster branch are unchanged
- [ ] The camper `else` branch text is unchanged

### Both
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/Controllers/RoundController.lua` | A | Camp task completion count tracking + per-task notification during Day |
| `src/client/UI/GameView.lua` | B | NightTransform monster objective shows target name |
