# Claude_Request-0040 — NightTransform Phase Entry Toast

**Base commit:** 16d186d
**Wave:** 1 (single agent, single file)

---

## Preamble — 0039 Review

Request 0039 is accepted. Investigation phase entry toast inserted cleanly; all placement assumptions were correct; no pseudocode correction required. 83/83 checks passed.

---

## Mission

After MurderPlanning (murderer gets target and sees "Night is falling"), the game transitions to `NightTransform` — the phase where the actual murder happens. Currently no toast fires for any player during this transition. The murderer has their target but no GO signal. Survivors have no warning that danger is imminent.

Add a role-differentiated entry toast on `NightTransform` phase entry:

- **Murderer** (not ghost): `"Your moment is now"` / `"Strike true. The camp is yours."` — `DangerBright`
- **Survivor** (not ghost, not Spectator, not Murderer): `"Night falls"` / `"Stay alert. Someone won't make it to morning."` — `Warning`
- **Ghost** or **Spectator**: no toast

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
			if phaseName == "MurderPlanning" and not reconnect and roleName == "Murderer" then
				-- ... victim name lookup ...
				currentView:Notify("Night is falling", ..., "Warning")
			end
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

### A1. Insert NightTransform toast after the Investigation block

Immediately after the Investigation `if/end` block and before the keybind hint block, add:

```lua
			if phaseName == "NightTransform" and not reconnect then
				local playerIsGhost = type(player) == "table" and player.isGhost == true
				if not playerIsGhost then
					if roleName == "Murderer" then
						currentView:Notify(
							"Your moment is now",
							"Strike true. The camp is yours.",
							"DangerBright"
						)
					elseif roleName ~= "Spectator" then
						currentView:Notify(
							"Night falls",
							"Stay alert. Someone won't make it to morning.",
							"Warning"
						)
					end
				end
			end
```

**Constraints for Agent A:**
- Insert inside `if currentView then` — `currentView` is guaranteed non-nil; do not add a redundant nil check.
- `not reconnect` — suppresses the toast if the player reconnects while already in NightTransform.
- Ghost check: `player.isGhost == true` (strict equality) — ghosts skip; use the same pattern as the Investigation block directly above.
- Spectator check: `roleName ~= "Spectator"` — spectators skip.
- `player` is the `snapshot.player` local derived at line ~520 in this function. Do not re-derive it.
- No new module-level variables. No `Stop()` changes. No reconnect init changes.
- No other changes to this file.
- The keybind hint block immediately after this insertion must remain unchanged (NightTransform is not in HINT_PHASES and does not gain a keybind hint).

---

## Acceptance Criteria

- [ ] When the phase transitions to `NightTransform` (first entry, not reconnect) and `player.role == "Murderer"` and `player.isGhost ~= true`, a "Your moment is now" DangerBright toast fires with "Strike true. The camp is yours."
- [ ] When the phase transitions to `NightTransform` (first entry, not reconnect) and `player.role` is a survivor role (not "Murderer", not "Spectator") and `player.isGhost ~= true`, a "Night falls" Warning toast fires with "Stay alert. Someone won't make it to morning."
- [ ] No toast fires for ghost players during NightTransform entry
- [ ] No toast fires for Spectator players during NightTransform entry
- [ ] No toast fires when reconnecting while already in NightTransform (`not reconnect` guard)
- [ ] No toast fires on subsequent NightTransform snapshots (guarded by `phaseName ~= lastCinematicPhase` in the outer block)
- [ ] Campfire, MurderPlanning, and Investigation toasts and keybind hints are unchanged
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/Controllers/RoundController.lua` | A | Role-differentiated NightTransform entry toast (Murderer GO signal; survivor danger warning) |
