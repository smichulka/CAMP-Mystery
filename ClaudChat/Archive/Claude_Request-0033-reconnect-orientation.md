# Claude_Request-0033 — Reconnect Orientation Notification

**Base commit:** d7de52b
**Wave:** 1 (single agent, single file)

---

## Preamble — 0032 Review

Request 0032 is accepted as implemented. Health state change notifications are wired inside the existing `healthImproved` and `severityDegraded` blocks. All existing visual effects, state tracking, reconnect suppression, and Lobby/Rewards suppression remain unchanged. All checks pass.

---

## Mission

When a player disconnects and reconnects mid-game, they land on an active snapshot with no text orientation. The ghost death cinematic is suppressed on reconnect (`not reconnect` guard), and the health-state and witness/task notifications are also suppressed. The player sees the phase title card replay but gets no message about their current situation — whether they're a ghost, injured, or just picking up from where they left off.

Add a single reconnect orientation `Notify` call that fires once per reconnect snapshot, after all state is derived, giving the player a one-line summary of their current situation.

---

## Agent A — `src/client/Controllers/RoundController.lua`

### Context

In `updateReleaseExperience`, after the health-state update block, the next lines are:

```lua
	if currentSeverity ~= lastHealthSeverity then
		lastHealthSeverity = currentSeverity
	end
	currentEffects:SetGhostTint(isGhost)
```

At this point all required variables are in scope:
- `reconnect` — `local reconnect = isReconnectSnapshot == true` (top of function)
- `phaseName` — derived from `snapshot.round.phaseName` (top of function)
- `roundEnded` — `phaseName == "Rewards" or phaseName == "Lobby"` (earlier in function)
- `isGhost` — `type(player) == "table" and player.isGhost == true` (earlier in function)
- `currentHealthState` — derived above from `player.healthState` (health-state block)
- `currentView` — `local currentView = view` (top of function)

### A1. Insert reconnect orientation block

Immediately after `lastHealthSeverity = currentSeverity` (before `currentEffects:SetGhostTint`), add:

```lua
	if reconnect and currentView and not roundEnded and phaseName ~= nil then
		if isGhost then
			currentView:Notify(
				"Reconnected",
				"You are a ghost. Observe the round and witness the verdict.",
				"Info"
			)
		elseif currentHealthState == "Critical" or currentHealthState == "Incapacitated" then
			currentView:Notify(
				"Reconnected — you're incapacitated",
				string.format("Current phase: %s. You can barely move.", phaseName),
				"Warning"
			)
		elseif currentHealthState == "Injured" then
			currentView:Notify(
				"Reconnected — you're injured",
				string.format("Current phase: %s. Find help.", phaseName),
				"Warning"
			)
		else
			currentView:Notify(
				"Reconnected",
				string.format("Current phase: %s.", phaseName),
				"Info"
			)
		end
	end
```

**Constraints for Agent A:**
- Insert only after `lastHealthSeverity = currentSeverity` — all required variables must already be defined.
- `not roundEnded` suppresses the notification when the player reconnects to Lobby or Rewards (round not active).
- `phaseName ~= nil` prevents a string.format crash if the round table is absent.
- `isGhost` check must come first to correctly orient ghost players regardless of health state.
- Ghost orientation text intentionally mirrors the existing death notification body ("Observe the round and witness the verdict.") because reconnecting ghosts need the same context.
- Do not add any module-level variables, do not change Stop(), do not change the reconnect init block.
- No other changes to this file.

---

## Acceptance Criteria

- [ ] When `reconnect == true`, `phaseName` is an active phase (not Lobby/Rewards), and `isGhost == true`: "Reconnected" / "You are a ghost. Observe the round and witness the verdict." Info notification fires
- [ ] When `reconnect == true`, `phaseName` is active, and `currentHealthState` is "Critical" or "Incapacitated": "Reconnected — you're incapacitated" / "Current phase: X. You can barely move." Warning fires
- [ ] When `reconnect == true`, `phaseName` is active, and `currentHealthState` is "Injured": "Reconnected — you're injured" / "Current phase: X. Find help." Warning fires
- [ ] When `reconnect == true`, `phaseName` is active, and player is healthy/alive: "Reconnected" / "Current phase: X." Info fires
- [ ] No notification fires when `phaseName` is "Lobby" or "Rewards"
- [ ] No notification fires when `reconnect == false`
- [ ] No notification fires when `phaseName == nil`
- [ ] No new module-level variables introduced; Stop() unchanged; reconnect init block unchanged
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/Controllers/RoundController.lua` | A | Add contextual reconnect orientation notification |
