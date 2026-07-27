# Claude_Request-0044 — Resolution Panel + MurderPlanning Observer Branches + NightTransform Ghost Toast

**Base commit:** 46d371e
**Wave:** 2 (Agent A: GameView.lua — two changes; Agent B: RoundController.lua — one change)

---

## Preamble — 0043 Review

Request 0043 is accepted. Day phase objective panel now correctly branches on Spectator → ghost → Murderer → living camper. All 83 checks passed.

---

## Mission

Three gaps remain across two files:

1. **Resolution phase has no dedicated objective-panel block** — it falls through to the `else` catch-all and every role sees `"CURRENT MISSION\nFollow the phase instructions and stay alert."` during the most dramatic moment of the round.
2. **MurderPlanning objective panel collapses Spectator and ghost into the Camper preparation text** — they see `"PREPARATION\nSomething is coming. Secure your equipment and stay alert."` which implies they have a task. They don't.
3. **NightTransform toast has no ghost branch** — ghost players get no notification when the hunt begins. Every other phase with a toast covers ghosts; this one is the only gap.

---

## Agent A — `src/client/UI/GameView.lua`

### A1. MurderPlanning objective panel — add Spectator and ghost branches

**Context:** The `elseif phase == "MurderPlanning"` block (approximately lines 4082–4110). The current branch structure after the victim-name lookup is:

```lua
		if localRole == "Murderer" then
			self.progressLabel.Text = "Plan your attack before night falls."
			self.objectiveText.Text = string.format(
				"MURDERER OBJECTIVE\nEliminate %s. Frame the evidence.",
				victimName
			)
			self.objectiveFill.Size = UDim2.fromScale(1, 1)
		else
			self.progressLabel.Text = "Night is coming. Prepare your tools."
			self.objectiveText.Text = "PREPARATION\nSomething is coming. Secure your equipment and stay alert."
			self.objectiveFill.Size = UDim2.fromScale(0, 1)
		end
```

Replace the single `else` branch with three branches:

```lua
		if localRole == "Murderer" then
			self.progressLabel.Text = "Plan your attack before night falls."
			self.objectiveText.Text = string.format(
				"MURDERER OBJECTIVE\nEliminate %s. Frame the evidence.",
				victimName
			)
			self.objectiveFill.Size = UDim2.fromScale(1, 1)
		elseif readBoolean(player, "isGhost", false) then
			self.progressLabel.Text = "Night is coming."
			self.objectiveText.Text = "OBSERVING\nYou are a ghost. Watch the night unfold."
			self.objectiveFill.Size = UDim2.fromScale(0, 1)
		elseif localRole == "Spectator" then
			self.progressLabel.Text = "Night is coming."
			self.objectiveText.Text = "OBSERVING\nThe night phase is beginning. Watch what unfolds."
			self.objectiveFill.Size = UDim2.fromScale(0, 1)
		else
			self.progressLabel.Text = "Night is coming. Prepare your tools."
			self.objectiveText.Text = "PREPARATION\nSomething is coming. Secure your equipment and stay alert."
			self.objectiveFill.Size = UDim2.fromScale(0, 1)
		end
```

**Constraints:**
- `readBoolean(player, "isGhost", false)` — existing helper, same pattern as Campfire/Day.
- Branch order: Murderer → ghost → Spectator → living camper. A dead Murderer (ghost) takes the ghost branch.
- The Murderer branch (including victim-name lookup) is completely unchanged.
- `localRole` is already derived above the branch in the existing code — do not re-derive it.
- No other phases touched. No new Notify calls.

---

### A2. Resolution phase — add dedicated objective-panel block

**Context:** The main phase `if/elseif` chain in `GameView:Update`. Currently the chain is:

```
if phase == "Day"
elseif phase == "Investigation"
elseif phase == "Campfire"
elseif phase == "MurderPlanning"
elseif phase == "NightTransform"
elseif phase == "Rewards"
else   ← Resolution and Lobby both fall here
```

Insert a new `elseif phase == "Resolution" then` branch **between** `elseif phase == "Rewards"` and `else`. This lifts Resolution out of the generic fallback while leaving the Lobby `else` unchanged.

The new block:

```lua
	elseif phase == "Resolution" then
		local resRole = if type(player) == "table" and type(player.role) == "string"
			then player.role
			else ""
		local resWinner = readString(round, "winner", "")
		local campersWon = resWinner == "Campers"
		local isGhostRes = readBoolean(player, "isGhost", false)
		if resRole == "Spectator" then
			self.progressLabel.Text = if campersWon
				then "Campers prevailed."
				else "The murderer escaped."
			self.objectiveText.Text = "ROUND OVER\nThe mystery has been resolved."
			self.objectiveFill.Size = UDim2.fromScale(if campersWon then 1 else 0, 1)
		elseif isGhostRes then
			self.progressLabel.Text = if campersWon
				then "Justice delivered."
				else "The murderer escaped."
			self.objectiveText.Text = if campersWon
				then "JUSTICE\nThe camp caught the killer. Your death was not in vain."
				else "UNSOLVED\nThe murderer escaped. Your death remains unavenged."
			self.objectiveFill.Size = UDim2.fromScale(if campersWon then 1 else 0, 1)
		elseif resRole == "Murderer" then
			self.progressLabel.Text = if campersWon
				then "The camp unmasked you."
				else "The camp could not name you."
			self.objectiveText.Text = if campersWon
				then "UNMASKED\nThe camp named you. The hunt is over."
				else "UNSEEN\nYour name was never called. You walk free."
			self.objectiveFill.Size = UDim2.fromScale(if campersWon then 0 else 1, 1)
		else
			self.progressLabel.Text = if campersWon
				then "Justice delivered."
				else "The murderer escaped."
			self.objectiveText.Text = if campersWon
				then "NAMED\nThe murderer has been revealed. The camp is safe."
				else "UNSOLVED\nNo verdict reached. The killer walks free."
			self.objectiveFill.Size = UDim2.fromScale(if campersWon then 1 else 0, 1)
		end
```

**Constraints:**
- `readString`, `readBoolean` — existing helpers in scope.
- Branch order: Spectator → ghost → Murderer → living camper (`else`).
- `resRole`, `resWinner`, `campersWon`, `isGhostRes` are all local to this block.
- The Rewards block immediately above and the `else` fallback immediately below are completely unchanged.
- No result modal, no Notify call, no cinematic logic is touched — only the objective panel (progressLabel, objectiveText, objectiveFill).
- No other phases touched.

---

## Agent B — `src/client/Controllers/RoundController.lua`

### B1. NightTransform toast — add ghost branch

**Context:** The `if phaseName == "NightTransform" and not reconnect then` block (approximately lines 728–745). Current structure:

```lua
		if phaseName == "NightTransform" and not reconnect then
			local playerIsGhost = type(player) == "table" and player.isGhost == true
			if not playerIsGhost then
				if roleName == "Murderer" then
					currentView:Notify("Your moment is now", "Strike true. The camp is yours.", "DangerBright")
				elseif roleName ~= "Spectator" then
					currentView:Notify("Night falls", "Stay alert. Someone won't make it to morning.", "Warning")
				end
			end
		end
```

Add an `else` branch for ghost players:

```lua
		if phaseName == "NightTransform" and not reconnect then
			local playerIsGhost = type(player) == "table" and player.isGhost == true
			if not playerIsGhost then
				if roleName == "Murderer" then
					currentView:Notify("Your moment is now", "Strike true. The camp is yours.", "DangerBright")
				elseif roleName ~= "Spectator" then
					currentView:Notify("Night falls", "Stay alert. Someone won't make it to morning.", "Warning")
				end
			else
				currentView:Notify("Night falls", "Watch from beyond. The hunt begins.", "Info")
			end
		end
```

**Constraints:**
- The `playerIsGhost` guard pattern (`type(player) == "table" and player.isGhost == true`) is the established pattern in this file — use it as-is.
- The existing Murderer and living-camper toast copy is unchanged.
- The `else` is the direct complement of `if not playerIsGhost` — no additional condition needed.
- No other phase toast blocks are touched. No new module-level variables.

---

## Acceptance Criteria

**GameView — MurderPlanning:**
- [ ] Ghost during MurderPlanning: `objectiveText` = `"OBSERVING\nYou are a ghost. Watch the night unfold."`
- [ ] Spectator during MurderPlanning: `objectiveText` = `"OBSERVING\nThe night phase is beginning. Watch what unfolds."`
- [ ] Living camper during MurderPlanning: text unchanged (`"PREPARATION\n..."`)
- [ ] Murderer branch (victim name, full bar) completely unchanged

**GameView — Resolution:**
- [ ] Spectator: `objectiveText` = `"ROUND OVER\nThe mystery has been resolved."`; fill reflects `campersWon`
- [ ] Ghost (campers won): `objectiveText` = `"JUSTICE\nThe camp caught the killer. Your death was not in vain."`
- [ ] Ghost (murderer won): `objectiveText` = `"UNSOLVED\nThe murderer escaped. Your death remains unavenged."`
- [ ] Murderer (caught): `objectiveText` = `"UNMASKED\nThe camp named you. The hunt is over."`; fill = 0
- [ ] Murderer (escaped): `objectiveText` = `"UNSEEN\nYour name was never called. You walk free."`; fill = 1
- [ ] Living camper (won): `objectiveText` = `"NAMED\nThe murderer has been revealed. The camp is safe."`; fill = 1
- [ ] Living camper (lost): `objectiveText` = `"UNSOLVED\nNo verdict reached. The killer walks free."`; fill = 0
- [ ] `else` catch-all (Lobby, unknown phases) completely unchanged

**RoundController — NightTransform:**
- [ ] Ghost during NightTransform: toast `"Night falls"` / `"Watch from beyond. The hunt begins."` / `Info`
- [ ] Murderer and living-camper toasts completely unchanged

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|------|-------|---------|
| `src/client/UI/GameView.lua` | A | MurderPlanning: ghost + Spectator branches; Resolution: new dedicated `elseif` block with 4-way branch |
| `src/client/Controllers/RoundController.lua` | B | NightTransform: add `else` ghost toast branch |
