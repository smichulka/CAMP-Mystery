# Claude_Request-0029 — Ghost Orientation + Murderer Target Name

**Base commit:** 98bc6c8
**Wave:** 1 (two agents, different files — no merge conflicts)

---

## Preamble — 0028 Review

Request 0028 is accepted as implemented. No pseudocode corrections were needed. The Campfire toast and updated `objectiveText` (with singular/plural survivor count) are clean.

No automated runtime harness needed — Studio multiplayer testing covers both changes.

---

## Mission

Two orientation gaps remain for players in key moments:

1. **Agent A** — `src/client/Controllers/RoundController.lua`: When a player dies and becomes a ghost, `PlayDeathCinematic()` fires but there is no notification text to orient them afterwards. The player transitions into ghost/spectator mode with no UI message explaining their new state. Add a one-time Info notification on the `ghostJustDied` crossing so the player understands what they are and what to do.

2. **Agent B** — `src/client/UI/GameView.lua`: During MurderPlanning phase, the Murderer sees "MURDERER OBJECTIVE — Eliminate your target." but their target's name is never shown in the objective panel. The private `murderPlan.victimParticipantId` is already in the snapshot; look up the matching participant's display name and show it in the objective text so the Murderer is always oriented to their target.

---

## Agent A — `src/client/Controllers/RoundController.lua`

### A1. Add ghost orientation notification on the death crossing

The existing ghost transition block is:

```lua
-- Ghost transition cinematic — fires once on the false → true crossing.
local ghostJustDied = isGhost == true and lastIsGhost == false and not reconnect
if ghostJustDied and currentView then
    currentView:PlayDeathCinematic()
end
```

Add a `Notify` call inside the same `if ghostJustDied` block, immediately after `PlayDeathCinematic()`:

```lua
local ghostJustDied = isGhost == true and lastIsGhost == false and not reconnect
if ghostJustDied and currentView then
    currentView:PlayDeathCinematic()
    currentView:Notify(
        "You have been eliminated",
        "You are now a ghost. Observe the round and witness the verdict.",
        "Info"
    )
end
```

**Constraints for Agent A:**
- The notification fires ONLY when `ghostJustDied` is true — the same one-time false → true crossing that guards `PlayDeathCinematic()`. Do not add separate tracking state.
- `not reconnect` is already part of the `ghostJustDied` condition — do not add it again.
- Place the `Notify` call AFTER `PlayDeathCinematic()` so the cinematic launches first.
- `"Info"` is the correct toast variant — this is a neutral state change notification, not danger or success.
- No new module-level variables are needed.
- The existing `SetGhostMode` calls on `currentCinematics` and the `lastIsGhost` update that follow are unchanged.

---

## Agent B — `src/client/UI/GameView.lua`

### B1. Look up the victim's display name from the murder plan

In `GameView:Update(state, legacyRound, legacyPlayer)`, the MurderPlanning block is:

```lua
elseif phase == "MurderPlanning" then
    local localRole = if type(player) == "table" and type(player.role) == "string"
        then player.role
        else ""
    if localRole == "Murderer" then
        self.progressLabel.Text = "Plan your attack before night falls."
        self.objectiveText.Text = "MURDERER OBJECTIVE\nEliminate your target. Frame the evidence."
        self.objectiveFill.Size = UDim2.fromScale(1, 1)
    else
        ...
    end
```

Inside the `if localRole == "Murderer"` branch, before setting `self.objectiveText.Text`, derive the victim's name:

```lua
local murderPlan = if type(state) == "table" then state.murderPlan else nil
local victimId = if type(murderPlan) == "table"
        and type(murderPlan.victimParticipantId) == "string"
    then murderPlan.victimParticipantId
    else nil
local victimName = "your target"
if victimId ~= nil then
    local planParticipants = if type(state) == "table"
            and type(state.participants) == "table"
        then state.participants
        else {}
    for _, p in planParticipants do
        if type(p) == "table" and p.participantId == victimId then
            victimName = readString(p, "displayName", "your target")
            break
        end
    end
end
```

### B2. Update the Murderer objectiveText to include the victim's name

Replace:

```lua
self.objectiveText.Text = "MURDERER OBJECTIVE\nEliminate your target. Frame the evidence."
```

with:

```lua
self.objectiveText.Text = string.format(
    "MURDERER OBJECTIVE\nEliminate %s. Frame the evidence.",
    victimName
)
```

**Constraints for Agent B:**
- `murderPlan` is private to the Murderer's snapshot — non-Murderer players have `state.murderPlan == nil`, so `victimId` will be `nil` for them. The branch structure already ensures only the Murderer reaches this code, so this is not a privacy concern.
- Name the participants local `planParticipants` (not `participants`) to avoid shadowing any existing scope variable.
- `readString` is already in scope as a module-level helper in `GameView.lua` — use it for the `displayName` fallback.
- The fallback `"your target"` produces "Eliminate your target." which is the current text, ensuring safe degradation if `murderPlan` is absent or the participant is not found.
- The `progressLabel`, `objectiveFill`, and the non-Murderer `else` branch are unchanged.
- Only add this logic inside the `if localRole == "Murderer"` branch — do not touch the spectator or camper branches.

---

## Acceptance Criteria

### Agent A
- [ ] When a player transitions from `isGhost == false` to `isGhost == true` (not on reconnect), a "You have been eliminated" Info notification fires
- [ ] The notification fires in the same `if ghostJustDied` block as `PlayDeathCinematic()`, after it
- [ ] No notification fires on reconnect (a reconnecting ghost player is already a ghost)
- [ ] No new module-level state is added
- [ ] `PlayDeathCinematic()` is unchanged and still called first
- [ ] The `SetGhostMode` calls and `lastIsGhost` update that follow are unchanged

### Agent B
- [ ] During MurderPlanning, the Murderer's `objectiveText` reads "MURDERER OBJECTIVE\n Eliminate [VictimName]. Frame the evidence."
- [ ] If `murderPlan` is nil or `victimParticipantId` is absent, the text reads "MURDERER OBJECTIVE\nEliminate your target. Frame the evidence." (fallback)
- [ ] If the victim participant is not found in `state.participants`, the same fallback applies
- [ ] The `progressLabel`, `objectiveFill.Size`, and `else` branch are unchanged
- [ ] No change to any other phase

### Both
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/Controllers/RoundController.lua` | A | Ghost orientation notification on death crossing |
| `src/client/UI/GameView.lua` | B | Murderer objectiveText shows victim display name |
