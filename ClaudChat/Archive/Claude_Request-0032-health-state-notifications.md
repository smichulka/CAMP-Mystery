# Claude_Request-0032 — Health State Change Notifications

**Base commit:** ec8603d
**Wave:** 1 (single agent, single file)

---

## Preamble — 0031 Review

Request 0031 is accepted as implemented. `RoundController.lua` tracks `round.objectivesCompleted` and fires a Day-only Info notification per increment. `GameView.lua` resolves the murder-plan victim during NightTransform and shows the target name in the monster objective text. All checks pass.

---

## Mission

When a player's health state degrades (Healthy → Injured, or anything → Incapacitated/Critical), the game already fires a visual impact flash and optional screen shake. No text notification tells the player what happened. Similarly, when a player's health improves back to Healthy, `ShowHealedEffect()` plays visually but no text confirms recovery. Add matching `currentView:Notify()` calls to both events so players get clear text feedback alongside the existing visuals.

---

## Agent A — `src/client/Controllers/RoundController.lua`

### Context

In `updateReleaseExperience` (starts line 390), `currentView` is declared at line 400 as `local currentView = view`.

The health state block (lines ~702–733) currently reads:

```lua
local healthImproved = currentHealthState == "Healthy"
    and lastHealthState ~= nil
    and lastHealthState ~= "Healthy"
    and not reconnect
    and not roundEnded
if healthImproved then
    currentEffects:ShowHealedEffect()
end
if currentHealthState ~= lastHealthState then
    lastHealthState = currentHealthState
end
local currentSeverity = if currentHealthState ~= nil
    then HEALTH_SEVERITY[currentHealthState]
    else nil
local severityDegraded = currentSeverity ~= nil
    and lastHealthSeverity ~= nil
    and currentSeverity > lastHealthSeverity
    and not reconnect
    and not roundEnded
if severityDegraded then
    local currentCinematics = cinematics
    if currentCinematics then
        currentCinematics:PlayImpactFlash()
        if currentSeverity >= 2 then
            currentCinematics:PlayScreenShake(0.5)
        end
    end
end
if currentSeverity ~= lastHealthSeverity then
    lastHealthSeverity = currentSeverity
end
```

### A1. Add recovery notification inside `healthImproved` block

Replace:

```lua
if healthImproved then
    currentEffects:ShowHealedEffect()
end
```

With:

```lua
if healthImproved then
    currentEffects:ShowHealedEffect()
    if currentView then
        currentView:Notify("You've recovered", "You're no longer injured and can act freely.", "Success")
    end
end
```

### A2. Add injury notification inside `severityDegraded` block

Replace:

```lua
if severityDegraded then
    local currentCinematics = cinematics
    if currentCinematics then
        currentCinematics:PlayImpactFlash()
        if currentSeverity >= 2 then
            currentCinematics:PlayScreenShake(0.5)
        end
    end
end
```

With:

```lua
if severityDegraded then
    local currentCinematics = cinematics
    if currentCinematics then
        currentCinematics:PlayImpactFlash()
        if currentSeverity >= 2 then
            currentCinematics:PlayScreenShake(0.5)
        end
    end
    if currentView then
        if currentSeverity >= 2 then
            currentView:Notify("You're incapacitated", "You've been seriously wounded. You can barely move.", "DangerBright")
        else
            currentView:Notify("You've been injured", "You're hurt. Find help before it gets worse.", "Warning")
        end
    end
end
```

**Constraints for Agent A:**
- Both `healthImproved` and `severityDegraded` already guard with `not reconnect and not roundEnded`. Do not add redundant guards inside the notify calls.
- `currentSeverity >= 2` matches HEALTH_SEVERITY's Incapacitated and Critical (both map to 2). Severity 1 is Injured.
- `currentView` is a local declared at the top of `updateReleaseExperience`. Guard both notify calls with `if currentView then` for nil-safety.
- No new module-level variables, no changes to Stop(), no changes to the reconnect init block. The existing `lastHealthState` and `lastHealthSeverity` tracking is unchanged.
- Do not alter the `if currentHealthState ~= lastHealthState then` or `if currentSeverity ~= lastHealthSeverity then` update lines.
- The only changes are two additions inside the existing `if healthImproved then` and `if severityDegraded then` blocks.

---

## Acceptance Criteria

- [ ] When `severityDegraded` is true and `currentSeverity >= 2`, a "You're incapacitated" DangerBright notification fires
- [ ] When `severityDegraded` is true and `currentSeverity == 1`, a "You've been injured" Warning notification fires
- [ ] When `healthImproved` is true, a "You've recovered" Success notification fires
- [ ] No notification fires on reconnect (guarded by existing `not reconnect` in `healthImproved` and `severityDegraded`)
- [ ] No notification fires when `phaseName` is Lobby or Rewards (guarded by existing `not roundEnded`)
- [ ] `currentView` is nil-checked before each notify call
- [ ] The visual effects (`ShowHealedEffect`, `PlayImpactFlash`, `PlayScreenShake`) are unchanged
- [ ] No other changes to this file
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Change |
|------|-------|--------|
| `src/client/Controllers/RoundController.lua` | A | Add health state change notifications (injury and recovery) |
