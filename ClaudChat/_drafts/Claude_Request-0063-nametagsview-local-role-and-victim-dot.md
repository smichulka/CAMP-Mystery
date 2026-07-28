# Claude_Request-0063 — NametagsView localRole Parameter + Murderer Victim Dot Highlight

**Base commit:** (updated after 0062 lands)
**Wave:** 2 (Agent A: NametagsView.lua add localRole param + victim dot color; Agent B: RoundController.lua forward roleName + murderPlan victimId to NametagsView:Update)

---

## Preamble — 0062 Review

Request 0062 is accepted. RoundController "Witness interviewed" and "Camp task complete" are role-branched; TutorialView progress header shows "MURDERER BRIEFING" for Murderer-specific steps. All 83 checks passed.

---

## Mission

`NametagsView.lua` is architecturally role-blind — its `Update` method signature never receives `localRole` or the Murderer's chosen victim ID. Audit confirmed:

1. **`Update` signature** (lines 198–202): `(participants, localParticipantId, phase)` — no role, no victimId. The call site in `RoundController.lua` (line 424) does not forward `roleName` even though it is in scope.

2. **Victim dot**: Every living participant receives the same green success dot regardless of whether the Murderer is looking at their designated victim. The snapshot in `RoundController` already tracks `murderPlan.victimParticipantId` (line ~755) — the data exists server-side and is delivered to the client but never forwarded to the nametag renderer.

3. **"Unknown camper" fallback** (line 241): `readString(participant, "displayName", "Unknown camper")` — the word "camper" is role-specific. A role-neutral fallback `"Unknown"` covers all roles.

This is the final high-priority architectural gap in the nametag rendering path.

---

## Agent A — `src/client/UI/NametagsView.lua` (accept localRole + victimParticipantId; apply victim dot)

### A1. Pre-implementation inspection

Agent A must read the file and confirm:

1. Exact `Update` method signature (lines 198–202). Note all current parameters.
2. The per-participant loop body (lines ~215–264). Identify:
   - How each participant's dot color is currently set (what variable or constant and what theme key).
   - Whether a participant's `participantId` is read inside the loop.
   - Where the dot element is referenced (local variable or `self`-stored).
3. Line 241: confirm the exact `readString(participant, "displayName", "Unknown camper")` call.
4. Whether there are other callers of `NametagsView:Update` besides `RoundController.lua`. Search for `:Update(` in nametag-related call sites.

### A2. Extend `Update` signature with `localRole` and `victimParticipantId`

**New signature:**
```lua
function NametagsView:Update(
    participants: { any },
    localParticipantId: string,
    phase: string,
    localRole: string?,              -- new, optional — defaults to ""
    victimParticipantId: string?     -- new, optional — only populated for Murderer
)
```

Both new parameters are optional (`?`) so existing callers that haven't been updated yet still compile and run without error — they just don't pass role data and see the default behavior.

**Constraints:**
- Adding optional parameters to the signature is backward-compatible in Luau with `--!strict` only if the parameters are typed as optional (`string?`). Confirm the file uses `--!strict` and add `?` types accordingly.
- The method body must guard on `localRole ~= nil` or `localRole ~= ""` before applying Murderer-specific logic.

### A3. Apply amber/danger dot color to the Murderer's designated victim

**Inside the per-participant loop**, after the standard dot color is set:

```lua
-- Existing: set dot color based on participant.alive / healthState
dot.BackgroundColor3 = Theme.Colors.Success  -- (or whatever the current logic is)

-- New: override for Murderer's victim
if localRole == "Murderer"
    and victimParticipantId ~= nil
    and participant.participantId == victimParticipantId
    and participant.alive == true  -- only highlight if target is still alive
then
    dot.BackgroundColor3 = Theme.Colors.Amber  -- or Theme.Colors.DangerBright if Amber doesn't exist
end
```

**What to use for the dot color override:**
- First choice: `Theme.Colors.Amber` — matches the urgency tier used in campfire timer and ability warnings.
- Second choice: `Theme.Colors.DangerBright` — if Amber is not defined in `Theme.lua`.
- Read `Theme.lua` to confirm which constant exists.

**What NOT to change:**
- The dot's shape, size, position, and visibility logic are unchanged.
- The dot color logic for non-victim participants is unchanged.
- Ghost / Spectator participants' dot rendering is unchanged.
- If `participant.alive == false`, the existing dead-state rendering applies (do not highlight a dead victim with Amber — they are already eliminated).

### A4. "Unknown camper" → "Unknown" fallback

Change line ~241:
```lua
-- Before:
local displayName = readString(participant, "displayName", "Unknown camper")

-- After:
local displayName = readString(participant, "displayName", "Unknown")
```

This is a one-word change. No role branch needed — `"Unknown"` is valid for all roles.

---

## Agent B — `src/client/Controllers/RoundController.lua` (forward role + victimId to NametagsView)

### B1. Pre-implementation inspection

Agent B must read the file and confirm:

1. Find the `currentNametags:Update(...)` call (~line 424). Note the exact arguments currently passed.
2. Find where `roleName` is derived at the enclosing function scope (confirm it is accessible at line 424).
3. Find where `murderPlan` or `victimParticipantId` is read from the snapshot (~line 755 or nearby). Confirm:
   - The exact key path: `snapshot.murderPlan.victimParticipantId` or `snapshotState.player.murderPlan.victimId` or similar.
   - Whether this value is stored as a local variable in scope at line 424.
   - Whether it is only populated during MurderPlanning/NightTransform phases or available throughout the round.
4. If `victimParticipantId` is not already a local variable at the call site, identify the shortest read path to get it.

### B2. Forward localRole and victimParticipantId to NametagsView:Update

**Current (approximate):**
```lua
currentNametags:Update(participants, localParticipantId, phaseName)
```

**Target:**
```lua
local victimId = readString(snapshotState, "player.murderPlan.victimParticipantId", "")
-- (use whatever key path B1 inspection reveals)

currentNametags:Update(
    participants,
    localParticipantId,
    phaseName,
    roleName,
    if victimId ~= "" then victimId else nil
)
```

**Constraints:**
- `roleName` is already in scope — no new state read needed.
- `victimParticipantId` may be an empty string or nil when the Murderer hasn't chosen a target yet — pass `nil` in that case (the `if victimId ~= ""` guard handles this).
- If `murderPlan.victimParticipantId` is not in the snapshot at this call site, read it with `readString(snapshotState, "player.murderPlan.victimParticipantId", "")` — Agent B must confirm the exact key path.
- If there are multiple `currentNametags:Update(...)` calls (e.g., a reconnect path), update all of them with the same signature.

---

## Acceptance Criteria

**A2 — Update signature:**
- [ ] `NametagsView:Update` accepts `localRole: string?` and `victimParticipantId: string?` as 4th/5th args
- [ ] File compiles with `--!strict` (optional types used)
- [ ] Existing callers that don't pass these args still compile and run correctly

**A3 — Victim dot:**
- [ ] Murderer viewing their living victim: dot overrides to Amber/DangerBright color
- [ ] Murderer viewing a non-victim: standard dot color (unchanged)
- [ ] Murderer viewing a dead victim: dead-state dot rendering (unchanged, no Amber override)
- [ ] All non-Murderer roles: all dot colors unchanged

**A4 — "Unknown" fallback:**
- [ ] `readString(participant, "displayName", "Unknown")` — "camper" removed

**B2 — Forward to Update:**
- [ ] `currentNametags:Update(...)` passes `roleName` and `victimId` (or `nil`) as 4th/5th args
- [ ] All `currentNametags:Update` call sites updated
- [ ] No new state reads needed beyond what's already in scope

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|---|---|---|
| `src/client/UI/NametagsView.lua` | A | Add `localRole`, `victimParticipantId` optional params; amber dot for Murderer's living victim; "Unknown" fallback |
| `src/client/Controllers/RoundController.lua` | B | Forward `roleName` + `victimParticipantId` to all `currentNametags:Update(...)` calls |
