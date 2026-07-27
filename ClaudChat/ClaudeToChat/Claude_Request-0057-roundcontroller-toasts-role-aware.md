# Claude_Request-0057 — RoundController Toast Notifications Role-Aware

**Base commit:** 2f7e271
**Wave:** 4 (all changes in RoundController.lua; Agent A: Campfire transition + all-votes-in; Agent B: ghost post-death + non-target elimination)

---

## Preamble — 0056 Review

Request 0056 is accepted. TutorialController Murderer step copy and currentContext branch implemented; PlayerStatusView roster header is role-aware. All 83 checks passed.

---

## Mission

Four toast notification call-sites in `RoundController.lua` remain role-naive. All four fire at high-tension moments where the Murderer and Ghost have distinctly different stakes than a living Camper. All four are in the same file, same `updateReleaseExperience` function, and all involve the same three variables (`roleName`, `isGhost`, `currentView`) that are already in scope.

---

## Agent A — `src/client/Controllers/RoundController.lua` (Campfire transition + all-votes-in)

### A1. Pre-implementation inspection

Agent A must read the actual file and verify:
1. Exact lines of the Campfire transition toast (~714–726). Confirm `roleName`, `isGhost`, and `aliveCount` are in scope.
2. Exact lines of the "all votes are in" toast (~544–558). Confirm `roleName` and `isGhost` are in scope.
3. The exact `currentView:Notify(title, body, style)` call signature used at each site — confirm argument count and order.

### A2. Campfire phase-transition toast — branch by role

**Context:** The Campfire transition fires a toast when the phase changes to Campfire. Current code sends identical "Cast your vote" copy to all non-ghost, non-Spectator players.

**Target behavior:**

```lua
if not isGhost and roleName ~= "Spectator" then
    if roleName == "Murderer" then
        local survivorText = if aliveCount == 1
            then "One player remains."
            else string.format("%d players remain.", aliveCount)
        currentView:Notify(
            "CAMPFIRE VOTE",
            survivorText .. " Stay calm. Deflect suspicion.",
            "DangerBright"
        )
    else
        local voteMessage = if aliveCount == 1
            then "One player remains. Cast your vote."
            else string.format("%d players remain. Cast your vote.", aliveCount)
        currentView:Notify("CAMPFIRE VOTE", voteMessage, "Warning")
    end
end
```

**Constraints:**
- `aliveCount` derivation is unchanged — use whatever the existing code already computes.
- Ghost and Spectator suppression logic is unchanged.
- Only the Murderer-specific branch is new; all other players receive the existing copy.

### A3. "All votes are in" notification — branch by role

**Context:** The notification fired when `voteCount >= participantCount` (or equivalent). Currently fires the same "The verdict is coming." copy to all roles.

**Target behavior:**

```lua
if roleName == "Murderer" then
    currentView:Notify(
        "All votes are in",
        "The vote is sealed. Your fate is decided.",
        "DangerBright"
    )
elseif isGhost then
    currentView:Notify(
        "All votes are in",
        "The campfire vote is sealed. Watch the verdict.",
        "Info"
    )
else
    currentView:Notify(
        "All votes are in",
        "The campfire vote is sealed. The verdict is coming.",
        "Warning"
    )
end
```

**Constraints:**
- If the current code has a Spectator suppression guard, preserve it.
- Style strings (`"DangerBright"`, `"Info"`, `"Warning"`) must match the exact style keys already used elsewhere in this file — inspect existing `Notify` calls to confirm casing.

---

## Agent B — `src/client/Controllers/RoundController.lua` (ghost post-death + non-target elimination)

### B1. Pre-implementation inspection

Agent B must read the actual file and verify:
1. Exact lines of the ghost post-death notification (`ghostJustDied` branch, ~829–838). Confirm `roleName` is in scope.
2. Exact lines of the non-target elimination toast (`participantId ~= localParticipantId` branch, ~609–630). Confirm `roleName` is in scope and `monsterTargetId` is already differentiated.
3. The `displayName` variable — confirm it is derived from the eliminated participant at the non-target site.

### B2. Ghost post-death notification — branch by role

**Context:** Fires when `isGhost` transitions from false to true. Currently sends neutral "witness the verdict" copy to all roles including the Murderer, whose death cinematic already correctly shows "CAUGHT."

**Target behavior:**

```lua
if ghostJustDied and currentView then
    -- (any existing delay/debounce logic is unchanged)
    if roleName == "Murderer" then
        currentView:Notify(
            "You have been unmasked",
            "The camp named you. Watch the resolution unfold.",
            "DangerBright"
        )
    else
        currentView:Notify(
            "You have been eliminated",
            "You are now a ghost. Observe the round and witness the verdict.",
            "Info"
        )
    end
end
```

**Constraints:**
- The death cinematic (`PlayDeathCinematic`) call order is unchanged — this only changes the toast copy, not the cinematic.
- If the current code has a debounce guard or delay before the notification, preserve it exactly.

### B3. Non-target elimination toast — branch by role in fallback branch

**Context:** The participant-eliminated handler already has a `monsterTargetId == participantId` branch that fires `"TARGET ELIMINATED"` correctly for the Murderer. The `else` fallback branch fires Warning-tone "A player has been taken out." to all remaining cases including the Murderer making a secondary kill.

**Current structure (approximate):**
```lua
if monsterTargetId ~= nil and monsterTargetId == participantId and currentView then
    currentView:Notify("TARGET ELIMINATED", displayName .. " has been eliminated.", "Success")
elseif participantId ~= localParticipantId and currentView then
    -- This branch fires for Murderer on secondary kills
    currentView:Notify(
        displayName .. " has been eliminated",
        "A player has been taken out.",
        "Warning"
    )
end
```

**Target behavior (else branch only):**
```lua
elseif participantId ~= localParticipantId and currentView then
    if roleName == "Murderer" then
        currentView:Notify(
            "ELIMINATED",
            displayName .. " has been taken out.",
            "Success"
        )
    else
        currentView:Notify(
            displayName .. " has been eliminated",
            "A player has been taken out.",
            "Warning"
        )
    end
end
```

**Constraints:**
- The `monsterTargetId == participantId` (primary TARGET ELIMINATED) branch is completely unchanged.
- `displayName` derivation is unchanged — use whatever the existing code already computes.
- Only the else fallback branch gains a Murderer check.
- Ghost and Spectator handling (if any exists beyond these branches) is unchanged.

---

## Acceptance Criteria

**A2 — Campfire transition toast:**
- [ ] Murderer: `"CAMPFIRE VOTE"` / `"N players remain. Stay calm. Deflect suspicion."` / DangerBright
- [ ] Living camper: `"CAMPFIRE VOTE"` / `"N players remain. Cast your vote."` / Warning (unchanged)
- [ ] Ghost / Spectator: suppressed (unchanged)

**A3 — All votes are in:**
- [ ] Murderer: `"All votes are in"` / `"The vote is sealed. Your fate is decided."` / DangerBright
- [ ] Ghost: `"All votes are in"` / `"…Watch the verdict."` / Info
- [ ] Living camper: `"All votes are in"` / `"The verdict is coming."` / Warning (unchanged)

**B2 — Ghost post-death:**
- [ ] Murderer ghost: `"You have been unmasked"` / `"The camp named you. Watch the resolution unfold."` / DangerBright
- [ ] Camper ghost: `"You have been eliminated"` / `"…witness the verdict."` / Info (unchanged)

**B3 — Non-target elimination:**
- [ ] Murderer (secondary kill): `"ELIMINATED"` / `"<Name> has been taken out."` / Success
- [ ] Living camper: unchanged Warning toast
- [ ] TARGET ELIMINATED primary branch: unchanged

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|------|-------|---------|
| `src/client/Controllers/RoundController.lua` | A | Campfire transition toast + all-votes-in toast: role-branched |
| `src/client/Controllers/RoundController.lua` | B | Ghost post-death toast + non-target elimination toast: role-branched |
