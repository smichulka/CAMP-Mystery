# Claude_Request-0054 — Monster Ability Panel Per-Ability Cooldowns + PhaseTips Murderer Overrides

**Base commit:** a851580
**Wave:** 2 (Agent A: GameView.lua monster panel per-ability cooldowns; Agent B: PhaseTitles.lua PhaseTips murderer entries + GameView.lua consumer)

---

## Preamble — 0053 Review

Request 0053 is accepted. Server phase announcement banner suppressed for Murderer during MurderPlanning, NightTransform, Investigation — Murderer sees first-person override copy. Evidence discovery ceremony replaced with threat toast for Murderer. All 83 checks passed.

---

## Mission

Two remaining gaps:

1. **Monster ability panel** reduces all ability cooldowns to a single max value and shows either `"ABILITY READY"` or `"ABILITY COOLING: Xs"`. If the Murderer has two abilities where one is ready and one is still cooling, the panel shows "ABILITY COOLING" with no indication that one ability is already usable. Named, per-ability rows would be far more actionable.

2. **PhaseTips** (the tip text shown in the lobby cycling ticker and phase tip overlays) includes a MurderPlanning entry written from the camper's perspective: `"Stay calm and move with purpose. The monster is choosing its plan."` The Murderer reads a third-person description of their own actions. The `PhaseTitlesMurderer` config table (added in 0049) should be extended with a `PhaseTipsMurderer` sibling if not already present — if 0049 already added it, verify the lobby tip cycling path actually uses it.

---

## Agent A — `src/client/UI/GameView.lua` (monster ability panel per-ability display)

### A1. `_updateMonsterPanel` — per-ability cooldown rows

**Context:** `_updateMonsterPanel` (approximately lines 3812–3837). Current behavior:

```lua
    local longestRemaining = 0
    for _, endsAt in cooldownEndsAt do
        longestRemaining = math.max(longestRemaining, endsAt - currentTime)
    end
    if longestRemaining > 0.5 then
        monsterAbilityLabel.Text = string.format("ABILITY COOLING: %ds", math.ceil(longestRemaining))
    else
        monsterAbilityLabel.Text = "ABILITY READY"
    end
```

**Pre-implementation step (critical):** Agent A must inspect:
1. The shape of `cooldownEndsAt` — is it a plain list of timestamps, or a table keyed by ability name/ID? If it's a keyed table, ability names are available for display.
2. Whether there are any ability name constants or config (e.g., `MonsterAbilities.lua` or similar) that provide human-readable names.
3. Whether `monsterAbilityLabel` is a single TextLabel or a container. If it's a single label, per-ability rows require either multi-line text or the parent frame must accommodate additional child labels.

**If `cooldownEndsAt` is keyed by ability name** (most flexible case):

Replace the single-label display with per-ability rows. For each ability:
- If cooldown remaining ≤ 0.5s: show `"<AbilityName>  READY"` in Gold
- If cooling: show `"<AbilityName>  Xs"` in Amber

If the panel has room for multiple rows, create one label per ability. If the panel is a single-label TextLabel, build a newline-separated string:

```lua
    local lines = {}
    for abilityName, endsAt in cooldownEndsAt do
        local remaining = endsAt - currentTime
        if remaining > 0.5 then
            table.insert(lines, string.format("%s  %ds", string.upper(abilityName), math.ceil(remaining)))
        else
            table.insert(lines, string.format("%s  READY", string.upper(abilityName)))
        end
    end
    monsterAbilityLabel.Text = table.concat(lines, "\n")
```

**If `cooldownEndsAt` is a plain list** (no names available): Keep the existing single-label display but improve it — show both the longest cooldown AND a "1 READY" / "ALL READY" / "ALL COOLING" status:

```lua
    local readyCount = 0
    local longestRemaining = 0
    for _, endsAt in cooldownEndsAt do
        local remaining = endsAt - currentTime
        if remaining <= 0.5 then
            readyCount += 1
        else
            longestRemaining = math.max(longestRemaining, remaining)
        end
    end
    local total = #cooldownEndsAt  -- or table length
    if readyCount == total then
        monsterAbilityLabel.Text = "ALL ABILITIES READY"
    elseif readyCount > 0 then
        monsterAbilityLabel.Text = string.format("%d READY  |  COOLING: %ds", readyCount, math.ceil(longestRemaining))
    else
        monsterAbilityLabel.Text = string.format("COOLING: %ds", math.ceil(longestRemaining))
    end
```

**Constraints:**
- Agent A must choose the appropriate path based on what they find. Report the data structure in the implementation notes.
- Panel size, position, `shouldShow` logic, and all other content (name label, stamina bar) are completely unchanged.
- If adding multi-line text causes layout overflow, Agent A must constrain to what fits within the existing label bounds.

---

## Agent B — `src/shared/Config/PhaseTitles.lua` + `src/client/UI/GameView.lua`

### B1. PhaseTips Murderer entry verification and lobby cycling fix

**Context:** `PhaseTitles.lua` was updated in 0049 to add `PhaseTitlesMurderer` and `PhaseTipsMurderer`. The current MurderPlanning default tip:

```lua
PhaseTips = {
    MurderPlanning = "Stay calm and move with purpose. The monster is choosing its plan.",
    ...
}
```

The Murderer sees this when the lobby tip cycles to MurderPlanning, which reads as third-person observer copy.

**Pre-implementation step:** Verify:
1. Whether `PhaseTipsMurderer.MurderPlanning` already exists from 0049 (it was in the spec). If yes, verify its value is `"Study your target now. Your window is short."`.
2. Find the lobby tip cycling path in GameView.lua (search for `lobbyTipIndex` or the tip label update). Does it read from `PhaseTipsMurderer` when the local role is Murderer, or does it only read from the default `PhaseTips` table?
3. Find any other path where `PhaseTips[phaseName]` is read (besides `PlayPhaseTitleCard` which was updated in 0049).

**If `PhaseTipsMurderer` is already in the config but the lobby cycling path doesn't use it:**

In the lobby tip cycling function (wherever it reads `PhaseTips[currentTipPhase]`), add a role check:

```lua
    local tipRole = if type(localRole) == "string" then localRole else ""
    local tipText = if tipRole == "Murderer" and PhaseTipsMurderer[currentTipPhase]
        then PhaseTipsMurderer[currentTipPhase]
        else PhaseTips[currentTipPhase]
    tipLabel.Text = tipText
```

**If `PhaseTipsMurderer` is missing from the config:**

Add it to `PhaseTitles.lua` (it may have been omitted from the 0049 implementation). The entries needed:

```lua
local PhaseTipsMurderer = {
    MurderPlanning = "Study your target now. Your window is short.",
    NightTransform = "Your ability is your greatest weapon. Use it wisely.",
}
```

**Constraints:**
- `PlayPhaseTitleCard` already reads from `PhaseTipsMurderer` (updated in 0049) — do not change it again.
- Only the lobby tip cycling path is the target if that's the gap.
- If lobby tips don't cycle by phase name (only show generic tips), report this finding and skip B1.
- All non-Murderer tip consumers see the default `PhaseTips` table (unchanged).

---

## Acceptance Criteria

**GameView — A1 monster panel:**
- [ ] If abilities are named: each ability shows its name + "READY" or cooldown seconds
- [ ] If abilities are unnamed: shows ready count vs cooling, not just max-cooling
- [ ] Panel visibility (NightTransform + Investigation) unchanged
- [ ] Stamina bar and name label unchanged

**PhaseTitles + GameView — B1 lobby tips:**
- [ ] `PhaseTipsMurderer.MurderPlanning` exists: `"Study your target now. Your window is short."`
- [ ] `PhaseTipsMurderer.NightTransform` exists: `"Your ability is your greatest weapon. Use it wisely."`
- [ ] Lobby tip cycling uses Murderer-specific tip when local role is Murderer and tip phase matches
- [ ] All non-Murderer tip cycling unchanged

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|------|-------|---------|
| `src/client/UI/GameView.lua` | A | `_updateMonsterPanel`: per-ability or ready-count display instead of max-cooldown |
| `src/shared/Config/PhaseTitles.lua` | B | Verify/add `PhaseTipsMurderer`; add MurderPlanning + NightTransform entries |
| `src/client/UI/GameView.lua` | B | Lobby tip cycling: use `PhaseTipsMurderer` when local role is Murderer |
