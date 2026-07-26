# Claude_Request-0036 — Personalized Rewards Outcome Text

**Base commit:** 0f8ba52
**Wave:** 1 (single agent, single file)

---

## Preamble — 0035 Review

Request 0035 is accepted as implemented. The monster stamina low notification uses `lastStaminaWasLow == false` (not `~= true`) so nil history does not trigger the toast — the correction is correct. All checks pass.

---

## Mission

When the round ends and the Rewards phase begins, the objective panel (`progressLabel`, `objectiveText`, `objectiveFill`) shows the generic fallback text: "CURRENT MISSION / Follow the phase instructions and stay alert." This text is wrong for the post-round experience. Add a dedicated `elseif phase == "Rewards"` branch that shows a personalized outcome message based on the local player's role and the round winner.

---

## Agent A — `src/client/UI/GameView.lua`

### Context

In `GameView:Update` (line 3875), the objective panel phase chain ends at:

```lua
	elseif phase == "NightTransform" then
		-- ... NightTransform block ...
	else
		self.progressLabel.Text = readString(
			round,
			"resultMessage",
			if readBoolean(round, "isNight", false) then "Stay together. The town is awake." else "Listen for the next briefing."
		)
		self.objectiveText.Text = if phase == "Lobby"
			then "NEXT MYSTERY\nReady up while the camp fills empty seats."
			else "CURRENT MISSION\nFollow the phase instructions and stay alert."
		self.objectiveFill.Size = UDim2.fromScale(0, 1)
	end
```

`player` and `round` are already derived at the top of `Update`:

```lua
local round = if type(state) == "table" and type(state.round) == "table" then state.round else legacyRound
local player = if type(state) == "table" and type(state.player) == "table" then state.player else legacyPlayer
```

`readString` and `readBoolean` are module-level helpers in this file.

### A1. Insert Rewards branch before the fallback `else`

Replace:

```lua
	else
		self.progressLabel.Text = readString(
			round,
			"resultMessage",
			if readBoolean(round, "isNight", false) then "Stay together. The town is awake." else "Listen for the next briefing."
		)
		self.objectiveText.Text = if phase == "Lobby"
			then "NEXT MYSTERY\nReady up while the camp fills empty seats."
			else "CURRENT MISSION\nFollow the phase instructions and stay alert."
		self.objectiveFill.Size = UDim2.fromScale(0, 1)
	end
```

With:

```lua
	elseif phase == "Rewards" then
		local rewardsRole = readString(player, "role", "Spectator")
		local rewardsWinner = readString(round, "winner", "")
		local campersWon = rewardsWinner == "Campers"
		if rewardsRole == "Murderer" then
			if campersWon then
				self.progressLabel.Text = "The camp unmasked you."
				self.objectiveText.Text = "CAUGHT\nThe campers solved the mystery. Better luck next time."
			else
				self.progressLabel.Text = "You escaped into the night."
				self.objectiveText.Text = "ESCAPED\nThe camp never caught you. A flawless hunt."
			end
		elseif rewardsRole ~= "Spectator" then
			if campersWon then
				self.progressLabel.Text = "Justice was served."
				self.objectiveText.Text = "VICTORY\nYou helped catch the monster. The camp is safe."
			else
				self.progressLabel.Text = "The monster escaped."
				self.objectiveText.Text = "DEFEAT\nThe mystery went unsolved. The monster walks free."
			end
		else
			self.progressLabel.Text = if campersWon then "The campers prevailed." else "The monster escaped."
			self.objectiveText.Text = "ROUND OVER\nThe mystery has been resolved."
		end
		self.objectiveFill.Size = UDim2.fromScale(if campersWon then 1 else 0, 1)
	else
		self.progressLabel.Text = readString(
			round,
			"resultMessage",
			if readBoolean(round, "isNight", false) then "Stay together. The town is awake." else "Listen for the next briefing."
		)
		self.objectiveText.Text = if phase == "Lobby"
			then "NEXT MYSTERY\nReady up while the camp fills empty seats."
			else "CURRENT MISSION\nFollow the phase instructions and stay alert."
		self.objectiveFill.Size = UDim2.fromScale(0, 1)
	end
```

**Constraints for Agent A:**
- `rewardsRole` and `rewardsWinner` are used as local names to avoid shadowing the `local role = readString(player, "role", "Spectator")` that follows later in the same function (used for roleIcon display).
- `readString(player, "role", "Spectator")` is nil-safe: if `player` is nil the helper returns the fallback.
- `campersWon = rewardsWinner == "Campers"` — when `winner` is absent or empty, `campersWon` is false and the "monster escaped / defeat" variant shows, which is a safe fallback.
- The `elseif rewardsRole ~= "Spectator"` branch covers all non-Murderer, non-Spectator roles (i.e., Campers and any other role the server might introduce).
- `objectiveFill.Size = UDim2.fromScale(if campersWon then 1 else 0, 1)` — full fill on a camper win (positive outcome visual), empty on monster win.
- The fallback `else` block (covering Lobby, Resolution, and any other unhandled phase) is unchanged.
- No other changes to this file.

---

## Acceptance Criteria

- [ ] When `phase == "Rewards"` and `player.role == "Murderer"` and `round.winner == "Campers"`: progressLabel "The camp unmasked you.", objectiveText "CAUGHT\n..."
- [ ] When `phase == "Rewards"` and `player.role == "Murderer"` and winner is not "Campers": progressLabel "You escaped into the night.", objectiveText "ESCAPED\n..."
- [ ] When `phase == "Rewards"` and `player.role` is a non-Spectator non-Murderer role (e.g. "Camper") and `round.winner == "Campers"`: progressLabel "Justice was served.", objectiveText "VICTORY\n..."
- [ ] When `phase == "Rewards"` and `player.role` is a non-Spectator non-Murderer role and winner is not "Campers": progressLabel "The monster escaped.", objectiveText "DEFEAT\n..."
- [ ] When `phase == "Rewards"` and `player.role == "Spectator"`: progressLabel shows winner-based phrase, objectiveText "ROUND OVER\n..."
- [ ] `objectiveFill.Size` is `UDim2.fromScale(1, 1)` when campers won, `UDim2.fromScale(0, 1)` otherwise
- [ ] Lobby and Resolution phases still show the fallback `else` text unchanged
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/UI/GameView.lua` | A | Personalized Rewards phase outcome text in objective panel |
