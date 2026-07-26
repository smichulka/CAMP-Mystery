# Claude_Request-0030 — Witness Interview Notification + Monster Hunt Target Name

**Base commit:** 47f72d0
**Wave:** 1 (two agents, different files — no merge conflicts)

---

## Preamble — 0029 Review

Request 0029 is accepted as implemented. Both changes are clean: the ghost orientation notification fires exactly once on the death crossing alongside `PlayDeathCinematic()`, and the MurderPlanning objective correctly resolves the victim name via `murderPlan.victimParticipantId` with safe fallback.

No automated runtime harness needed — Studio multiplayer testing covers both changes.

---

## Mission

Two information gaps remain in the Day and Investigation phases:

1. **Agent A** — `src/client/Controllers/RoundController.lua`: When a witness is interviewed during Day phase and `mystery.revealedWitnessCount` increments, no notification fires. All other players learn about new evidence (`PlayEvidenceDiscovery`), but there is no equivalent acknowledgement for witness interviews. Add tracking and a one-time notification each time the witness count increases during the Day phase.

2. **Agent B** — `src/client/UI/GameView.lua`: During Investigation, the monster player sees "HUNT OBJECTIVE — Eliminate your designated target." in the objective panel, but their target's name is never shown. The private `murderPlan.victimParticipantId` is already in the snapshot (same source used in MurderPlanning). Apply the same lookup pattern to the Investigation monster branch so the monster always sees their target's name while hunting.

---

## Agent A — `src/client/Controllers/RoundController.lua`

### A1. Add module-level witness count tracker

Near the top of the file, alongside `lastEvidenceFound`, `lastCulpritEvidenceCount`, and `lastMonsterEvidenceCount`, add:

```lua
local lastRevealedWitnessCount = 0
```

### A2. Initialize on reconnect

In the reconnect initialization block inside the `OnSnapshot("game", ...)` callback, alongside the existing lines:

```lua
lastEvidenceFound = evidenceFoundCount(payload)
lastCulpritEvidenceCount = #evidenceList(payload, "culpritEvidence")
lastMonsterEvidenceCount = #evidenceList(payload, "monsterEvidence")
```

Add:

```lua
local reconnectMystery = if type(payload) == "table" then payload.mystery else nil
lastRevealedWitnessCount = readNumber(reconnectMystery, "revealedWitnessCount", 0)
```

### A3. Detect witness count increase and notify in `updateReleaseExperience`

In `updateReleaseExperience`, after the existing evidence-found block (the block ending with `lastMonsterEvidenceCount = #monsterEvidence`), add witness tracking:

```lua
local mystery = if type(snapshot) == "table" then snapshot.mystery else nil
local revealedWitnessCount = readNumber(mystery, "revealedWitnessCount", 0)
local totalWitnessCount = math.max(1, readNumber(mystery, "totalWitnessCount", 1))
if revealedWitnessCount > lastRevealedWitnessCount
    and not reconnect
    and phaseName == "Day"
    and currentView
then
    currentView:Notify(
        "Witness interviewed",
        string.format("%d of %d witnesses spoken to.", revealedWitnessCount, totalWitnessCount),
        "Info"
    )
end
lastRevealedWitnessCount = revealedWitnessCount
```

### A4. Reset in Stop() cleanup

In `RoundController.Stop()`, alongside the existing reset of `lastEvidenceFound = 0`, add:

```lua
lastRevealedWitnessCount = 0
```

**Constraints for Agent A:**
- `lastRevealedWitnessCount` is a module-level number (initialized to `0`) — add it alongside the other `last*` evidence tracking variables.
- `phaseName == "Day"` guards the notification so it only fires during Day phase; witness count updates to `lastRevealedWitnessCount` happen unconditionally regardless of phase.
- `not reconnect` suppresses notifications from the initial reconnect snapshot.
- `revealedWitnessCount > lastRevealedWitnessCount` fires once per increment (the count can only go up during a round).
- `readNumber(mystery, "totalWitnessCount", 1)` with `math.max(1, ...)` prevents division-by-zero and matches the existing pattern used in GameView for this field.
- The reconnect initialization block sets `lastRevealedWitnessCount` from the payload's mystery so that the first non-reconnect increment after a reconnect fires correctly (not for pre-existing interviews).
- `readNumber` is already defined in this file — use it directly.
- The evidence-found block (`if evidenceFound > lastEvidenceFound`) is unchanged; place the witness block immediately after `lastMonsterEvidenceCount = #monsterEvidence`.

---

## Agent B — `src/client/UI/GameView.lua`

### B1. Derive monster hunt target name in the Investigation monster branch

In `GameView:Update(state, legacyRound, legacyPlayer)`, the Investigation monster branch is:

```lua
if isMonsterPlayer then
    self.progressLabel.Text = "Hunt your targets. Don't get cornered."
    self.objectiveText.Text = "HUNT OBJECTIVE\nEliminate your designated target. Avoid discovery. Use your ability when the time is right."
    self.objectiveFill.Size = UDim2.fromScale(1, 1)
```

Before setting the text fields, derive the victim name using the same pattern established in MurderPlanning (0029):

```lua
local huntMurderPlan = if type(state) == "table" then state.murderPlan else nil
local huntVictimId = if type(huntMurderPlan) == "table"
        and type(huntMurderPlan.victimParticipantId) == "string"
        and huntMurderPlan.victimParticipantId ~= ""
    then huntMurderPlan.victimParticipantId
    else nil
local huntVictimName = "your target"
if huntVictimId ~= nil then
    local huntParticipants = if type(state) == "table"
            and type(state.participants) == "table"
        then state.participants
        else {}
    for _, p in huntParticipants do
        if type(p) == "table" and p.participantId == huntVictimId then
            huntVictimName = readString(p, "displayName", "your target")
            break
        end
    end
end
```

### B2. Update progressLabel and objectiveText to include the target name

Replace:

```lua
self.progressLabel.Text = "Hunt your targets. Don't get cornered."
self.objectiveText.Text = "HUNT OBJECTIVE\nEliminate your designated target. Avoid discovery. Use your ability when the time is right."
```

with:

```lua
self.progressLabel.Text = string.format("Hunt %s. Don't get cornered.", huntVictimName)
self.objectiveText.Text = string.format(
    "HUNT OBJECTIVE\nEliminate %s. Avoid discovery. Use your ability when the time is right.",
    huntVictimName
)
```

**Constraints for Agent B:**
- Name all locals with the `hunt` prefix (`huntMurderPlan`, `huntVictimId`, `huntVictimName`, `huntParticipants`) to avoid any shadowing with the MurderPlanning locals added in 0029 (different branch, but good hygiene).
- `murderPlan` is private — only the monster player receives it. The `isMonsterPlayer` guard already ensures this branch is only reached when `privateMonster.active == true`, so non-monster players never execute this lookup.
- The empty-string check on `victimParticipantId` (`~= ""`) rejects malformed snapshots, matching the existing MurderPlanning pattern.
- Fallback `"your target"` produces "Hunt your target. Don't get cornered." and "HUNT OBJECTIVE\nEliminate your target. Avoid discovery. Use your ability when the time is right." — safe degradation identical to current text minus "designated."
- `readString` is already in scope — use it for the `displayName` fallback.
- `self.objectiveFill.Size = UDim2.fromScale(1, 1)` is unchanged.
- The `elseif localRole == "Spectator"` and `else` (camper evidence) branches are unchanged.

---

## Acceptance Criteria

### Agent A
- [ ] When `mystery.revealedWitnessCount` increases during Day phase, a "Witness interviewed" Info notification fires with "X of Y witnesses spoken to."
- [ ] No notification fires on reconnect snapshots
- [ ] No notification fires when the phase is not "Day" (Investigation, Campfire, etc.)
- [ ] `lastRevealedWitnessCount` is initialized in the reconnect block alongside `lastEvidenceFound`
- [ ] `lastRevealedWitnessCount` is reset to 0 in `Stop()`
- [ ] The existing evidence discovery flow (`FlashEvidenceFound` + `PlayEvidenceDiscovery`) is unchanged

### Agent B
- [ ] During Investigation, the monster player's `progressLabel` reads "Hunt [Name]. Don't get cornered."
- [ ] During Investigation, the monster player's `objectiveText` reads "HUNT OBJECTIVE\nEliminate [Name]. Avoid discovery. Use your ability when the time is right."
- [ ] If `murderPlan` is nil, `victimParticipantId` is absent/empty, or no matching participant is found, both labels fall back to "your target"
- [ ] `objectiveFill.Size` and all other branches (spectator, camper evidence) are unchanged

### Both
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/Controllers/RoundController.lua` | A | Witness interview count tracking + per-interview notification during Day |
| `src/client/UI/GameView.lua` | B | Monster Investigation objective shows target name from `murderPlan` |
