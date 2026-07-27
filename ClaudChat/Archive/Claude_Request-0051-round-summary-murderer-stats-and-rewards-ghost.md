# Claude_Request-0051 — Round Summary Murderer Stats + Rewards Ghost Branch

**Base commit:** c96269f
**Wave:** 3 (Agent A: GameView.lua RoundSummaryStats type + PlayRoundSummary display; Agent B: RoundController.lua summary builder; Agent C: GameView.lua Rewards ghost branch)

---

## Preamble — 0050 Review

Request 0050 is accepted. PlayVoteReveal branches on localRole — Murderer sees "EXPOSED" / "YOU SURVIVED THE VOTE"; PlayDeathCinematic accepts deathCause and localRole — Murderer sees "CAUGHT", voted-out camper sees "VOTED OUT", monster-killed camper sees "YOU HAVE FALLEN" (unchanged). All 83 checks passed.

---

## Mission

Two gaps:

1. **PlayRoundSummary** shows four camper-perspective stat rows to every player including the Murderer. The Murderer sees "Camp Tasks X/X" (the tasks they were sabotaging) and "Evidence X/X" (the evidence used to catch them) with no acknowledgment of their own outcome — kills, votes cast against them, or whether they were caught or escaped. The `RoundSummaryStats` type and the builder in RoundController both lack Murderer-private fields entirely.

2. **Rewards phase objective panel** in `GameView:Update` has no `isGhost` branch. Ghost players (dead campers with `isGhost=true`) fall into the living-camper "VICTORY"/"DEFEAT" branch. The Resolution phase already has a correct `"JUSTICE"` / `"UNSOLVED"` ghost branch — Rewards needs the same.

---

## Agent C — `src/client/UI/GameView.lua` (Rewards ghost branch only)

### C1. Rewards phase — add isGhost branch to objective panel

**Context:** The Rewards phase block in `GameView:Update` (approximately lines 4197–4221). Current branch order: Murderer → not Spectator (catches ghosts) → Spectator. The not-Spectator branch uses living-camper "VICTORY"/"DEFEAT" copy for both alive and ghost campers.

Add an `isGhost` check between Murderer and living-camper branches:

```lua
    -- existing: rewardsRole == "Murderer" branch (unchanged)
    elseif rewardsIsGhost then
        -- Ghost camper reaching Rewards
        self.objectiveText.Text = if rewardsCampersWon
            then "JUSTICE\nThe murderer was caught. Your death was not in vain."
            else "UNSOLVED\nThe murderer escaped. The mystery remains."
    elseif rewardsRole ~= "Spectator" then
        -- Living camper
        self.objectiveText.Text = if rewardsCampersWon
            then "VICTORY\nJustice was served. The camp is safe."
            else "DEFEAT\nThe murderer escaped. The mystery went unsolved."
    else
        -- Spectator
        ...
    end
```

**Derive `rewardsIsGhost`:** Use `readBoolean(player, "isGhost", false)` where `player` is the same source used for the Murderer role check above. The variable should be derived inline, scoped to the Rewards block.

**Constraints:**
- `rewardsIsGhost` is a local, not a module-level variable.
- The Murderer branch remains first (a dead Murderer who has `isGhost=true` takes the Murderer branch, not the ghost branch — dead Murderers should still see "CAUGHT"/"ESCAPED").
- All XP/token reward display and `_animateRewards` call are unchanged.
- All other phases' objective panels are unchanged.

---

## Agent B — `src/client/Controllers/RoundController.lua`

### B1. Round summary builder — add Murderer-private fields

**Context:** The `roundSummaryStats` builder (approximately lines 293–353). Currently it reads only camper-facing fields and produces no Murderer-specific data. Agent A (below) needs these three new fields in the stats table passed to `PlayRoundSummary`.

Add the following to the `roundSummaryStats` table before passing it to `currentView:PlayRoundSummary(roundSummaryStats)`:

```lua
    -- Murderer-private stats
    killCount = if roleName == "Murderer"
        then readNumber(round, "murdererKillCount", 0)
        else 0,
    votesAgainstMe = if roleName == "Murderer"
        then readNumber(round, "votesAgainstCulprit", 0)
        else 0,
    wasCaught = if roleName == "Murderer"
        then (winner == "Campers")
        else false,
```

**Pre-implementation:** Agent B must inspect the actual `round` snapshot fields available at this call site. The field names `murdererKillCount` and `votesAgainstCulprit` are suggested names — if the actual snapshot uses different field names, use whatever is real. If neither exists in the snapshot, use 0 for both (do not invent data).

**Constraints:**
- `roleName` and `winner` are already derivable at this call site (check if in scope; derive inline if not).
- `readNumber` is already in scope.
- No other changes to the builder.

---

## Agent A — `src/client/UI/GameView.lua` (PlayRoundSummary)

### A1. RoundSummaryStats type — add Murderer fields

**Context:** The type definition at approximately lines 29–43:

```lua
type RoundSummaryStats = {
    roundNumber: number,
    winner: string,
    isHumanWin: boolean,
    evidenceFound: number,
    evidenceGoal: number,
    objectivesCompleted: number,
    objectiveGoal: number,
    survivorCount: number,
    totalParticipants: number,
    monsterId: string,
    victimName: string,
    personalEvidence: number,
    playerRole: string,
}
```

Add three optional fields:

```lua
    killCount: number?,
    votesAgainstMe: number?,
    wasCaught: boolean?,
```

**Constraints:** Optional fields (`?`) so existing callers without these fields still typecheck.

---

### A2. PlayRoundSummary — Murderer-specific stat rows

**Context:** The stat card build block (approximately lines 5567–5621). It currently always renders four fixed rows:
1. Survivors
2. Evidence
3. Camp Tasks
4. Monster identity (who the monster was)

For the Murderer, replace rows 2–4 with Murderer-relevant data:

```lua
    if stats.playerRole == "Murderer" then
        -- Row 1: outcome (CAUGHT / ESCAPED)
        local outcomeText = if stats.wasCaught then "CAUGHT" else "ESCAPED"
        -- add outcome row

        -- Row 2: kill count
        local killText = string.format("%d", stats.killCount or 0)
        -- add kills row with label "Eliminations"

        -- Row 3: votes cast against them this round
        local votesText = string.format("%d", stats.votesAgainstMe or 0)
        -- add votes row with label "Votes Against You"

        -- Row 4: survivor count (same as everyone else — how many survived their hunt)
        -- reuse existing survivorCount row, label "Survivors Remaining"
    else
        -- existing four rows unchanged for all other roles
    end
```

**Implementation note:** Agent A must inspect the actual stat row rendering mechanism (how it adds a row label + value to the card UI) and replicate it exactly for the Murderer rows. The structure, font, colors, and layout must match existing rows. Do not add new UI elements — only branch which data populates the same row slots.

**Constraints:**
- The Murderer's stat rows replace (not add to) the four default rows — same card size.
- `stats.killCount`, `stats.votesAgainstMe`, `stats.wasCaught` are optional; fall back to 0/false when nil.
- The personal evidence contribution line at line 5605 (`if stats.playerRole ~= "Spectator" and stats.personalEvidence > 0`) is removed from the Murderer branch (Murderer has no personal evidence contribution).
- All animation, motion, fade timing, and the `isRoundSummaryVisible` guard are unchanged.
- Spectator, ghost, and living-camper stat rows are completely unchanged.

---

## Acceptance Criteria

**GameView — C1 Rewards ghost branch:**
- [ ] Ghost camper (campers won): text `"JUSTICE\nThe murderer was caught. Your death was not in vain."`
- [ ] Ghost camper (murderer escaped): text `"UNSOLVED\nThe murderer escaped. The mystery remains."`
- [ ] Living Murderer: unchanged ("CAUGHT"/"ESCAPED")
- [ ] Living camper: unchanged ("VICTORY"/"DEFEAT")
- [ ] Spectator: unchanged

**RoundController — B1 summary builder:**
- [ ] `killCount` field populated (from snapshot or 0)
- [ ] `votesAgainstMe` field populated (from snapshot or 0)
- [ ] `wasCaught` field populated (`winner == "Campers"` when Murderer)
- [ ] Non-Murderer players always receive 0/false for these fields

**GameView — A1 type definition:**
- [ ] `RoundSummaryStats` has optional `killCount`, `votesAgainstMe`, `wasCaught` fields

**GameView — A2 PlayRoundSummary Murderer rows:**
- [ ] Murderer sees: Outcome (CAUGHT/ESCAPED), Eliminations count, Votes Against You count, Survivors Remaining
- [ ] All other roles: stat rows unchanged
- [ ] Row layout, font, colors match existing rows

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|------|-------|---------|
| `src/client/UI/GameView.lua` | A | Add optional fields to RoundSummaryStats type; PlayRoundSummary Murderer stat rows |
| `src/client/Controllers/RoundController.lua` | B | Add killCount, votesAgainstMe, wasCaught to roundSummaryStats builder |
| `src/client/UI/GameView.lua` | C | Rewards phase objective panel isGhost branch |
