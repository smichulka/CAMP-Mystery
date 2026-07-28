# Claude_Request-0048 — Cinematic Role-Awareness: Win Reveal + Role Reveal + Round Toast + Monster Panel

**Base commit:** dcc37f3
**Wave:** 2 (Agent A: GameView.lua; Agent B: RoundController.lua)

---

## Preamble — 0047 Review

Request 0047 is accepted. Reconnect toast default branch now has phase/role-aware copy. Vote modal warning label is role-branched. All 83 checks passed.

---

## Mission

Four cinematic and moment-to-moment UX gaps where the Murderer reads third-person or Camper-authored copy:

1. **Monster ability panel** is hidden during NightTransform — the phase where the Murderer is most active. It only appears during Investigation. The `shouldShow` guard needs to include NightTransform.

2. **PlayWinReveal** shows `"MONSTER WIN / The monster escapes into the night."` to everyone including the Murderer, who escaped. The Murderer should see a first-person outcome, not a news headline.

3. **PlayRoleReveal** header is `"YOUR ROLE"` for all players. The Murderer's role reveal is the most dramatic moment in the game; it should feel different from a generic role assignment.

4. **"ROUND X" toast** tells the Murderer `"Stay together."` — Camper advice written about the Murderer's prey. `roleName` (or player role) is readable at this call site.

---

## Agent A — `src/client/UI/GameView.lua`

### A1. Monster panel — show during NightTransform

**Context:** `_updateMonsterPanel`, the `shouldShow` line:

```lua
    local shouldShow = monsterActive and phase == "Investigation"
```

Change to:

```lua
    local shouldShow = monsterActive and (phase == "Investigation" or phase == "NightTransform")
```

**Constraints:** The one-line change only. All content update logic (name label, stamina bar, ability cooldown) is unchanged and already runs whenever `monsterActive` is true regardless of phase.

---

### A2. PlayWinReveal — first-person copy for Murderer

**Context:** `PlayWinReveal(winner: string, isHumanWin: boolean)` (approximately line 5262). Add a third parameter `localRole: string` and branch the title and subtitle for the Murderer.

New signature:

```lua
function GameView:PlayWinReveal(winner: string, isHumanWin: boolean, localRole: string?)
```

Branch the `title.Text` and `subtitle.Text` assignments:

```lua
    local resolvedRole = localRole or ""
    if resolvedRole == "Murderer" then
        if isHumanWin then
            Components.SetLetterspacedText(title, "CAUGHT")
            subtitle.Text = "The camp unmasked you. Your hunt is over."
        else
            Components.SetLetterspacedText(title, "YOU ESCAPED")
            subtitle.Text = "Your identity was never revealed. A flawless hunt."
        end
    else
        -- existing logic unchanged:
        local winnerDisplay = if winner ~= "" then string.upper(winner:sub(1, 48)) else (if isHumanWin then "CAMPERS" else "MONSTER")
        Components.SetLetterspacedText(title, winnerDisplay .. " WIN")
        subtitle.Text = if isHumanWin
            then "The mystery is solved."
            else "The monster escapes into the night."
    end
```

**Constraints:**
- Faction-colored accent strips, sound, auto-dismiss timer, and all other existing logic are unchanged.
- `localRole` is optional (`string?`) so existing internal call sites with two arguments still compile without changes — they receive `nil` and fall into the `else` branch.
- The parameter is appended last; do not reorder existing parameters.

---

### A3. PlayRoleReveal — Murderer-specific header

**Context:** `PlayRoleReveal(roleName, roleDisplayName, roleDescription, isMonster)` (approximately line 5012). The header label at the top of the role card is currently set to `"YOUR ROLE"` unconditionally.

Find the line that sets the header text (the label reading `"YOUR ROLE"`) and branch on `isMonster`:

```lua
    headerLabel.Text = if isMonster then "YOU ARE THE THREAT" else "YOUR ROLE"
```

**Constraints:**
- Only the header label's `Text` changes. Color, font, position, size, background, and all other elements are unchanged.
- `isMonster` is already a parameter — no new parameter needed.
- The role card's colored strip (DangerBright for monster, Gold for camper), role name display, and description text are all unchanged.

---

## Agent B — `src/client/Controllers/RoundController.lua`

### B1. "ROUND X" toast — role-aware copy

**Context:** The round-number toast block (approximately lines 624–635). `player` is in scope but `roleName` may be derived later in the function. Derive the role inline:

```lua
            local roundToastRole = if type(player) == "table" and type(player.role) == "string"
                then player.role
                else ""
            currentView:Notify(
                string.format("ROUND %d", roundNumber),
                if roundToastRole == "Murderer"
                    then "Your identity is hidden. Play the role."
                    else "The mystery begins. Stay together.",
                "Info"
            )
```

**Constraints:**
- `roundToastRole` is local to this block, does not affect the later `roleName` derivation.
- The `phaseName ~= "Lobby" and phaseName ~= "Rewards"` gate and the `lastHintRound` dedup guard are unchanged.
- Severity remains `"Info"` for all roles.

---

### B2. PlayWinReveal call — pass localRole

**Context:** The call to `currentView:PlayWinReveal(...)` (inside the `PlayWinReveal` delegation from the `playVoteReveal` callback or wherever it is called from RoundController). Add `roleName` as the third argument:

```lua
    currentView:PlayWinReveal(winner, isHumanWin, roleName)
```

**Constraints:** `roleName` is in scope at the call site. If there are multiple call sites for `PlayWinReveal`, pass `roleName` at each one.

---

## Acceptance Criteria

**GameView — A1 monster panel:**
- [ ] Murderer/monster panel visible during NightTransform
- [ ] Murderer/monster panel visible during Investigation (unchanged)
- [ ] Panel hidden for all other phases (unchanged)

**GameView — A2 win reveal:**
- [ ] Murderer (monster wins): title `"YOU ESCAPED"`, subtitle `"Your identity was never revealed. A flawless hunt."`
- [ ] Murderer (campers win): title `"CAUGHT"`, subtitle `"The camp unmasked you. Your hunt is over."`
- [ ] Camper/Spectator: title and subtitle unchanged
- [ ] Faction color, sound, timing all unchanged

**GameView — A3 role reveal:**
- [ ] Murderer/monster: header reads `"YOU ARE THE THREAT"`
- [ ] All other roles: header reads `"YOUR ROLE"` (unchanged)

**RoundController — B1 round toast:**
- [ ] Murderer: body = `"Your identity is hidden. Play the role."`
- [ ] All other roles: body = `"The mystery begins. Stay together."` (unchanged)

**RoundController — B2 win reveal call:**
- [ ] `PlayWinReveal` called with three arguments including `roleName`

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|------|-------|---------|
| `src/client/UI/GameView.lua` | A | Monster panel NightTransform visibility; PlayWinReveal localRole param + Murderer copy; PlayRoleReveal Murderer header |
| `src/client/Controllers/RoundController.lua` | B | Round toast role branch; PlayWinReveal call passes roleName |
