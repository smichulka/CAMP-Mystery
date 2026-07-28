# Claude_Request-0061 — GameView Day/Evidence Complete Notifications + Vote Required Framing Role-Aware

**Base commit:** (updated after 0060 lands)
**Wave:** 2 (Agent A: GameView.lua "Day objectives complete" + "Evidence complete" notifications; Agent B: GameView.lua "Vote required" + "No selectable target" text fixes)

---

## Preamble — 0060 Review

Request 0060 is accepted. PublicMonsterCatalog has `murdererNote` on all 8 monster entries; panel suppresses `counterplay` and shows `murdererNote` for Murderer viewing their own monster. TipCatalog 9 Tier-1 entries have `excludeRoles = {"Murderer"}`; lobby tip cycling skips them when local role is Murderer. All 83 checks passed.

---

## Mission

Four role-naive notification/label surfaces in `GameView.lua` discovered by full-file audit. Three are high-severity framing failures where the Murderer receives Success-tone (green) congratulations for events that are threats to them:

1. **"Day objectives complete"** (lines ~4042–4046) — fires with `"Success"` style when all Day-phase camp tasks are done. For the Murderer, this means campers have finished preparation and investigation is imminent — the worst possible development. They receive a green success pop as their window to remain undetected closes.

2. **"Evidence complete"** (lines ~4117–4121) — fires with `"Success"` style when all evidence clues are collected. This is the moment every clue pointing at the Murderer is now on the board. They receive a green success toast for their own incrimination being complete.

3. **"Vote required"** (line ~1427) — fires when a player tries to close the Campfire vote modal without voting. Body text reads "Choose one suspect before the fire goes out." The word "suspect" frames the reader as an investigator. The Murderer reads this as an instruction to identify their own culprit.

4. **"No selectable target"** (lines ~1833–1837) — body text reads "This action needs another living camper and was not sent." The phrase "another living camper" implies the local player is also a camper. If the Murderer's monster ability fires with no valid target, they read themselves described as a camper.

---

## Agent A — `src/client/UI/GameView.lua` (Day objectives + Evidence complete)

### A1. Pre-implementation inspection

Agent A must read and confirm:

1. Find "Day objectives complete" notification block (~lines 4042–4046). Confirm:
   - Whether `readString(state, "player.role", "")` or `localRole`/`roleName` is already in scope at this exact line.
   - Whether this block has any existing role guard (Ghost, Spectator) above it.
   - The exact `self:Notify(title, body, style)` signature used.

2. Find "Evidence complete" notification block (~lines 4117–4121). Same checks.

3. If `localRole` is not in scope at either site, confirm the nearest way to derive it (e.g., `readString(self._state, "player.role", "")` or `readString(state, "player.role", "")`).

### A2. "Day objectives complete" — Murderer branch

**Current (approximate):**
```lua
self:Notify(
    "Day objectives complete",
    "All camp work done and witnesses interviewed. Investigation begins soon.",
    "Success"
)
```

**Target:**
```lua
if localRole == "Murderer" then
    self:Notify(
        "Day objectives complete",
        "Campers are ready. Investigation begins soon — stay composed.",
        "Warning"
    )
else
    self:Notify(
        "Day objectives complete",
        "All camp work done and witnesses interviewed. Investigation begins soon.",
        "Success"
    )
end
```

**Constraints:**
- If an existing Ghost/Spectator guard surrounds this block, add the Murderer branch inside the `else` path (only living-non-Murderer campers see the Success version).
- Style string `"Warning"` must match casing used elsewhere in this file.
- Body text length for Murderer is comparable to the existing camper body (no new layout changes needed).

### A3. "Evidence complete" — Murderer branch

**Current (approximate):**
```lua
self:Notify(
    "Evidence complete",
    "All clues collected. Return for the Campfire.",
    "Success"
)
```

**Target:**
```lua
if localRole == "Murderer" then
    self:Notify(
        "Evidence complete",
        "All evidence is on the board. Stay composed — the vote decides your fate.",
        "Warning"
    )
else
    self:Notify(
        "Evidence complete",
        "All clues collected. Return for the Campfire.",
        "Success"
    )
end
```

**Constraints:** Same as A2 above. Same `"Warning"` style key, same guard structure.

---

## Agent B — `src/client/UI/GameView.lua` (Vote required + No selectable target)

### B1. Pre-implementation inspection

Agent B must read and confirm:

1. Find "Vote required" block (~line 1427). Confirm:
   - Whether it is inside `_buildVote`, `_updateVote`, or a separate button-callback.
   - Whether `localRole` / `player.role` is accessible at this exact site (it should be accessible via `player` param of `_updateVote` or through `self._state`).
   - Exact `self:Notify(...)` signature.

2. Find "No selectable target" block (~lines 1833–1837). Confirm:
   - What function contains it (likely `_activateRoleAbility` or `_activateMonsterAbility`).
   - Whether `localRole` is accessible — the monster-ability path should already know the Murderer's role.
   - Exact current body text (confirm "another living camper" appears verbatim).

### B2. "Vote required" — Murderer framing

**Current:**
```lua
self:Notify("Vote required", "Choose one suspect before the fire goes out.", "Warning")
```

**Target:**
```lua
local voteBody = if localRole == "Murderer"
    then "Name someone before the fire goes out. Redirect suspicion — every vote matters."
    else "Choose one suspect before the fire goes out."
self:Notify("Vote required", voteBody, "Warning")
```

**Constraints:**
- Style remains `"Warning"` for all roles — only body text changes.
- `localRole` derivation must use whatever pattern is already in scope at this call site.
- If `_updateVote` already reads `localRole` via `player.role`, use the same variable. Do not add a new state read if the variable already exists nearby.

### B3. "No selectable target" — role-neutral body text

**Current:**
```lua
self:Notify(
    "No selectable target",
    "This action needs another living camper and was not sent.",
    "Warning"
)
```

**Target (role-neutral, no role branch needed — just fix the language):**
```lua
self:Notify(
    "No selectable target",
    "This action requires at least one other living player and was not sent.",
    "Warning"
)
```

**Constraints:**
- This is a pure string replacement — no role branch, no new variables. The word "camper" → "player" is the entire change.
- Title, style, and all other behavior unchanged.
- If there are multiple `"No selectable target"` blocks in the file, apply the same string change to all of them.

---

## Acceptance Criteria

**A2 — Day objectives complete:**
- [ ] Murderer: `"Warning"` toast — "Campers are ready. Investigation begins soon — stay composed."
- [ ] Living camper: `"Success"` toast — "All camp work done and witnesses interviewed. Investigation begins soon." (unchanged)
- [ ] Ghost / Spectator: unchanged (existing suppression, if any, preserved)

**A3 — Evidence complete:**
- [ ] Murderer: `"Warning"` toast — "All evidence is on the board. Stay composed — the vote decides your fate."
- [ ] Living camper: `"Success"` toast — "All clues collected. Return for the Campfire." (unchanged)

**B2 — Vote required:**
- [ ] Murderer: "Name someone before the fire goes out. Redirect suspicion — every vote matters."
- [ ] All other roles: "Choose one suspect before the fire goes out." (unchanged)
- [ ] Style `"Warning"` preserved for all roles

**B3 — No selectable target:**
- [ ] Body text reads "This action requires at least one other living player and was not sent." for all roles
- [ ] Title and style unchanged

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|---|---|---|
| `src/client/UI/GameView.lua` | A | "Day objectives complete": Murderer→Warning; "Evidence complete": Murderer→Warning |
| `src/client/UI/GameView.lua` | B | "Vote required": Murderer body text; "No selectable target": "camper"→"player" |
