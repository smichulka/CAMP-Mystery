# Claude_Request-0045 — Bug Fixes + NightTransform Panel + Lobby Panel

**Base commit:** (updated after 0044 lands)
**Wave:** 2 (Agent A: GameView.lua; Agent B: RoundController.lua)

---

## Preamble — 0044 Review

Request 0044 is accepted. Resolution has a dedicated 4-branch objective panel. MurderPlanning has ghost/Spectator observer branches. NightTransform ghost toast added. All 83 checks passed.

---

## Mission

This wave fixes one runtime crash, three ghost/Spectator misrouting bugs in the toast system, and two objective-panel gaps — across both game files.

**RoundController.lua bugs (Agent B):**
1. `readBoolean` is called 4 times but never defined — runtime crash for every Murderer's ability-ready and stamina-low logic.
2. Campfire entry toast fires for ghost and Spectator players who cannot vote ("Cast your vote." is actively wrong for them).
3. Day witness and camp-task toasts fire for ghost players who cannot complete those tasks.
4. Stamina-low toast uses `lastStaminaWasLow == false` — when `lastStaminaWasLow` is `nil` (first tick), the condition fails and the first-ever low-stamina crossing is silently swallowed.
5. Investigation closing has placeholder copy and no role differentiation.

**GameView.lua gaps (Agent A):**
6. NightTransform objective panel collapses ghost and Spectator into the living-camper "NIGHT BEGINS" text.
7. Lobby falls through to the `else` catch-all with no role differentiation.

---

## Agent B — `src/client/Controllers/RoundController.lua`

### B1. Add missing `readBoolean` helper

**Context:** `readString` is defined at line 182 and `readNumber` at line 189. `readBoolean` is called at lines 855, 885, 1133, and 1154 but is not defined anywhere in the file.

Add immediately after the `readNumber` definition (before its first use):

```lua
local function readBoolean(value: any, key: string, fallback: boolean): boolean
    if type(value) == "table" and type(value[key]) == "boolean" then
        return value[key]
    end
    return fallback
end
```

**Constraints:** Place it directly after `readNumber`, before any other code. Signature must exactly match the three-argument pattern used at call sites.

---

### B2. Campfire entry toast — filter ghost and Spectator

**Context:** The Campfire block inside `if phaseName and phaseName ~= lastCinematicPhase then > if currentView then` (approximately line 671). The `currentView:Notify` call fires unconditionally for all roles including ghost and Spectator who cannot vote.

The local `isGhost` (`type(player) == "table" and player.isGhost == true`) and `roleName` are already in scope at this location.

Wrap the `Notify` call inside an additional condition:

```lua
if not isGhost and roleName ~= "Spectator" then
    currentView:Notify("CAMPFIRE VOTE", campPhrase, "Warning")
end
```

Where `campPhrase` is whatever the existing survivor-count string expression evaluates to. **Do not change** how `campPhrase` (or equivalent) is computed — only wrap the Notify call itself.

**Constraints:** The survivor-count computation, `castCount`/`eligibleVoters` derivation, and everything else in the Campfire block above the Notify are unchanged.

---

### B3. Day toasts — add ghost guard

**Context:** Two delta toasts in the Day phase (approximately lines 465–493):
- `"Witness interviewed"` — fires when `revealedWitnessCount > lastRevealedWitnessCount`
- `"Camp task complete"` — fires when `objectivesCompleted > lastObjectivesCompleted`

Both currently fire for ghost players, who cannot complete these tasks.

Add `and not isGhost` to each condition:

**Witness:**
```lua
if revealedWitnessCount > lastRevealedWitnessCount
    and not isGhost
    and not reconnect
    and phaseName == "Day"
    and currentView
then
```

**Camp task:**
```lua
if objectivesCompleted > lastObjectivesCompleted
    and not isGhost
    and not reconnect
    and phaseName == "Day"
    and currentView
then
```

**Constraints:** The `lastRevealedWitnessCount` and `lastObjectivesCompleted` updates immediately below each block are unchanged. The toast copy is unchanged.

---

### B4. Stamina-low toast — fix nil-history guard

**Context:** Approximately line 888:

```lua
if staminaIsLow and lastStaminaWasLow == false and not reconnect and currentView then
```

When `lastStaminaWasLow` is `nil` (game start, first tick), `nil == false` evaluates to `false` in Lua strict equality, silently swallowing the first-ever low-stamina crossing.

Change `== false` to `~= true`:

```lua
if staminaIsLow and lastStaminaWasLow ~= true and not reconnect and currentView then
```

**Constraints:** The `lastStaminaWasLow = staminaIsLow` assignment immediately below is unchanged. No other stamina or ability logic is touched.

---

### B5. Investigation closing — role-differentiated copy and ghost/Spectator filter

**Context:** `updateInvestigationUrgencyWarning(snapshot)` (approximately lines 199–222). Current implementation:

```lua
local function updateInvestigationUrgencyWarning(snapshot: any)
    local round = if type(snapshot) == "table" then snapshot.round else nil
    local phaseName = if type(round) == "table" and type(round.phase) == "string"
        then round.phase
        else nil
    if phaseName ~= "Investigation" then
        sentUrgencyWarning = false
        return
    end
    local currentView = view
    if not currentView or sentUrgencyWarning then
        return
    end
    local phaseEndsAt = readNumber(round, "phaseEndsAt", 0)
    local remaining = phaseEndsAt - Workspace:GetServerTimeNow()
    if remaining > 0 and remaining < 60 then
        sentUrgencyWarning = true
        currentView:Notify(
            "Investigation closing",
            "Under a minute remaining.",
            "Danger"
        )
    end
end
```

Replace with a version that reads player state and branches on role/ghost. Add player derivation after the `round` derivation, then branch the Notify:

```lua
local function updateInvestigationUrgencyWarning(snapshot: any)
    local round = if type(snapshot) == "table" then snapshot.round else nil
    local phaseName = if type(round) == "table" and type(round.phase) == "string"
        then round.phase
        else nil
    if phaseName ~= "Investigation" then
        sentUrgencyWarning = false
        return
    end
    local currentView = view
    if not currentView or sentUrgencyWarning then
        return
    end
    local phaseEndsAt = readNumber(round, "phaseEndsAt", 0)
    local remaining = phaseEndsAt - Workspace:GetServerTimeNow()
    if remaining > 0 and remaining < 60 then
        local urgPlayer = if type(snapshot) == "table" then snapshot.player else nil
        local urgIsGhost = type(urgPlayer) == "table" and urgPlayer.isGhost == true
        local urgRole = if type(urgPlayer) == "table" and type(urgPlayer.role) == "string"
            then urgPlayer.role
            else ""
        if not urgIsGhost and urgRole ~= "Spectator" then
            sentUrgencyWarning = true
            if urgRole == "Murderer" then
                currentView:Notify(
                    "Investigation ending",
                    "The campers are running out of time. Prepare for the vote.",
                    "Success"
                )
            else
                currentView:Notify(
                    "Investigation closing",
                    "Under a minute left. Post your evidence before campfire.",
                    "DangerBright"
                )
            end
        end
    end
end
```

**Constraints:**
- `sentUrgencyWarning = true` must remain inside the `not urgIsGhost and urgRole ~= "Spectator"` block — ghosts and Spectators never set the flag, so if a ghost reconnects during the final minute the flag stays false but that's acceptable.
- The early-return `sentUrgencyWarning = false` reset on non-Investigation phases is unchanged.
- No new module-level variables. `urgPlayer`, `urgIsGhost`, `urgRole` are local to the `if remaining` block.

---

## Agent A — `src/client/UI/GameView.lua`

### A1. NightTransform objective panel — add ghost and Spectator branches

**Context:** The `elseif phase == "NightTransform"` block (approximately lines 4144–4180). The current two-branch structure (`isMonsterPlayer` / `else`) collapses ghost and Spectator into the living-camper "NIGHT BEGINS" text.

`isMonsterPlayer`, `localRole` are already derived. `readBoolean` is already in scope in this file.

Replace the `else` branch with three branches:

```lua
        elseif readBoolean(player, "isGhost", false) then
            self.progressLabel.Text = "Night has fallen."
            self.objectiveText.Text = "OBSERVING\nYou are a ghost. Watch the hunt from beyond."
            self.objectiveFill.Size = UDim2.fromScale(0, 1)
        elseif localRole == "Spectator" then
            self.progressLabel.Text = "Night has fallen."
            self.objectiveText.Text = "OBSERVING\nThe night phase has begun. Watch what unfolds."
            self.objectiveFill.Size = UDim2.fromScale(0, 1)
        else
            self.progressLabel.Text = "The town has appeared. Stay close to your group."
            self.objectiveText.Text = "NIGHT BEGINS\nThe abandoned town has merged with the camp. The monster is somewhere inside."
            self.objectiveFill.Size = UDim2.fromScale(0, 1)
        end
```

**Constraints:**
- The `isMonsterPlayer` branch (with victim-name lookup) is completely unchanged.
- Branch order inside the `else` expansion: ghost → Spectator → living camper. A dead Murderer (ghost) takes the ghost branch.
- No other phases touched.

---

### A2. Lobby — extract into dedicated block with role branches

**Context:** The terminal `else` block (approximately lines 4206–4216). The Lobby case is currently identified only by an inline ternary on `self.objectiveText.Text`.

Insert a new `elseif phase == "Lobby" then` block **between** `elseif phase == "Resolution"` (added in 0044) and the existing `else`. Update the `else` to remove the now-unreachable Lobby ternary.

New Lobby block:

```lua
    elseif phase == "Lobby" then
        local lobbyRole = if type(player) == "table" and type(player.role) == "string"
            then player.role
            else ""
        local lobbyMsg = readString(round, "resultMessage", "Ready up while the camp fills seats.")
        if lobbyRole == "Spectator" then
            self.progressLabel.Text = lobbyMsg
            self.objectiveText.Text = "OBSERVING\nYou are watching this round. Wait for it to begin."
            self.objectiveFill.Size = UDim2.fromScale(0, 1)
        elseif lobbyRole == "Murderer" then
            self.progressLabel.Text = lobbyMsg
            self.objectiveText.Text = "CHOSEN\nYou have been selected. Your target will be revealed when night falls."
            self.objectiveFill.Size = UDim2.fromScale(0, 1)
        else
            self.progressLabel.Text = lobbyMsg
            self.objectiveText.Text = "NEXT MYSTERY\nReady up while the camp fills empty seats."
            self.objectiveFill.Size = UDim2.fromScale(0, 1)
        end
```

Updated `else` catch-all (Lobby ternary removed):

```lua
    else
        self.progressLabel.Text = readString(
            round,
            "resultMessage",
            if readBoolean(round, "isNight", false) then "Stay together. The town is awake." else "Listen for the next briefing."
        )
        self.objectiveText.Text = "CURRENT MISSION\nFollow the phase instructions and stay alert."
        self.objectiveFill.Size = UDim2.fromScale(0, 1)
    end
```

**Constraints:**
- Branch order: Spectator → Murderer → camper (default). No ghost check needed — players cannot be ghosts in Lobby.
- No ghost check in this block.
- `lobbyRole` and `lobbyMsg` are local to the Lobby block.
- The `else` catch-all retains its `progressLabel` and `objectiveFill` verbatim; only the `objectiveText` ternary is simplified (Lobby ternary removed since Lobby no longer reaches `else`).
- No notification calls added. No other phases touched.

---

## Acceptance Criteria

**RoundController — B1 readBoolean:**
- [ ] `readBoolean` is defined as a local function after `readNumber`, matching the same signature used at all four call sites
- [ ] No call site is changed — they work without modification once the function exists

**RoundController — B2 Campfire toast:**
- [ ] Ghost during Campfire phase transition: no "CAMPFIRE VOTE" toast
- [ ] Spectator during Campfire phase transition: no "CAMPFIRE VOTE" toast
- [ ] Living Murderer and living Camper: toast fires as before

**RoundController — B3 Day ghost guard:**
- [ ] Ghost player: no "Witness interviewed" or "Camp task complete" toast during Day
- [ ] Living camper: both toasts fire as before

**RoundController — B4 Stamina nil guard:**
- [ ] First low-stamina crossing from nil (game start): "Stamina low" toast fires
- [ ] Subsequent low→high→low crossing: "Stamina low" fires again as before

**RoundController — B5 Investigation closing:**
- [ ] Ghost: no urgency toast
- [ ] Spectator: no urgency toast
- [ ] Murderer: title `"Investigation ending"` / body about campers running out of time / `Success`
- [ ] Living camper: title `"Investigation closing"` / `"Under a minute left. Post your evidence before campfire."` / `DangerBright`

**GameView — A1 NightTransform panel:**
- [ ] Ghost: `"OBSERVING\nYou are a ghost. Watch the hunt from beyond."`
- [ ] Spectator: `"OBSERVING\nThe night phase has begun. Watch what unfolds."`
- [ ] Living camper: `"NIGHT BEGINS\n..."` unchanged
- [ ] Murderer/monster branch completely unchanged

**GameView — A2 Lobby panel:**
- [ ] Murderer: `"CHOSEN\nYou have been selected. Your target will be revealed when night falls."`
- [ ] Spectator: `"OBSERVING\nYou are watching this round. Wait for it to begin."`
- [ ] Living camper: `"NEXT MYSTERY\nReady up while the camp fills empty seats."` unchanged
- [ ] `else` catch-all `objectiveText` simplified (no Lobby ternary)

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|------|-------|---------|
| `src/client/Controllers/RoundController.lua` | B | Add `readBoolean`; Campfire toast ghost/Spectator filter; Day ghost guard; stamina nil fix; Investigation closing role copy |
| `src/client/UI/GameView.lua` | A | NightTransform panel ghost+Spectator branches; Lobby dedicated block with Murderer/Spectator branches |
