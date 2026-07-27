# Claude_Request-0043 — Day Phase Objective Panel Role-Differentiated Copy

**Base commit:** 8fe380979eb0c491b80ba8aced775e9da019a973
**Wave:** 1 (single agent, single file)

---

## Preamble — 0042 Review

Request 0042 is accepted. Campfire objective panel now correctly branches on Spectator → Ghost → Murderer → living survivor order. All 83 checks passed; build is 952,010 bytes.

---

## Mission

The `Day` phase in `GameView:Update` shows the same progress label and objective text to every player regardless of role:

```
DAY OBJECTIVE
Camp work: N of M
Interview witnesses: N of M
```

This is wrong for two states:

- The **Murderer** sees "DAY OBJECTIVE" as if they're a camper doing chores. They are the monster. Their Day goal is to blend in — not complete camp work.
- **Spectators** see "DAY OBJECTIVE" as if they have tasks. They're observers.

Add Murderer and Spectator branches, and add a ghost edge-case branch, so all four player states have appropriate Day copy. Living campers (the default) are unchanged.

---

## Agent A — `src/client/UI/GameView.lua`

### Context

The `if phase == "Day" then` block in `GameView:Update` (approximately lines 3929–3958). After the `witnessFound`/`witnessTotal` derivation, the current structure is:

```lua
		self.progressLabel.Text = string.format(
			"Camp work %d/%d  |  Witnesses %d/%d",
			objectiveDone, objectiveGoal, witnessFound, witnessTotal
		)
		self.objectiveText.Text = string.format(
			"DAY OBJECTIVE\nCamp work: %d of %d\nInterview witnesses: %d of %d",
			objectiveDone, objectiveGoal, witnessFound, witnessTotal
		)
		self.objectiveFill.Size = UDim2.fromScale(math.clamp(objectiveDone / objectiveGoal, 0, 1), 1)
		local roundNum = readNumber(round, "roundNumber", 0)
		local isLivingCamper = readString(player, "team", "") == "Campers"
			and readBoolean(player, "alive", false)
			and not readBoolean(player, "isGhost", false)
		if isLivingCamper
			and objectiveDone >= objectiveGoal
			and witnessFound >= witnessTotal
			and roundNum > 0
			and self.dayObjectiveNotifiedRound ~= roundNum
		then
			self.dayObjectiveNotifiedRound = roundNum
			self:Notify(
				"Day objectives complete",
				"All camp work done and witnesses interviewed. Investigation begins soon.",
				"Success"
			)
		end
```

`readBoolean` and `readString` are already in scope.

### A1. Replace the single text-assignment block with four branches

Replace only the `self.progressLabel.Text = ...` through `self.objectiveText.Text = ...` lines (the two `string.format` assignments) with a role-differentiated block. Everything else in the Day block — `objectiveFill.Size`, `roundNum`, `isLivingCamper`, and the notification — remains byte-for-byte unchanged.

The replacement:

```lua
		local localRole = if type(player) == "table" and type(player.role) == "string"
			then player.role
			else ""
		local isGhostPlayer = readBoolean(player, "isGhost", false)
		if localRole == "Spectator" then
			self.progressLabel.Text = string.format(
				"Camp work %d/%d  |  Witnesses %d/%d",
				objectiveDone, objectiveGoal, witnessFound, witnessTotal
			)
			self.objectiveText.Text = string.format(
				"OBSERVING\nCamp work: %d of %d. Witnesses: %d of %d.",
				objectiveDone, objectiveGoal, witnessFound, witnessTotal
			)
		elseif isGhostPlayer then
			self.progressLabel.Text = string.format(
				"Camp work %d/%d  |  Witnesses %d/%d",
				objectiveDone, objectiveGoal, witnessFound, witnessTotal
			)
			self.objectiveText.Text = string.format(
				"OBSERVING\nYou are a ghost. Camp work: %d of %d. Witnesses: %d of %d.",
				objectiveDone, objectiveGoal, witnessFound, witnessTotal
			)
		elseif localRole == "Murderer" then
			self.progressLabel.Text = string.format(
				"Camp work %d/%d  |  Witnesses %d/%d  — blend in.",
				objectiveDone, objectiveGoal, witnessFound, witnessTotal
			)
			self.objectiveText.Text = string.format(
				"DAY COVER\nCamp work: %d of %d. Witnesses: %d of %d. Act natural.",
				objectiveDone, objectiveGoal, witnessFound, witnessTotal
			)
		else
			self.progressLabel.Text = string.format(
				"Camp work %d/%d  |  Witnesses %d/%d",
				objectiveDone, objectiveGoal, witnessFound, witnessTotal
			)
			self.objectiveText.Text = string.format(
				"DAY OBJECTIVE\nCamp work: %d of %d\nInterview witnesses: %d of %d",
				objectiveDone, objectiveGoal, witnessFound, witnessTotal
			)
		end
```

**Constraints for Agent A:**
- Branch order: Spectator → ghost → Murderer → living camper (default `else`).
- `localRole` and `isGhostPlayer` are declared with `local` inside the `if phase == "Day" then` block; they are block-scoped and do not conflict with any other phase.
- `readBoolean(player, "isGhost", false)` — use the existing helper, matching the Investigation and Campfire patterns.
- The `self.objectiveFill.Size` line after the new block is unchanged.
- The `isLivingCamper` derivation, `roundNum`, and the "Day objectives complete" notification block after `objectiveFill` are unchanged.
- No other phases are changed. No new notification calls.
- No other changes to this file.

---

## Acceptance Criteria

- [ ] Spectator during Day: `objectiveText` starts with `"OBSERVING\n"` and shows camp work and witness counts
- [ ] Ghost during Day: `objectiveText` starts with `"OBSERVING\n"` and includes `"You are a ghost."` and shows counts
- [ ] Murderer during Day: `objectiveText` starts with `"DAY COVER\n"` and shows `"Act natural."` copy with counts; `progressLabel` ends with `"— blend in."`
- [ ] Living camper during Day: `objectiveText` starts with `"DAY OBJECTIVE\n"` (unchanged from before); `progressLabel` unchanged
- [ ] `objectiveFill` progress bar behavior unchanged for all branches
- [ ] No other phase objective panels changed
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/UI/GameView.lua` | A | Add Spectator, ghost, and Murderer branches to Day objective panel; living camper text unchanged |
