# Claude_Request-0041 — Ghost Investigation Fix (Objective Panel + Entry Toast)

**Base commit:** 977066a
**Wave:** 1 (two agents, two files, independent — run in parallel)

---

## Preamble — 0040 Review

Request 0040 is accepted. NightTransform entry toasts inserted cleanly; all placement and variable-scope assumptions were correct. 83/83 checks passed.

---

## Mission

Ghost players during the `Investigation` phase currently have two problems:

1. **`GameView.lua` objective panel bug** — The `Investigation` phase `else` branch (which covers non-Monster, non-Spectator players) has no ghost check. Ghosts fall into this branch and see "NIGHT OBJECTIVE / Collect and post clues: X of Y" — but ghosts cannot collect evidence. They should see observer-appropriate text.

2. **No `RoundController.lua` entry toast for ghosts** — The 0039 Investigation entry toast block explicitly excludes ghosts (`if not playerIsGhost`). When a ghost enters Investigation, they get the phase title card but no contextual toast. Adding an `else` branch gives them a brief orientation.

---

## Agent A — `src/client/Controllers/RoundController.lua`

### Context

The 0039 Investigation block (inside `if phaseName and phaseName ~= lastCinematicPhase then` → `if currentView then`):

```lua
			if phaseName == "Investigation" and not reconnect then
				local playerIsGhost = type(player) == "table" and player.isGhost == true
				if not playerIsGhost then
					if roleName == "Murderer" then
						currentView:Notify("Body discovered", "Stay calm. Blend in with the others.", "Warning")
					elseif roleName ~= "Spectator" then
						currentView:Notify("Body discovered", "Someone was killed. Find the evidence before campfire.", "DangerBright")
					end
				end
			end
```

### A1. Add ghost `else` branch

Replace the `if phaseName == "Investigation" and not reconnect then` block with:

```lua
			if phaseName == "Investigation" and not reconnect then
				local playerIsGhost = type(player) == "table" and player.isGhost == true
				if not playerIsGhost then
					if roleName == "Murderer" then
						currentView:Notify(
							"Body discovered",
							"Stay calm. Blend in with the others.",
							"Warning"
						)
					elseif roleName ~= "Spectator" then
						currentView:Notify(
							"Body discovered",
							"Someone was killed. Find the evidence before campfire.",
							"DangerBright"
						)
					end
				else
					currentView:Notify(
						"Investigation begins",
						"You are a ghost. Watch as the survivors search for the truth.",
						"Info"
					)
				end
			end
```

**Constraints for Agent A:**
- The only change is adding the `else` branch to the existing ghost check.
- The existing `if not playerIsGhost then` structure and all Murderer/Spectator/survivor branches are unchanged.
- Ghost toast fires for all ghost players regardless of their former role (they're all observers now).
- No new module-level variables. No `Stop()` changes. No reconnect init changes.
- No other changes to this file.

---

## Agent B — `src/client/UI/GameView.lua`

### Context

The `Investigation` phase block in `GameView:Update` (approximately lines 3959–4016). The current `else` branch (non-Monster, non-Spectator):

```lua
		else
			self.progressLabel.Text = string.format("Evidence %d/%d - search the abandoned town.", evidenceFound, evidenceGoal)
			self.objectiveText.Text = string.format("NIGHT OBJECTIVE\nCollect and post clues: %d of %d", evidenceFound, evidenceGoal)
			self.objectiveFill.Size = UDim2.fromScale(math.clamp(evidenceFound / evidenceGoal, 0, 1), 1)
			local roundNum = readNumber(round, "roundNumber", 0)
			local isLivingCamper = readString(player, "team", "") == "Campers"
				and readBoolean(player, "alive", false)
				and not readBoolean(player, "isGhost", false)
			if isLivingCamper
				and evidenceFound >= evidenceGoal
				and roundNum > 0
				and self.evidenceNotifiedRound ~= roundNum
			then
				self.evidenceNotifiedRound = roundNum
				self:Notify(
					"Evidence complete",
					"All clues collected. Return for the Campfire.",
					"Success"
				)
			end
		end
```

Note: `isLivingCamper` already gates on `not readBoolean(player, "isGhost", false)`, so the "Evidence complete" notification is already correctly suppressed for ghosts. Only the objective panel **text** is wrong for ghosts.

### B1. Add ghost check at the top of the `else` branch

Replace the `else` block with:

```lua
		else
			local isGhostPlayer = readBoolean(player, "isGhost", false)
			if isGhostPlayer then
				self.progressLabel.Text = string.format(
					"Evidence %d/%d collected by survivors.",
					evidenceFound,
					evidenceGoal
				)
				self.objectiveText.Text = "OBSERVING\nYou are a ghost. Watch as the survivors investigate."
				self.objectiveFill.Size = UDim2.fromScale(math.clamp(evidenceFound / evidenceGoal, 0, 1), 1)
			else
				self.progressLabel.Text = string.format(
					"Evidence %d/%d - search the abandoned town.",
					evidenceFound,
					evidenceGoal
				)
				self.objectiveText.Text = string.format(
					"NIGHT OBJECTIVE\nCollect and post clues: %d of %d",
					evidenceFound,
					evidenceGoal
				)
				self.objectiveFill.Size = UDim2.fromScale(math.clamp(evidenceFound / evidenceGoal, 0, 1), 1)
				local roundNum = readNumber(round, "roundNumber", 0)
				local isLivingCamper = readString(player, "team", "") == "Campers"
					and readBoolean(player, "alive", false)
					and not readBoolean(player, "isGhost", false)
				if isLivingCamper
					and evidenceFound >= evidenceGoal
					and roundNum > 0
					and self.evidenceNotifiedRound ~= roundNum
				then
					self.evidenceNotifiedRound = roundNum
					self:Notify(
						"Evidence complete",
						"All clues collected. Return for the Campfire.",
						"Success"
					)
				end
			end
		end
```

**Constraints for Agent B:**
- `readBoolean(player, "isGhost", false)` is consistent with the existing pattern for reading `isGhost` in this file (the `isLivingCamper` check uses the same helper).
- The `objectiveFill` progress bar shows evidence progress for ghost players too (they can see how far survivors have gotten), matching the fill shown for the Spectator branch above.
- The `isLivingCamper` guard and "Evidence complete" notification logic are moved inside the `else` (alive survivor) branch — their behavior is unchanged; they just don't execute for ghosts.
- All other phases (Day, Campfire, MurderPlanning, NightTransform, Rewards, else/Lobby) are unchanged.
- No new fields, no new Notify calls from GameView in this change.
- No other changes to this file.

---

## Acceptance Criteria

**RoundController (Agent A):**
- [ ] Ghost players entering Investigation (first entry, not reconnect) see: "Investigation begins" / "You are a ghost. Watch as the survivors search for the truth." Info
- [ ] The Murderer toast, survivor toast, and Spectator suppression from 0039 are unchanged
- [ ] Reconnect suppression is unchanged

**GameView (Agent B):**
- [ ] Ghost players in Investigation see progressLabel: "Evidence X/Y collected by survivors."
- [ ] Ghost players in Investigation see objectiveText: "OBSERVING\nYou are a ghost. Watch as the survivors investigate."
- [ ] Alive survivors still see "NIGHT OBJECTIVE / Collect and post clues: X of Y"
- [ ] "Evidence complete" notification still fires only for living campers (unchanged)
- [ ] No other phase's objective panel text is changed

**Shared:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/Controllers/RoundController.lua` | A | Add ghost `else` branch to Investigation entry toast |
| `src/client/UI/GameView.lua` | B | Add ghost check in Investigation `else` branch for correct objective panel text |
