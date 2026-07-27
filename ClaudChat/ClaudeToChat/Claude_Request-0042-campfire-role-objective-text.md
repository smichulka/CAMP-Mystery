# Claude_Request-0042 — Campfire Objective Panel Role-Differentiated Copy

**Base commit:** b0f92d5
**Wave:** 1 (single agent, single file)

---

## Preamble — 0041 Review

Request 0041 is accepted. Both files verified at the correct committed blobs. Ghost Investigation fix landed cleanly in both `RoundController.lua` and `GameView.lua`. 83/83 checks passed.

---

## Mission

The `Campfire` phase in `GameView:Update` has only two objective-panel branches — Spectator and everyone else. This means:

- The **Murderer** sees: `"FINAL VOTE\nN players remain. Review your notebook and identify the Murderer."` — They ARE the Murderer. This text is not just ironic; it's actively wrong and breaks immersion.
- **Ghost** players see the same survivor text — but they can't vote. They're observers just like Spectators.

Add Murderer and ghost branches so all four player states have appropriate Campfire copy.

---

## Agent A — `src/client/UI/GameView.lua`

### Context

The `elseif phase == "Campfire" then` block in `GameView:Update` (approximately lines 4017–4049). After the participant alive-count loop and `survivorPhrase` derivation, the current branch structure is:

```lua
		local localRole = if type(player) == "table" and type(player.role) == "string"
			then player.role
			else ""
		if localRole == "Spectator" then
			self.progressLabel.Text = string.format("Votes locked %d/%d - observing.", cast, eligible)
			self.objectiveText.Text = string.format(
				"OBSERVING\n%s. The vote will reveal the verdict.",
				survivorPhrase
			)
		else
			self.progressLabel.Text = string.format("Votes locked %d/%d - accuse carefully.", cast, eligible)
			self.objectiveText.Text = string.format(
				"FINAL VOTE\n%s. Review your notebook and identify the Murderer.",
				survivorPhrase
			)
		end
		self.objectiveFill.Size = UDim2.fromScale(math.clamp(cast / eligible, 0, 1), 1)
```

`readBoolean` is already in scope in this file (used extensively in the nearby branches).

### A1. Replace the two-branch block with a four-branch block

Replace the `if localRole == "Spectator" then ... else ... end` section with:

```lua
		local isGhostPlayer = readBoolean(player, "isGhost", false)
		if localRole == "Spectator" then
			self.progressLabel.Text = string.format("Votes locked %d/%d - observing.", cast, eligible)
			self.objectiveText.Text = string.format(
				"OBSERVING\n%s. The vote will reveal the verdict.",
				survivorPhrase
			)
		elseif isGhostPlayer then
			self.progressLabel.Text = string.format("Votes locked %d/%d - watching.", cast, eligible)
			self.objectiveText.Text = string.format(
				"OBSERVING\n%s. Watch the vote decide the verdict.",
				survivorPhrase
			)
		elseif localRole == "Murderer" then
			self.progressLabel.Text = string.format("Votes locked %d/%d - stay calm.", cast, eligible)
			self.objectiveText.Text = string.format(
				"CAMPFIRE VOTE\n%s. Deflect suspicion. Survive the vote.",
				survivorPhrase
			)
		else
			self.progressLabel.Text = string.format("Votes locked %d/%d - accuse carefully.", cast, eligible)
			self.objectiveText.Text = string.format(
				"FINAL VOTE\n%s. Review your notebook and identify the Murderer.",
				survivorPhrase
			)
		end
		self.objectiveFill.Size = UDim2.fromScale(math.clamp(cast / eligible, 0, 1), 1)
```

**Constraints for Agent A:**
- `readBoolean(player, "isGhost", false)` — use the existing helper, matching the pattern used in the Investigation fix (0041).
- Branch order matters: Spectator → ghost → Murderer → survivor. Ghosts come before Murderer because a Murderer who dies and becomes a ghost should show observing text (they're done).
- The `self.objectiveFill.Size` line after the `end` is unchanged.
- The alive-count loop, `survivorPhrase` derivation, `localRole` derivation, `cast`/`eligible` derivation, and everything above the branch are unchanged.
- No other phases are changed. No new fields or notification calls.
- No other changes to this file.

---

## Acceptance Criteria

- [ ] Spectator during Campfire: `progressLabel` = `"Votes locked X/Y - observing."` / `objectiveText` = `"OBSERVING\nN players remain. The vote will reveal the verdict."` (unchanged from before)
- [ ] Ghost during Campfire: `progressLabel` = `"Votes locked X/Y - watching."` / `objectiveText` = `"OBSERVING\nN players remain. Watch the vote decide the verdict."`
- [ ] Murderer during Campfire: `progressLabel` = `"Votes locked X/Y - stay calm."` / `objectiveText` = `"CAMPFIRE VOTE\nN players remain. Deflect suspicion. Survive the vote."`
- [ ] Alive survivor (Camper) during Campfire: `progressLabel` = `"Votes locked X/Y - accuse carefully."` / `objectiveText` = `"FINAL VOTE\nN players remain. Review your notebook and identify the Murderer."` (unchanged from before)
- [ ] `objectiveFill` progress bar behavior is unchanged for all branches
- [ ] No other phase objective panels are changed
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/UI/GameView.lua` | A | Add Murderer and ghost branches to Campfire objective panel; survivor and Spectator text unchanged |
