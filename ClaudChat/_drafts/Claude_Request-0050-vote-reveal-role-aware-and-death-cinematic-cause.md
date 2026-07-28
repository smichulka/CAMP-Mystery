# Claude_Request-0050 — Vote Reveal Role-Awareness + Death Cinematic Cause Differentiation

**Base commit:** a9ad403
**Wave:** 3 (Agent A: GameView.lua PlayVoteReveal; Agent B: GameView.lua PlayDeathCinematic; Agent C: RoundController.lua call sites)

---

## Preamble — 0049 Review

Request 0049 is accepted. PhaseTitlesMurderer and PhaseTipsMurderer tables added; PlayPhaseTitleCard accepts localRole; Murderer entering MurderPlanning sees "YOUR PREY IS CHOSEN / Strike before dawn." and NightTransform sees "YOU ARE THE MONSTER NOW / The hunt begins. Move in shadow." All 83 checks passed.

---

## Mission

Two high-priority role-naive screens remain:

1. **PlayVoteReveal** has no role parameter. When the Campfire vote resolves and the "CULPRIT FOUND / MONSTER ESCAPES" result fires, the Murderer reads a third-person news headline about themselves: `"THE CULPRIT IS FOUND — [Their own name] was the Murderer."` They are reading their own arrest report. This is the most emotionally charged reveal in the game and needs first-person copy for the Murderer.

2. **PlayDeathCinematic** always shows `"YOU HAVE FALLEN / Your spirit remains — watch over the living."` regardless of how or when the player died. Being eliminated by a monster kill during NightTransform is a very different experience from being voted out at Campfire by your fellow campers. The Murderer being caught at Campfire sees the same "spirit watching over the living" message as their victim. There is no cause parameter at all — fix this.

---

## Agent C — `src/client/Controllers/RoundController.lua`

### C1. PlayVoteReveal call — pass localRole

**Context:** Find the call to `currentView:PlayVoteReveal(...)` in RoundController. Add `roleName` as an additional argument:

```lua
    currentView:PlayVoteReveal(voteData, roleName)
```

Or if the function receives individual fields rather than a data table, append `roleName` as the last argument. Use whatever the actual call site looks like — inspect the file first.

**Constraints:** `roleName` is in scope at this call site. If `PlayVoteReveal` is called from multiple places, pass `roleName` at each. The new argument is appended last.

---

### C2. PlayDeathCinematic call — pass deathCause

**Context:** The call site is at approximately line 813:

```lua
    if isGhost and not lastIsGhost then
        currentView:PlayDeathCinematic()
    end
```

The current code has no context about WHY the player died. Derive the cause from the current phase at the moment of death:

```lua
    if isGhost and not lastIsGhost then
        local deathCause = if phaseName == "Campfire" or phaseName == "Resolution"
            then "voted"
            else "killed"
        currentView:PlayDeathCinematic(deathCause, roleName)
    end
```

**Constraints:**
- `phaseName` and `roleName` are in scope at this call site (they are derived earlier in the same update function). Verify they are not nil before using — use empty string fallback if needed.
- `deathCause` is a local string: `"voted"` (Campfire/Resolution) or `"killed"` (any other phase, default for unknown).
- No other logic at this call site changes.

---

## Agent A — `src/client/UI/GameView.lua` (PlayVoteReveal)

### A1. PlayVoteReveal — add localRole parameter and branch Murderer copy

**Context:** `PlayVoteReveal(voteData, ...)` (approximately line 4863). The function sets the result title/body at two key moments:

**Moment 1 — interim counting phase** (approximately line 4880):
```lua
    resultTitle.Text = "COUNTING THE VOTES"
    resultBody.Text = ""
```
This is acceptable as-is — leave it unchanged.

**Moment 2 — final result reveal** (approximately lines 4969–4979):
```lua
    if majorityCorrect then
        resultTitle.Text = "THE CULPRIT IS FOUND"
        resultBody.Text = culpritName .. " was the " .. safeMonsterId
    else
        resultTitle.Text = "THE MONSTER ESCAPES"
        resultBody.Text = safeMonsterId .. " was never caught"
    end
```

**New signature:**
```lua
function GameView:PlayVoteReveal(voteData, localRole: string?)
```
(or append after whatever existing parameters are already present)

**Branch the final result:**
```lua
    local resolvedVoteRole = localRole or ""
    if resolvedVoteRole == "Murderer" then
        if majorityCorrect then
            -- Murderer was caught
            resultTitle.Text = "EXPOSED"
            resultBody.Text = "The camp unmasked you. The hunt is over."
        else
            -- Murderer survived the vote
            resultTitle.Text = "YOU SURVIVED THE VOTE"
            resultBody.Text = "The camp guessed wrong. You remain hidden."
        end
    else
        -- original copy for all other roles
        if majorityCorrect then
            resultTitle.Text = "THE CULPRIT IS FOUND"
            resultBody.Text = culpritName .. " was the " .. safeMonsterId
        else
            resultTitle.Text = "THE MONSTER ESCAPES"
            resultBody.Text = safeMonsterId .. " was never caught"
        end
    end
```

**Constraints:**
- `localRole` is optional (`string?`) — existing two-arg or single-arg call sites still compile.
- `resolvedVoteRole` is local to the final-reveal block.
- The vote animation sequence, faction color strips, sound, auto-dismiss timer, and all other visual logic are completely unchanged.
- `voteRevealOwnsResults` guard (if present in this function) is unchanged — only the title/body text is branched.
- Only the final-result moment is branched; interim "COUNTING" text is unchanged.

---

## Agent B — `src/client/UI/GameView.lua` (PlayDeathCinematic)

### B1. PlayDeathCinematic — accept deathCause and localRole; branch copy

**Context:** `GameView:PlayDeathCinematic()` at approximately line 5702. Current behavior:

```lua
    heading.Text = "YOU HAVE FALLEN"
    sub.Text = "Your spirit remains — watch over the living."
```

**New signature:**
```lua
function GameView:PlayDeathCinematic(deathCause: string?, localRole: string?)
```

Both parameters are optional so the zero-argument internal call (if it exists) still compiles.

**Branch the copy:**
```lua
    local cause = deathCause or "killed"
    local dRole = localRole or ""

    if dRole == "Murderer" then
        -- The Murderer was caught/voted out (they can only die via Campfire vote)
        heading.Text = "CAUGHT"
        sub.Text = "The camp saw through you. Your hunt is over."
    elseif cause == "voted" then
        -- Living camper voted out at Campfire
        heading.Text = "VOTED OUT"
        sub.Text = "The camp made their choice. Watch over the living."
    else
        -- Living camper killed by monster during NightTransform or similar
        heading.Text = "YOU HAVE FALLEN"
        sub.Text = "Your spirit remains — watch over the living."
    end
```

**Constraints:**
- All animation, motion, fade timing, ghost-state setup, and any other visual logic after the heading/sub assignment are completely unchanged.
- `deathCause` and `localRole` are both `string?` — the function still works if called with zero arguments (existing callers that haven't been updated yet get default values and see the original copy).
- The `if self.destroyed` guard at the top of the function is unchanged.

---

## Acceptance Criteria

**RoundController — C1 PlayVoteReveal call:**
- [ ] `PlayVoteReveal` called with `roleName` as additional argument

**RoundController — C2 PlayDeathCinematic call:**
- [ ] `PlayDeathCinematic` called with `deathCause` and `roleName`
- [ ] `deathCause` is `"voted"` when `phaseName` is `"Campfire"` or `"Resolution"`
- [ ] `deathCause` is `"killed"` for all other phases

**GameView — A1 PlayVoteReveal role-branching:**
- [ ] Murderer (majority voted correct, Murderer caught): title `"EXPOSED"`, body about being unmasked
- [ ] Murderer (majority voted wrong, Murderer survived): title `"YOU SURVIVED THE VOTE"`, body about remaining hidden
- [ ] All other roles (correct vote): title `"THE CULPRIT IS FOUND"`, body unchanged
- [ ] All other roles (wrong vote): title `"THE MONSTER ESCAPES"`, body unchanged
- [ ] Interim "COUNTING THE VOTES" state unchanged for all roles
- [ ] Animation, color, timing all unchanged

**GameView — B1 PlayDeathCinematic cause-branching:**
- [ ] Murderer dying (any cause): title `"CAUGHT"`, sub about hunt ending
- [ ] Non-Murderer voted out (deathCause == "voted"): title `"VOTED OUT"`, sub unchanged
- [ ] Non-Murderer monster-killed (deathCause == "killed"): title `"YOU HAVE FALLEN"`, sub unchanged (original copy)
- [ ] Zero-argument call (no deathCause, no localRole): defaults to "killed" / non-Murderer path → original copy

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|------|-------|---------|
| `src/client/Controllers/RoundController.lua` | C | Pass `roleName` to `PlayVoteReveal`; pass `deathCause` + `roleName` to `PlayDeathCinematic` |
| `src/client/UI/GameView.lua` | A | `PlayVoteReveal` accepts `localRole`; branch final-result title/body for Murderer |
| `src/client/UI/GameView.lua` | B | `PlayDeathCinematic` accepts `deathCause` + `localRole`; branch heading/sub by cause and role |
