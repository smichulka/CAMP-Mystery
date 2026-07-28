# Claude_Request-0052 — Spectator Reconnect Structural Fix + Vote Candidate Self-Marker

**Base commit:** (updated after 0051 lands)
**Wave:** 2 (Agent A: RoundController.lua Spectator reconnect; Agent B: GameView.lua vote candidate self-marker)

---

## Preamble — 0051 Review

Request 0051 is accepted. PlayRoundSummary has Murderer stat rows (Outcome, Eliminations, Votes Against You, Survivors); Rewards phase now has isGhost branch; RoundSummaryStats type has optional Murderer fields. All 83 checks passed.

---

## Mission

Two structural gaps:

1. **Spectator reconnect is silently broken.** The `isReconnectSnapshot` flag is computed with a hard `player.role ~= "Spectator"` exclusion, meaning a Spectator who drops and reconnects mid-round receives no reconnect toast, no PrepareReconnectSnapshot call, and no phase-context UI update. They rejoin in silence. This is a structural bug, not just a copy gap.

2. **Vote candidate list shows the Murderer's own name without a self-marker.** The Murderer appears in the suspects list they vote from (they can even vote for themselves). There is no "(YOU)" label, color differentiation, or any visual signal that one of those buttons is their own entry. A Spectator exclusion would be more complex (they don't vote) but the self-marker is a simple, targeted improvement.

---

## Agent A — `src/client/Controllers/RoundController.lua`

### A1. isReconnectSnapshot — remove Spectator exclusion and handle separately

**Context:** Lines ~1145–1150:

```lua
local isReconnectSnapshot = firstFullState
    and phaseName ~= nil
    and phaseName ~= "Lobby"
    and phaseName ~= "Rewards"
    and type(player) == "table"
    and player.role ~= "Spectator"    -- ← this hard-excludes Spectators
```

**Change:** Remove the `player.role ~= "Spectator"` guard from `isReconnectSnapshot`. Spectators should be included in the reconnect path so that `PrepareReconnectSnapshot()` runs and the toast fires.

```lua
local isReconnectSnapshot = firstFullState
    and phaseName ~= nil
    and phaseName ~= "Lobby"
    and phaseName ~= "Rewards"
    and type(player) == "table"
```

**Pre-implementation check:** Agent A must verify that `PrepareReconnectSnapshot()` (called at line ~1214 inside `if isReconnectSnapshot`) does not do anything that would break for Spectators — e.g., setting up stamina bars or ghost UI that Spectators don't have. If `PrepareReconnectSnapshot` has side effects that are role-sensitive, add a Spectator guard inside PrepareReconnectSnapshot itself (inspect the function body first).

**Also verify:** The `updateReleaseExperience(state, reconnect)` call that follows — confirm `reconnect = true` reaching it for Spectators doesn't cause issues. Report findings inline.

**Constraints:**
- Ghost players are still handled by the `player.isGhost` branch that fires before the Spectator branch in the reconnect toast block — that ordering is unchanged.
- The existing 0047 Spectator reconnect toast branch (`elseif roleName == "Spectator"`) is already in place — removing the exclusion from `isReconnectSnapshot` is what actually allows that branch to fire.
- Lobby and Rewards exclusions remain.

---

## Agent B — `src/client/UI/GameView.lua`

### B1. Vote candidate list — self-marker for local player's own entry

**Context:** `_updateVote` (approximately lines 3567–3606). The function iterates over `suspects` and creates or updates a button per suspect. Each button uses `Theme.Colors.Danger` (red) for unchosen suspects.

**Target behavior:** When the local player's own key matches a suspect entry, that entry should have a `" (you)"` suffix appended to the display name label — making it visually distinct without changing its interactability or color.

**Implementation:** Within the suspects loop, after reading the suspect key, check if it matches the local participant's key:

```lua
    for _, suspect in suspects do
        if type(suspect) == "table" then
            local key = readString(suspect, "key", "")
            local displayName = readString(suspect, "displayName", "Unknown")
            local isSelf = key == localParticipantKey   -- derive localParticipantKey as shown below
            local labelText = if isSelf then displayName .. " (you)" else displayName
            -- use labelText instead of displayName when setting the button label
        end
    end
```

**Deriving `localParticipantKey`:** Agent B must inspect how `_updateVote` or its parent scope identifies the local player. Look for `localPlayer`, `localKey`, `player.key`, or similar. If the local key is not directly available here, use `game:GetService("Players").LocalPlayer.UserId` to derive it and compare against `readNumber(suspect, "userId", 0)` or whichever field uniquely identifies a suspect.

**Constraints:**
- Only the text label changes — button size, color, click handler, position, and vote confirmation logic are completely unchanged.
- `" (you)"` is appended in lowercase with a leading space — matches the casual style of existing UI copy.
- If the local player's key/userId is not determinable at this call site, Agent B must report this finding rather than inventing a lookup.
- The Spectator who doesn't vote still sees the vote modal (they are observers) — the `" (you)"` label would not appear for them since their own entry is not in the suspects list (Spectators are excluded by the server-side `_suspects()` filter).

---

## Acceptance Criteria

**RoundController — A1 isReconnectSnapshot:**
- [ ] Spectator reconnecting mid-round receives a reconnect toast
- [ ] Toast reads `"Reconnected — Observing — Phase: <phaseName>."` (existing B1 from 0047 branch fires)
- [ ] PrepareReconnectSnapshot runs for Spectators without errors
- [ ] Ghost branch unchanged (fires on `isGhost` before role check)
- [ ] Lobby and Rewards exclusions unchanged (no reconnect toast in those phases for anyone)

**GameView — B1 vote candidate self-marker:**
- [ ] Murderer's own name in the suspect list shows `"<DisplayName> (you)"`
- [ ] Living camper's own entry shows `"<DisplayName> (you)"`
- [ ] All other suspect entries unchanged
- [ ] Button behavior (click, color, confirm) unchanged
- [ ] Spectator (observing, not in suspect list) unaffected

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|------|-------|---------|
| `src/client/Controllers/RoundController.lua` | A | Remove `player.role ~= "Spectator"` from `isReconnectSnapshot`; verify PrepareReconnectSnapshot safety |
| `src/client/UI/GameView.lua` | B | Vote candidate list: append `" (you)"` to local player's own entry label |
