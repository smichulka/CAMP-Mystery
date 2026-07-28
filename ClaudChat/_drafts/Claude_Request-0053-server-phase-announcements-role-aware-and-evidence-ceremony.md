# Claude_Request-0053 — Server Phase Announcements Role-Aware + Evidence Discovery Ceremony Murderer Path

**Base commit:** d6d85d8
**Wave:** 2 (Agent A: GameRuntimeService.lua or RoundController.lua announcement dispatch; Agent B: RoundController.lua evidence ceremony guard)

---

## Preamble — 0052 Review

Request 0052 is accepted. Vote candidate list shows `" (you)"` marker on the local player's own suspect entry; self-voting shows `"(you)  ✓ YOUR VOTE"` after locking. Murderer Campfire timer turns amber at 60s and DangerBright at 20s (with pulse) in both the snapshot-update and interpolated Tick paths; all other roles and phases unchanged. All 83 checks passed.

---

## Mission

Two gaps found by server-side audit:

1. **Server phase announcements** send camper-framed copy to all players via `FireAllClients`. The Murderer reads "Stay alert. Someone at camp is choosing what happens tonight." during MurderPlanning — they ARE the someone. "Get to safety. Camp is changing around you." during NightTransform — they don't need safety, they are the threat. The announcements cannot be role-personalized server-side (single broadcast to all clients), but the client-side `RoundController` can suppress or replace the banner when the Murderer receives it.

2. **Evidence discovery ceremony** fires `PlayEvidenceDiscovery` for all players including the Murderer when new evidence is found. The Murderer sees the camper-positive "NEW CLUE" ceremony with `Theme.Colors.Info` framing — a discovery animation celebrating evidence that implicates them. The Murderer should instead see a threat notification: a toast, not a ceremony.

---

## Agent A — Client-side phase announcement override for Murderer

**Context:** Find where the `announcement` remote event is received on the client. This is likely in RoundController.lua or a dedicated AnnouncementController. The server fires `announcement:FireAllClients(kind, title, message, duration)` with flat string payloads. The client renders the banner.

**Pre-implementation:** Agent A must find the announcement listener on the client and determine where the banner text is rendered. If the banner text is set directly from the remote payload (title/message), the cleanest fix is to intercept at the listener and substitute Murderer-specific copy for the affected phases.

**Target substitutions (only when `roleName == "Murderer"` AND announcement matches these phases):**

| Phase / title received | Murderer sees instead |
|---|---|
| "MurderPlanning" banner | title: `"YOUR PLAN"`, message: `"Choose your target. You have until dawn."` |
| "NightTransform" banner | title: `"YOUR HUNT BEGINS"`, message: `"You are the threat. Move unseen."` |
| "Investigation" banner | title: `"THEY ARE SEARCHING"`, message: `"Stay calm. Blend in. Cast doubt."` |

All other banners (Lobby, Day, Campfire, RoleReveal, Resolution, Rewards) are unchanged for all roles.

**Implementation approach:** At the client-side announcement listener, after receiving the payload, check if `roleName` is "Murderer" (derive it the same way RoundController does — from the latest `player.role` snapshot) and if the phase matches one of the three above. If both are true, substitute the title and message before passing to the banner renderer. If the client listener does not have easy access to `roleName`, inspect RoundController for whether it intercepts the remote or defers to a view method.

**Constraints:**
- Only three phase announcements are overridden. All other content (kind, duration, color, font, animation) is unchanged.
- If the announcement listener is in RoundController, the `roleName` variable is in scope from the snapshot — no new remote calls needed.
- If the listener is in a separate controller with no snapshot access, pass the role-aware copy from RoundController via the view's existing method (e.g., `currentView:SetAnnouncementOverride(phaseName, title, message)`). Choose whatever is cleanest.
- Do not modify GameRuntimeService.lua or the server-side broadcast.

---

## Agent B — `src/client/Controllers/RoundController.lua`

### B1. Evidence discovery ceremony — suppress for Murderer, show threat toast instead

**Context:** Lines ~483–487:

```lua
if evidenceFound > lastEvidenceFound and currentView then
    local evidenceName, evidenceDescription = evidenceCopy(latestEvidence)
    currentEffects:FlashEvidenceFound()
    currentView:PlayEvidenceDiscovery(evidenceName, evidenceDescription)
end
```

This fires unconditionally for all roles. The Murderer sees the celebratory discovery overlay.

**Change:** Add a role check:

```lua
if evidenceFound > lastEvidenceFound and currentView then
    if roleName == "Murderer" then
        -- Threat notification instead of discovery ceremony
        currentView:Notify(
            "Evidence Found",
            "A clue has been posted against you. Stay composed.",
            "Warning"
        )
    else
        local evidenceName, evidenceDescription = evidenceCopy(latestEvidence)
        currentEffects:FlashEvidenceFound()
        currentView:PlayEvidenceDiscovery(evidenceName, evidenceDescription)
    end
end
```

**Pre-implementation check:** Agent B must verify that `roleName` is in scope at this call site (lines ~483–487). If it is not yet derived at this point in the snapshot processing loop, derive it inline:

```lua
    local evidenceRole = if type(player) == "table" and type(player.role) == "string"
        then player.role
        else ""
```

And use `evidenceRole` instead of `roleName` in the branch.

**Also check:** Whether `currentEffects:FlashEvidenceFound()` triggers any screen effect that the Murderer should also NOT see. If it flashes the screen with a positive "found it!" effect, suppress it for the Murderer (only call it in the `else` branch, as shown).

**Constraints:**
- Ghost players who were campers are NOT the Murderer — they see the discovery ceremony normally (their `isGhost` flag is true but `player.role` is not "Murderer"). Do not suppress for ghosts.
- The toast uses `"Warning"` severity (amber) — same as the Murderer reconnect toast — consistent urgency signaling.
- Spectators: they are non-Murderer, so they see the normal discovery ceremony.
- `lastEvidenceFound` update (whichever line sets it after the block) is completely unchanged.

---

## Acceptance Criteria

**Agent A — phase announcement override:**
- [ ] Murderer entering MurderPlanning: banner title `"YOUR PLAN"`, message about choosing target
- [ ] Murderer entering NightTransform: banner title `"YOUR HUNT BEGINS"`, message about being unseen
- [ ] Murderer entering Investigation: banner title `"THEY ARE SEARCHING"`, message about blending in
- [ ] All other banners (Day, Campfire, Lobby, etc.) unchanged for Murderer
- [ ] All banners unchanged for non-Murderer roles
- [ ] Banner animation, color, duration unchanged

**RoundController — B1 evidence ceremony:**
- [ ] Murderer: receives `"Warning"` toast `"A clue has been posted against you. Stay composed."` instead of ceremony
- [ ] Murderer: `FlashEvidenceFound()` NOT called (positive effect suppressed)
- [ ] All other living players: discovery ceremony and flash unchanged
- [ ] Ghost players: discovery ceremony unchanged (they observe normally)

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|------|-------|---------|
| Client announcement listener (RoundController.lua or dedicated file) | A | Substitute Murderer-specific title/message for MurderPlanning, NightTransform, Investigation banners |
| `src/client/Controllers/RoundController.lua` | B | Evidence discovery: Murderer gets threat toast, not ceremony |
