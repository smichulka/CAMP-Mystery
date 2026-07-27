# Claude_Request-0039 — Investigation Phase Entry Toast

**Base commit:** 5466097
**Wave:** 1 (single agent, single file)

---

## Preamble — 0038 Review

Request 0038 is accepted. The MurderPlanning "Night is falling" toast was inserted cleanly at the correct location, all placement assumptions were correct, and all 83 strict Luau checks passed. No corrections required.

---

## Mission

When the game enters the `Investigation` phase — the morning after the murder, when the body has been found — there is no directive toast for anyone. The participant loop already fires "[Name] has been eliminated" (Warning) when the victim's `alive` flag flips, but that happens during `NightTransform`. When `Investigation` begins, players need to know what to DO next, and the Murderer needs the flavor moment of pretending to be shocked.

Add a role-differentiated entry toast on `Investigation` phase entry:

- **Murderer** (alive, not ghost): `"Body discovered"` / `"Stay calm. Blend in with the others."` — `Warning`
- **Survivor** (alive, not ghost, not Spectator, not Murderer): `"Body discovered"` / `"Someone was killed. Find the evidence before campfire."` — `DangerBright`
- **Ghost** or **Spectator**: no toast (they have nothing actionable to do)

---

## Agent A — `src/client/Controllers/RoundController.lua`

### Context

In `updateReleaseExperience`, inside the `if phaseName and phaseName ~= lastCinematicPhase then` block, inside the `if currentView then` sub-block, the current structure is:

```lua
			currentView:PlayPhaseTitleCard(phaseName, reconnect)
			if phaseName == "Campfire" and not reconnect then
				-- ... alive count toast ...
				currentView:Notify("CAMPFIRE VOTE", voteMessage, "Warning")
			end
			if phaseName == "MurderPlanning" and not reconnect and roleName == "Murderer" then
				-- ... victim name lookup ...
				currentView:Notify("Night is falling", ..., "Warning")
			end
			-- Keybind hint on first entry to key phases (not on reconnect).
			if HINT_PHASES[phaseName] and not seenHintPhases[phaseName] and not reconnect and currentView then
				seenHintPhases[phaseName] = true
				currentView:ShowKeybindHint(phaseName)
			end
```

At this insertion point the following locals are already in scope:
- `phaseName` — current phase string
- `reconnect` — bool
- `roleName` — `readString(player, "role", "Spectator")` (derived at the top of `if currentView then`)
- `player` — `snapshot.player` (derived at line ~520, before this block)
- `currentView` — confirmed non-nil (we are inside `if currentView then`)

### A1. Insert Investigation toast after the MurderPlanning block

Immediately after the MurderPlanning `if/end` block and before the keybind hint block, add:

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
				end
			end
```

**Constraints for Agent A:**
- Insert inside `if currentView then` — `currentView` is guaranteed non-nil; do not add a redundant nil check.
- `not reconnect` — suppresses the toast if the player reconnects while already in Investigation.
- Ghost check: `player.isGhost == true` (strict equality) — ghosts have nothing actionable to do; skip their toast entirely.
- Spectator check: `roleName ~= "Spectator"` — spectators also skip.
- `player` is already the `snapshot.player` local derived at line ~520 in this function. Do not re-derive it.
- No new module-level variables. No `Stop()` changes. No reconnect init changes.
- No other changes to this file.
- The keybind hint block immediately after this insertion must remain unchanged.

---

## Acceptance Criteria

- [ ] When the phase transitions to `Investigation` (first entry, not reconnect) and `player.role == "Murderer"` and `player.isGhost ~= true`, a "Body discovered" Warning toast fires with "Stay calm. Blend in with the others."
- [ ] When the phase transitions to `Investigation` (first entry, not reconnect) and `player.role` is a survivor role (not "Murderer", not "Spectator") and `player.isGhost ~= true`, a "Body discovered" DangerBright toast fires with "Someone was killed. Find the evidence before campfire."
- [ ] No toast fires for ghost players during Investigation entry
- [ ] No toast fires for Spectator players during Investigation entry
- [ ] No toast fires when reconnecting while already in Investigation (`not reconnect` guard)
- [ ] No toast fires on subsequent Investigation snapshots (guarded by `phaseName ~= lastCinematicPhase` in the outer block)
- [ ] Campfire VOTE toast, MurderPlanning toast, and keybind hints are unchanged
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/Controllers/RoundController.lua` | A | Role-differentiated "Body discovered" toast on Investigation phase entry |
