# Claude_Request-0035 — Monster Stamina Low Notification

**Base commit:** 8896fb1
**Wave:** 1 (single agent, single file)

---

## Preamble — 0034 Review

Request 0034 is accepted as implemented. The monster ability ready notification fires on each cooling → ready transition, guarded against nil history, reconnect, and inactive monster state. ChatGPT disclosed a no-op intermediate commit; the actual implementation is in `1fc483f4`. All checks pass.

---

## Mission

The monster player's HUD shows a live stamina bar. When it drops critically low there is no text alert — the monster must notice the bar themselves, which is easy to miss during an active chase. Add a "Stamina low" Warning notification that fires once each time the monster's stamina fraction crosses below 20%, giving the monster a clear cue to disengage before being cornered.

---

## Agent A — `src/client/Controllers/RoundController.lua`

### Context

In `updateReleaseExperience` (function starts ~line 390), the 0034-added ability block ends with:

```lua
	else
		lastAbilityWasCooling = nil
	end
	currentEffects:SetGhostTint(isGhost)
```

`abilityMonster` (which holds `(snapshot :: any).privateMonster`) is a local declared before the ability block and remains in scope after its closing `end`. The stamina block should be inserted immediately after that closing `end` and before `currentEffects:SetGhostTint(isGhost)`.

### A1. Add module-level tracker

Near line 86, alongside `lastAbilityWasCooling`, add:

```lua
local lastStaminaWasLow: boolean? = nil
```

### A2. Reset in Stop()

In `RoundController.Stop()`, alongside `lastAbilityWasCooling = nil`, add:

```lua
lastStaminaWasLow = nil
```

### A3. Initialize on reconnect

In the reconnect init block, `reconnectMonster` is declared at line ~1022 and remains in scope after the cooldown `if/else/end`. Immediately after that block (and before `local reconnectPhase = ...`), add:

```lua
if type(reconnectMonster) == "table"
    and readBoolean(reconnectMonster, "active", false)
then
    local reconnectStamina = readNumber(reconnectMonster, "stamina", 0)
    local reconnectMaxStamina = readNumber(reconnectMonster, "maxStamina", 0)
    lastStaminaWasLow = reconnectMaxStamina > 0
        and (reconnectStamina / reconnectMaxStamina) < 0.2
else
    lastStaminaWasLow = nil
end
```

### A4. Detect stamina crossing low threshold in `updateReleaseExperience`

Immediately after the ability block's closing `end` (after `lastAbilityWasCooling = nil`) and before `currentEffects:SetGhostTint(isGhost)`, add:

```lua
if type(abilityMonster) == "table" and readBoolean(abilityMonster, "active", false) then
    local stamina = readNumber(abilityMonster, "stamina", 0)
    local maxStamina = readNumber(abilityMonster, "maxStamina", 0)
    local staminaIsLow = maxStamina > 0 and (stamina / maxStamina) < 0.2
    if staminaIsLow and lastStaminaWasLow ~= true and not reconnect and currentView then
        currentView:Notify(
            "Stamina low",
            "Disengage and let it recover before striking again.",
            "Warning"
        )
    end
    lastStaminaWasLow = staminaIsLow
else
    lastStaminaWasLow = nil
end
```

**Constraints for Agent A:**
- `abilityMonster` is already the `(snapshot :: any).privateMonster` local from the 0034 block — do not re-derive it. The stamina block reuses the same local.
- `maxStamina > 0` guards against division by zero when `maxStamina` is absent or zero.
- `lastStaminaWasLow ~= true` (not `== false`) — prevents a spurious toast when `lastStaminaWasLow` is `nil` (first snapshot seen for the monster).
- `not reconnect` suppresses the toast on reconnect snapshots.
- `lastStaminaWasLow = staminaIsLow` is set unconditionally so the tracker stays current across all snapshots.
- `lastStaminaWasLow = nil` in the `else` branch resets when the monster is inactive so the next activation does not carry stale state.
- The reconnect init reuses `reconnectMonster` (already declared in the reconnect block from 0034) and adds a second separate `if/else/end` block for stamina, immediately after the cooldown block. It does NOT modify the cooldown block.
- `readNumber` is the existing helper at the top of this file; `readBoolean` likewise.
- No other changes to this file.

---

## Acceptance Criteria

- [ ] When `privateMonster.active` is true and `stamina / maxStamina` drops below 0.2 (from ≥ 0.2), a "Stamina low" Warning notification fires
- [ ] No toast fires when `lastStaminaWasLow` is `nil` (first snapshot — no prior low state observed)
- [ ] No toast fires when stamina is already low in consecutive snapshots (`lastStaminaWasLow == true`)
- [ ] No toast fires on reconnect snapshots
- [ ] `lastStaminaWasLow` is initialized from the reconnect snapshot's `privateMonster.stamina / maxStamina`
- [ ] `lastStaminaWasLow` is reset to `nil` in `Stop()`
- [ ] When `privateMonster` is absent or inactive, `lastStaminaWasLow` is set to `nil`
- [ ] `maxStamina == 0` does not produce a division-by-zero error
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/Controllers/RoundController.lua` | A | Monster stamina drops below 20% → "Stamina low" Warning notification |
