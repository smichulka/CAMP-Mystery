# Claude_Request-0052 — Vote Candidate Self-Marker + Campfire Timer Urgency for Murderer

**Base commit:** dd81171
**Wave:** 2 (Agent A: GameView.lua vote candidate self-marker; Agent B: GameView.lua Campfire timer urgency)

---

## Preamble — 0051 Review

Request 0051 is accepted. PlayRoundSummary shows Murderer-specific stat rows (Outcome, Eliminations, Votes Against You, Survivors Remaining); Rewards phase has isGhost branch; RoundSummaryStats type extended with optional Murderer fields. All 83 checks passed.

---

## Mission

Two targeted UX gaps:

1. **Vote candidate list** shows the local player's own name as an orange-red button with no self-indication. The Murderer sees their own name listed as a suspect they can click to vote for themselves (which is a valid game action). There is no "(you)" label or any visual signal to distinguish their own entry from others.

2. **Campfire timer urgency** is uniform for all roles. The investigation phase already has Murderer-specific urgency toast (body-discovered + under-60s warning). The Campfire phase has none — the Murderer watches the same neutral gold → amber → DangerBright countdown as everyone else. They're potentially seconds from being exposed and the timer treats them identically to a curious bystander.

---

## Agent A — `src/client/UI/GameView.lua` (vote candidate self-marker)

### A1. Vote candidate list — "(you)" label on local player's own entry

**Context:** `_updateVote` (approximately lines 3567–3606). The function iterates over `suspects` and creates/updates a button per suspect. Each button uses `Theme.Colors.Danger` (red) for unchosen suspects.

**Pre-implementation step:** Agent A must find how the local player's identity is tracked in this context. Look for:
- `localParticipantKey`, `localKey`, `self.localKey`, or similar on self
- `game:GetService("Players").LocalPlayer.UserId` vs `readNumber(suspect, "userId", 0)`
- Or a `key` field on suspect compared to `player.key` from the round snapshot

Use whatever uniquely identifies the local player's suspect entry.

**Target behavior:** When a suspect entry matches the local player, append `" (you)"` to the displayed name:

```lua
    for _, suspect in suspects do
        if type(suspect) == "table" then
            local key = readString(suspect, "key", "")
            local displayName = readString(suspect, "displayName", "Unknown")
            local isSelf = (key ~= "" and key == localParticipantKey)
            local labelText = if isSelf then displayName .. " (you)" else displayName
            -- use labelText when setting the button's name/display label
        end
    end
```

**Constraints:**
- Only the text label changes. Button size, color (`Theme.Colors.Danger`), click handler, vote confirmation logic, and position are completely unchanged.
- `" (you)"` uses lowercase and a leading space to match the casual register of existing UI copy.
- If the local participant key is not determinable at this call site without a significant plumbing change, Agent A must report the finding and not invent a lookup.
- Spectators do not appear in the suspects list (server-side exclusion in `_suspects()`), so no "(you)" appears for them.

---

## Agent B — `src/client/UI/GameView.lua` (Campfire timer urgency)

### B1. Campfire phase — Murderer-specific pulsing accent on timer

**Context:** The timer color/pulse logic (approximately lines 3915–3923). Current logic:

```lua
    if timeRemaining > 30 then
        timerLabel.TextColor3 = Theme.Colors.Gold
        -- no pulse
    elseif timeRemaining > 10 then
        timerLabel.TextColor3 = Theme.Colors.Amber
        -- no pulse
    else
        timerLabel.TextColor3 = Theme.Colors.DangerBright
        -- pulse
    end
```

This applies identically for all roles in all phases.

**Target behavior:** When `phase == "Campfire"` AND `localRole == "Murderer"`, apply urgency earlier and more aggressively:

```lua
    local isMurdererCampfire = (phase == "Campfire") and (localRole == "Murderer")

    if isMurdererCampfire then
        -- Murderer urgency: amber at 60s (not 30s), danger at 20s (not 10s)
        if timeRemaining > 60 then
            timerLabel.TextColor3 = Theme.Colors.Gold
        elseif timeRemaining > 20 then
            timerLabel.TextColor3 = Theme.Colors.Amber
        else
            timerLabel.TextColor3 = Theme.Colors.DangerBright
            -- same pulse as existing ≤10s logic
        end
    else
        -- existing logic unchanged for all other roles and phases
        if timeRemaining > 30 then
            timerLabel.TextColor3 = Theme.Colors.Gold
        elseif timeRemaining > 10 then
            timerLabel.TextColor3 = Theme.Colors.Amber
        else
            timerLabel.TextColor3 = Theme.Colors.DangerBright
        end
    end
```

**Pre-implementation step:** Agent B must verify:
1. That `phase` and `localRole` (or equivalent) are in scope at this timer update site. If `localRole` is not directly available in the timer path, derive it from the current player snapshot the same way RoundController does.
2. Whether the pulse behavior is triggered by color or by a separate `Pulse`/`Flash` call. If the pulse at ≤10s is triggered separately, the `isMurdererCampfire` branch should trigger that same pulse at ≤20s.

**Constraints:**
- The new logic only activates for `phase == "Campfire"` AND `localRole == "Murderer"`. All other phases and roles use the existing thresholds unchanged.
- Timer position, size, font, and layout are completely unchanged.
- No module-level variable added — `isMurdererCampfire` is local to the timer update block.

---

## Acceptance Criteria

**GameView — A1 vote self-marker:**
- [ ] Murderer's own name in suspects list: `"<DisplayName> (you)"`
- [ ] Living camper's own entry: `"<DisplayName> (you)"`
- [ ] All other suspect entries: unchanged
- [ ] Button color, click handler, vote logic all unchanged

**GameView — B1 Campfire Murderer timer urgency:**
- [ ] Murderer during Campfire: amber color starts at ≤60s (not 30s)
- [ ] Murderer during Campfire: DangerBright starts at ≤20s (not 10s) with pulse
- [ ] All non-Murderer roles during Campfire: timer thresholds unchanged
- [ ] Murderer during all non-Campfire phases: timer thresholds unchanged

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|------|-------|---------|
| `src/client/UI/GameView.lua` | A | Vote candidate list: `" (you)"` label on local player's entry |
| `src/client/UI/GameView.lua` | B | Timer color thresholds: Murderer during Campfire sees urgency 2× earlier |
