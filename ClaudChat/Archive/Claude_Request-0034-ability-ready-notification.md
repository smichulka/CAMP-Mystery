# Claude_Request-0034 — Monster Ability Ready Notification

**Base commit:** de0f4dd
**Wave:** 1 (single agent, single file)

---

## Preamble — 0033 Review

Request 0033 is accepted as implemented. Contextual reconnect orientation fires once per reconnect snapshot for active phases, branching on ghost state then health state. ChatGPT correctly identified and removed a pre-existing duplicate generic toast from Request 0007, so exactly one reconnect notification fires. Test contract updated accordingly. All checks pass.

---

## Mission

The monster player's HUD already shows "ABILITY READY" / "ABILITY COOLING: Xs" continuously during Investigation. But when the ability transitions from cooling to ready, there is no attention-getting toast. The monster must notice the HUD change themselves — easy to miss in a tense chase.

Add a single `Notify` call that fires once on each transition from cooling → ready, giving the monster a clear action cue: **"Ability ready — strike when the moment is right."**

---

## Agent A — `src/client/Controllers/RoundController.lua`

### A1. Add module-level tracker

Near line 84–85 alongside `lastRevealedWitnessCount` and `lastObjectivesCompleted`, add:

```lua
local lastAbilityWasCooling: boolean? = nil
```

### A2. Reset in Stop()

In `RoundController.Stop()`, alongside `lastHealthState = nil` and `lastHealthSeverity = nil`, add:

```lua
lastAbilityWasCooling = nil
```

### A3. Initialize on reconnect

In the reconnect init block (where `lastObjectivesCompleted` is initialized from `reconnectRound`), add immediately after:

```lua
local reconnectMonster = if type(payload) == "table" then (payload :: any).privateMonster else nil
if type(reconnectMonster) == "table" and readBoolean(reconnectMonster, "active", false) then
    local reconnectCooldowns = (reconnectMonster :: any).cooldownEndsAt
    local reconnectLongest = 0
    if type(reconnectCooldowns) == "table" then
        local now = Workspace:GetServerTimeNow()
        for _, endsAt in reconnectCooldowns do
            if type(endsAt) == "number"
                and endsAt == endsAt
                and math.abs(endsAt) < math.huge
            then
                reconnectLongest = math.max(reconnectLongest, endsAt - now)
            end
        end
    end
    lastAbilityWasCooling = reconnectLongest > 0.5
else
    lastAbilityWasCooling = nil
end
```

This initializes `lastAbilityWasCooling` silently on reconnect so the first real snapshot after reconnect does not produce a spurious "ready" toast.

### A4. Detect cooling → ready transition in `updateReleaseExperience`

Immediately after the reconnect orientation block (after its closing `end`) and before `currentEffects:SetGhostTint(isGhost)`, add:

```lua
local abilityMonster = if type(snapshot) == "table"
    then (snapshot :: any).privateMonster
    else nil
if type(abilityMonster) == "table" and readBoolean(abilityMonster, "active", false) then
    local longestRemaining = 0
    local cooldowns = (abilityMonster :: any).cooldownEndsAt
    if type(cooldowns) == "table" then
        local now = Workspace:GetServerTimeNow()
        for _, endsAt in cooldowns do
            if type(endsAt) == "number"
                and endsAt == endsAt
                and math.abs(endsAt) < math.huge
            then
                longestRemaining = math.max(longestRemaining, endsAt - now)
            end
        end
    end
    local abilityCooling = longestRemaining > 0.5
    if lastAbilityWasCooling == true
        and not abilityCooling
        and not reconnect
        and currentView
    then
        currentView:Notify(
            "Ability ready",
            "Your ability is charged. Strike when the moment is right.",
            "Success"
        )
    end
    lastAbilityWasCooling = abilityCooling
else
    lastAbilityWasCooling = nil
end
```

**Constraints for Agent A:**
- `(snapshot :: any).privateMonster` — cast through `any` because `GameState` may not expose `privateMonster` directly; this is the same pattern used in `refresh()` where `local snapshot: any = state` is applied before accessing `privateMonster`.
- The cooldown loop is identical to `GameView:_updateMonsterPanel`'s loop: same NaN guard, same infinity guard, same 0.5-second threshold.
- `lastAbilityWasCooling == true` (strict equality) — prevents a spurious toast when `lastAbilityWasCooling` is `nil` (no cooldown history yet, e.g. first snapshot when monster just spawned with ability already ready).
- `not reconnect` — suppresses the toast on reconnect snapshots so a reconnecting monster does not see a false "now ready" alert.
- `lastAbilityWasCooling = nil` in the `else` branch handles the monster becoming inactive between snapshots — resets the tracker so the next active snapshot does not see a false transition.
- No phase gate is added here — the monster is only `active` during the appropriate phases anyway.
- `Workspace` is already imported at the top of this file (`local Workspace = game:GetService("Workspace")`).
- No other changes to this file.

---

## Acceptance Criteria

- [ ] When `privateMonster.active` is true, `lastAbilityWasCooling` was `true`, and the current `longestRemaining <= 0.5`, a "Ability ready" Success notification fires
- [ ] No toast fires when `lastAbilityWasCooling` is `nil` (first-time ready — no prior cooling observed)
- [ ] No toast fires on reconnect snapshots
- [ ] `lastAbilityWasCooling` is initialized from the reconnect snapshot's `privateMonster.cooldownEndsAt` so the first post-reconnect snapshot does not falsely trigger
- [ ] `lastAbilityWasCooling` is reset to `nil` in `Stop()`
- [ ] When `privateMonster` is absent or inactive, `lastAbilityWasCooling` is set to `nil`
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/Controllers/RoundController.lua` | A | Monster ability cooling → ready transition notification |
