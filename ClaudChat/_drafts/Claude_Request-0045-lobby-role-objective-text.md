# Claude_Request-0045 — Lobby Phase Objective Panel Role-Differentiated Copy

**Base commit:** (updated after 0044 lands)
**Wave:** 1 (single agent, single file)

---

## Preamble — 0044 Review

Request 0044 is accepted. Resolution phase now has a dedicated 4-branch objective panel. MurderPlanning has ghost and Spectator observer branches. NightTransform ghost toast added. All 83 checks passed.

---

## Mission

The Lobby phase falls into the `else` catch-all in `GameView:Update`. Every player — Murderer, Camper, Spectator — sees identical text:

- `progressLabel`: reads `round.resultMessage`, falls back to `"Listen for the next briefing."`
- `objectiveText`: `"NEXT MYSTERY\nReady up while the camp fills empty seats."`

A Murderer in the lobby has already been assigned their role and knows they're the killer. Showing them "Ready up while the camp fills empty seats" is a missed immersion beat. Spectators should see observer-appropriate copy.

Extract Lobby into its own `elseif phase == "Lobby"` block and add role differentiation.

---

## Agent A — `src/client/UI/GameView.lua`

### Context

The current `else` branch (approximately lines 4173–4183):

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

### A1. Extract Lobby into its own block and add role branches

Insert a new `elseif phase == "Lobby" then` block **before** the existing `else`. The `else` remains as the catch-all for truly unknown phases — just remove the Lobby ternary from `objectiveText` since Lobby no longer reaches it.

New Lobby block:

```lua
	elseif phase == "Lobby" then
		local lobbyRole = if type(player) == "table" and type(player.role) == "string"
			then player.role
			else ""
		local lobbyResultMessage = readString(
			round,
			"resultMessage",
			"Ready up while the camp fills seats."
		)
		if lobbyRole == "Spectator" then
			self.progressLabel.Text = lobbyResultMessage
			self.objectiveText.Text = "OBSERVING\nYou are watching this round. Wait for it to begin."
			self.objectiveFill.Size = UDim2.fromScale(0, 1)
		elseif lobbyRole == "Murderer" then
			self.progressLabel.Text = lobbyResultMessage
			self.objectiveText.Text = "CHOSEN\nYou have been selected. Your target will be revealed when night falls."
			self.objectiveFill.Size = UDim2.fromScale(0, 1)
		else
			self.progressLabel.Text = lobbyResultMessage
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
- Branch order: Spectator → Murderer → camper (default `else`). No ghost check needed in Lobby — players cannot be ghosts during Lobby.
- `lobbyRole` and `lobbyResultMessage` are `local` inside the Lobby block; they do not affect any other phase.
- The `else` catch-all retains its original `progressLabel` and `objectiveFill` logic verbatim; only the `objectiveText` ternary is simplified (the Lobby case is no longer reachable from `else`).
- No notification calls added. No other phases touched. No new module-level variables.

---

## Acceptance Criteria

- [ ] Murderer during Lobby: `objectiveText` = `"CHOSEN\nYou have been selected. Your target will be revealed when night falls."`
- [ ] Spectator during Lobby: `objectiveText` = `"OBSERVING\nYou are watching this round. Wait for it to begin."`
- [ ] Living camper during Lobby: `objectiveText` = `"NEXT MYSTERY\nReady up while the camp fills empty seats."` (unchanged)
- [ ] Unknown/future phases (`else`): `objectiveText` = `"CURRENT MISSION\nFollow the phase instructions and stay alert."` (Lobby ternary removed, behavior for unknown phases unchanged)
- [ ] `progressLabel` in all Lobby branches reads `round.resultMessage` with the same fallback logic as before
- [ ] No other phase objective panels changed
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/UI/GameView.lua` | A | Extract Lobby into dedicated `elseif` block; add Murderer and Spectator branches; clean up `else` catch-all |
