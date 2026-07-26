# Claude_Request-0038 — MurderPlanning "Night Is Falling" Toast for Murderer

**Base commit:** 1f3a73c
**Wave:** 1 (single agent, single file)

---

## Preamble — 0037 Review

Request 0037 is accepted as implemented. ChatGPT noted two narrow placement corrections — `roundNumber` is derived after `lastObjectivesCompleted`, and `reconnectRound` is declared after `lastRoleRevealRound` — both ordering adjustments that preserve the requested behavior. All checks pass.

---

## Mission

When the game transitions from Day to MurderPlanning, the Murderer player receives the phase title card and sees their target in the objective panel (from 0029). There is no Notify toast for this dramatic moment. The Campfire phase has "CAMPFIRE VOTE" entry toast; the role reveal fires on round start; but MurderPlanning — the moment the Murderer gets their target — has nothing.

Add a single entry toast for the Murderer when MurderPlanning begins, showing their target by name.

---

## Agent A — `src/client/Controllers/RoundController.lua`

### Context

In `updateReleaseExperience`, inside the `if phaseName and phaseName ~= lastCinematicPhase then` block, inside the `if currentView then` sub-block, the current structure after `PlayPhaseTitleCard` is:

```lua
			currentView:PlayPhaseTitleCard(phaseName, reconnect)
			if phaseName == "Campfire" and not reconnect then
				-- ... alive count toast ...
				currentView:Notify("CAMPFIRE VOTE", voteMessage, "Warning")
			end
			-- Keybind hint on first entry to key phases (not on reconnect).
			if HINT_PHASES[phaseName]
				and not seenHintPhases[phaseName]
				and not reconnect
				and currentView
			then
				seenHintPhases[phaseName] = true
				currentView:ShowKeybindHint(phaseName)
			end
```

At this point, the following locals are already in scope:
- `phaseName` — current phase string
- `reconnect` — bool
- `roleName` — `readString(player, "role", "Spectator")`
- `participants` — derived from `snapshot.participants` earlier in the function (line ~507)
- `snapshot` — function parameter; `snapshot.murderPlan` is accessible (same pattern used at line ~513 in the participant loop)
- `currentView` — confirmed non-nil (we are inside `if currentView then`)

### A1. Insert MurderPlanning toast after the Campfire block

Immediately after the Campfire `if/end` block (after `currentView:Notify("CAMPFIRE VOTE", ...)`) and before the keybind hint block, add:

```lua
			if phaseName == "MurderPlanning" and not reconnect and roleName == "Murderer" then
				local murdPlan = if type(snapshot) == "table" then snapshot.murderPlan else nil
				local victimId = if type(murdPlan) == "table"
						and type(murdPlan.victimParticipantId) == "string"
						and murdPlan.victimParticipantId ~= ""
					then murdPlan.victimParticipantId
					else nil
				local victimName = "your target"
				if victimId ~= nil then
					for _, p in participants do
						if type(p) == "table" and p.participantId == victimId then
							victimName = readString(p, "displayName", "your target")
							break
						end
					end
				end
				currentView:Notify(
					"Night is falling",
					string.format("You must eliminate %s. Use the shadows.", victimName),
					"Warning"
				)
			end
```

**Constraints for Agent A:**
- Insert inside `if currentView then` — `currentView` is guaranteed non-nil there; do not add a redundant nil check.
- `not reconnect` — phase transitions fire once on first entry; gating on `phaseName ~= lastCinematicPhase` already ensures this fires once per phase entry. The `not reconnect` guard suppresses the toast if the player reconnects while already in MurderPlanning.
- `roleName == "Murderer"` — only the Murderer player sees this. `roleName` is already derived earlier in this `if currentView then` block.
- `snapshot.murderPlan` is accessible without an `any` cast — this is the same field accessed at line ~513 in the participant loop using the pattern `if type(snapshot) == "table" then snapshot.murderPlan else nil`.
- Fallback `victimName = "your target"` — produces "You must eliminate your target. Use the shadows." when the murder plan or participant is absent.
- `participants` is the local derived from `snapshot.participants` earlier in the function (line ~507). Iterate it directly; do not re-derive.
- No new module-level variables, no Stop() changes, no reconnect init changes.
- No other changes to this file.

---

## Acceptance Criteria

- [ ] When the phase transitions to MurderPlanning (first entry, not reconnect) and `player.role == "Murderer"`, a "Night is falling" Warning toast fires with "You must eliminate [Name]. Use the shadows."
- [ ] When `murderPlan.victimParticipantId` is absent or the participant is not found, the toast shows "You must eliminate your target. Use the shadows."
- [ ] No toast fires for non-Murderer players during MurderPlanning
- [ ] No toast fires when reconnecting while already in MurderPlanning (`not reconnect` guard)
- [ ] No toast fires on subsequent MurderPlanning snapshots (already guarded by `phaseName ~= lastCinematicPhase` in the outer block)
- [ ] The Campfire VOTE toast and keybind hints are unchanged
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/Controllers/RoundController.lua` | A | "Night is falling" Warning toast for Murderer on MurderPlanning phase entry |
