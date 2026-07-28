# Claude_Request-0046 — Keybind Hint Role-Gating + Murderer Phase Hints + Result Modal Role Copy

**Base commit:** (updated after 0045 lands)
**Wave:** 3 (Agent A: GameView.lua; Agent B: RoundController.lua; Agent C: KeybindHints.lua)

---

## Preamble — 0045 Review

Request 0045 is accepted. readBoolean defined; Campfire/Day ghost toast guards applied; stamina nil fix applied; Investigation closing role-differentiated; NightTransform and Lobby panels role-branched. All 83 checks passed.

---

## Mission

Three gaps in two systems:

1. **Keybind hints ignore role** — the hint system fires identically for every player. Ghost players entering Campfire see "E Vote" (they can't vote). Ghost and Spectator players entering Investigation see "Q Role ability" (they have no ability). The Murderer entering MurderPlanning and NightTransform gets no keybind guidance despite those being the most action-dense phases for them.

2. **Result modal has no role copy** — identical title (`"CAMPERS WIN"` / `"MURDERER WINS"`) and body (`round.resultMessage`) are shown to every role. The mission panel already branches by role during Rewards; the modal should too.

---

## Agent B — `src/client/Controllers/RoundController.lua`

### B1. Keybind hint call — filter ghost and Spectator; add Murderer phase gates

**Context:** The hint call block (lines 752–760):

```lua
			if HINT_PHASES[phaseName]
				and not seenHintPhases[phaseName]
				and not reconnect
				and currentView
			then
				seenHintPhases[phaseName] = true
				currentView:ShowKeybindHint(phaseName)
			end
```

`roleName` is already in scope at this point (derived just above this block). `player` is also in scope as `snapshot.player`.

Replace with a version that:
- Skips the hint entirely for ghost players in any phase
- Skips Campfire and Investigation hints for Spectator
- Shows MurderPlanning and NightTransform hints for Murderer only

```lua
			local hintIsGhost = type(player) == "table" and player.isGhost == true
			local hintRole = roleName
			local showHint = HINT_PHASES[phaseName]
				and not seenHintPhases[phaseName]
				and not reconnect
				and currentView
				and not hintIsGhost
				and not (hintRole == "Spectator" and (phaseName == "Campfire" or phaseName == "Investigation"))
			local showMurdererHint = MURDERER_HINT_PHASES[phaseName]
				and not seenHintPhases[phaseName]
				and not reconnect
				and currentView
				and not hintIsGhost
				and hintRole == "Murderer"
			if showHint or showMurdererHint then
				seenHintPhases[phaseName] = true
				currentView:ShowKeybindHint(phaseName)
			end
```

**Also add `MURDERER_HINT_PHASES` table** near `HINT_PHASES` (lines 57–61):

```lua
local MURDERER_HINT_PHASES: { [string]: boolean } = {
	MurderPlanning = true,
	NightTransform = true,
}
```

**Constraints:**
- `hintIsGhost` is local to the hint block; no new module-level variable.
- `hintRole` aliases `roleName` for clarity — no recomputation.
- `seenHintPhases[phaseName] = true` stays inside the combined `if` so each phase is only hinted once per round regardless of which branch triggered it.
- No other code in the file is touched.

---

## Agent C — `src/shared/Config/KeybindHints.lua`

### C1. Add MurderPlanning and NightTransform hint entries

**Context:** Current module (complete):

```lua
local HINTS: { [string]: KeybindHints } = {
    Day = {
        keyboard   = { "E  Interact", "N  Notebook", "Tab  Players", "F  Equip item" },
        controller = { "A  Interact", "Y  Notebook", "View  Players", "X  Equip item" },
    },
    Investigation = {
        keyboard   = { "E  Interact", "N  Notebook", "Q  Role ability", "Tab  Players" },
        controller = { "A  Interact", "Y  Notebook", "LB  Role ability", "View  Players" },
    },
    Campfire = {
        keyboard   = { "E  Vote", "N  Evidence notebook" },
        controller = { "A  Vote", "Y  Evidence notebook" },
    },
}
```

**Pre-implementation step:** Before writing the new entries, read the existing ability and interaction keybinding configuration for the monster player — specifically what keyboard key triggers the monster's ability (it appears to be `Q` based on Investigation hints) and what interaction key is used during MurderPlanning (target selection). Inspect `InputController.lua` or any keybind config to confirm.

Add two new entries matching whatever the real bindings are. Suggested baseline (adjust if the real keys differ):

```lua
    MurderPlanning = {
        keyboard   = { "E  Choose target", "Q  Monster ability", "Tab  Suspects" },
        controller = { "A  Choose target", "LB  Monster ability", "View  Suspects" },
    },
    NightTransform = {
        keyboard   = { "Q  Monster ability", "Tab  Track target" },
        controller = { "LB  Monster ability", "View  Track target" },
    },
```

**Constraints:**
- Match the exact key label format of existing entries (key first, two spaces, action label).
- Only add; do not modify existing entries.
- If the real keybindings differ from the suggested baseline, use the real ones.

---

## Agent A — `src/client/UI/GameView.lua`

### A1. Result modal — role-branched title and body

**Context:** Inside the `if (phase == "Resolution" or phase == "Rewards") and not modalTargetVisible(self.progression) then` block (approximately line 4386), the `if not self.voteRevealOwnsResults then` branch:

```lua
    if not self.voteRevealOwnsResults then
        self.resultTitle.Text = if winner then string.upper(winner .. " WIN") else "MYSTERY RESOLVED"
        self.resultBody.Text = readString(round, "resultMessage", "The night is over—for now.")
    end
```

Replace with role-aware copy. `player` is accessible via the `legacyPlayer` parameter (or however GameView:Update receives it). `readBoolean`, `readString` are in scope.

```lua
    if not self.voteRevealOwnsResults then
        local modalRole = if type(player) == "table" and type(player.role) == "string"
            then player.role
            else ""
        local modalCampersWon = winner == "Campers"
        local modalIsGhost = readBoolean(player, "isGhost", false)
        if modalRole == "Spectator" then
            self.resultTitle.Text = if modalCampersWon then "CAMPERS WIN" else "MURDERER WINS"
            self.resultBody.Text = readString(round, "resultMessage", "The night is over—for now.")
        elseif modalIsGhost then
            self.resultTitle.Text = if modalCampersWon then "JUSTICE" else "UNSOLVED"
            self.resultBody.Text = if modalCampersWon
                then "The murderer was caught. Your death was not in vain."
                else "The murderer escaped. The mystery remains."
        elseif modalRole == "Murderer" then
            self.resultTitle.Text = if modalCampersWon then "CAUGHT" else "ESCAPED"
            self.resultBody.Text = if modalCampersWon
                then "The camp unmasked you. The hunt is over."
                else "The camp never identified you. A flawless hunt."
        else
            self.resultTitle.Text = if modalCampersWon then "VICTORY" else "DEFEAT"
            self.resultBody.Text = if modalCampersWon
                then "Justice was served. The camp is safe."
                else "The murderer escaped. The mystery went unsolved."
        end
    end
```

**Constraints:**
- `winner` is already derived above this block — do not re-derive it.
- `modalRole`, `modalCampersWon`, `modalIsGhost` are all `local` to the `if not self.voteRevealOwnsResults` block.
- The XP/token reward section, `_animateRewards`, and `rewardText` are completely unchanged.
- Branch order: Spectator → ghost → Murderer → living camper.
- The `voteRevealOwnsResults` guard wraps the entire new block exactly as before — no change to when role-branching fires vs when it doesn't.
- No other phases or modal logic touched.

---

## Acceptance Criteria

**RoundController — B1 keybind role-gating:**
- [ ] Ghost player: no keybind hint in any phase (all phases skipped)
- [ ] Spectator entering Campfire: no hint
- [ ] Spectator entering Investigation: no hint
- [ ] Spectator entering Day: hint fires as before (Day is generic, Spectator can interact)
- [ ] Living Murderer entering MurderPlanning: hint fires
- [ ] Living Murderer entering NightTransform: hint fires
- [ ] Living Camper in Day / Investigation / Campfire: hints fire as before

**KeybindHints — C1 new entries:**
- [ ] `KeybindHints["MurderPlanning"]` exists with keyboard and controller arrays
- [ ] `KeybindHints["NightTransform"]` exists with keyboard and controller arrays
- [ ] Existing Day / Investigation / Campfire entries unchanged
- [ ] Key label format matches existing entries

**GameView — A1 result modal:**
- [ ] Murderer (caught): title `"CAUGHT"`, body about unmasking
- [ ] Murderer (escaped): title `"ESCAPED"`, body about flawless hunt
- [ ] Living camper (won): title `"VICTORY"`
- [ ] Living camper (lost): title `"DEFEAT"`
- [ ] Ghost (campers won): title `"JUSTICE"`
- [ ] Ghost (murderer won): title `"UNSOLVED"`
- [ ] Spectator: title matches winner string as before
- [ ] `voteRevealOwnsResults` guard unchanged — when true, no role copy is applied
- [ ] Reward section unchanged

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|------|-------|---------|
| `src/client/Controllers/RoundController.lua` | B | Add `MURDERER_HINT_PHASES` table; role-gate ShowKeybindHint call; Murderer-only path for MurderPlanning/NightTransform |
| `src/shared/Config/KeybindHints.lua` | C | Add MurderPlanning and NightTransform hint entries |
| `src/client/UI/GameView.lua` | A | Result modal role-branched title and body |
