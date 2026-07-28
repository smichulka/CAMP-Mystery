# Claude_Request-0047 — Reconnect Toast Polish + Vote Modal Murderer Framing

**Base commit:** (updated after 0046 lands)
**Wave:** 2 (Agent A: GameView.lua; Agent B: RoundController.lua)

---

## Preamble — 0046 Review

Request 0046 is accepted. Keybind hints role-gated; Murderer gets MurderPlanning and NightTransform hints; result modal has role-branched copy. All 83 checks passed.

---

## Mission

Two remaining copy gaps:

1. **Reconnect toast default body is bare scaffolding** — `"Current phase: Day."` is the single most generic line in the entire file. A healthy non-ghost non-Spectator player reconnecting mid-game deserves phase-aware, role-aware copy that tells them what they need to do right now.

2. **Vote modal warning text is written about the Murderer in third person** — the label reads `"One vote. No take-backs. A tie favors the Murderer."` The Murderer reads this about themselves. Both roles should have copy written for them.

---

## Agent B — `src/client/Controllers/RoundController.lua`

### B1. Reconnect toast — replace default branch with phase/role-aware copy

**Context:** The reconnect block default `else` branch (line ~848):

```lua
    else
        currentView:Notify(
            "Reconnected",
            string.format("Current phase: %s.", phaseName),
            "Info"
        )
    end
```

This fires for healthy, non-ghost, non-Critical/Incapacitated/Injured players of any role. `roleName` and `phaseName` are in scope.

Replace with role-aware branching:

```lua
    else
        if roleName == "Murderer" then
            currentView:Notify(
                "Reconnected",
                string.format("You are the Murderer. Phase: %s. Stay in character.", phaseName),
                "Warning"
            )
        elseif roleName == "Spectator" then
            currentView:Notify(
                "Reconnected",
                string.format("Observing — Phase: %s.", phaseName),
                "Info"
            )
        elseif phaseName == "Day" then
            currentView:Notify(
                "Reconnected",
                "Complete camp work and interview witnesses before nightfall.",
                "Info"
            )
        elseif phaseName == "Investigation" then
            currentView:Notify(
                "Reconnected",
                "Find and post evidence before the campfire vote.",
                "Info"
            )
        elseif phaseName == "Campfire" then
            currentView:Notify(
                "Reconnected",
                "Cast your vote carefully. The verdict decides the round.",
                "Info"
            )
        elseif phaseName == "MurderPlanning" then
            currentView:Notify(
                "Reconnected",
                string.format("Phase: %s. Follow the phase instructions.", phaseName),
                "Info"
            )
        elseif phaseName == "NightTransform" then
            currentView:Notify(
                "Reconnected",
                string.format("Phase: %s. Follow the phase instructions.", phaseName),
                "Info"
            )
        else
            currentView:Notify(
                "Reconnected",
                string.format("Current phase: %s.", phaseName),
                "Info"
            )
        end
    end
```

**Note:** The Murderer branch is intentionally `"Warning"` severity (amber) to signal urgency without revealing information to others. The Spectator branch preserves the Info tone. Generic fallback for any phase not explicitly handled keeps the original format.

**Constraints:**
- `roleName` and `phaseName` are already in scope — no new derivation needed.
- The ghost, Critical/Incapacitated, and Injured branches above remain completely unchanged.
- The outer `if reconnect and currentView and not roundEnded and phaseName ~= nil then` guard is unchanged.
- No new module-level variables.

---

## Agent A — `src/client/UI/GameView.lua`

### A1. Vote modal — role-aware warning label

**Context:** The warning label in `_buildVote` is set statically at build time via `Components.Label(...)`. The text is: `"One vote. No take-backs. A tie favors the Murderer."` The Murderer reads this about themselves.

**Pre-implementation step:** Confirm the exact location of the `_buildVote` method and whether the `warning` label reference is stored on `self` or is a local that goes out of scope. If the label is only a local, Agent A must store it as `self.voteWarningLabel` at build time, then update it inside `_updateVote` or whenever the vote modal becomes visible with role-aware copy.

**Target behavior:**

| Player role | Warning text |
|-------------|-------------|
| Murderer | `"One vote. No take-backs. A tie breaks in your favor."` |
| All others | `"One vote. No take-backs. A tie favors the Murderer."` (unchanged) |

**Implementation:** In `_updateVote` (or the vote modal visibility update path), after determining `localRole`, update the warning label text based on role. If the label is not yet stored on self, save the reference as `self.voteWarningLabel` in `_buildVote`.

**Constraints:**
- Do not change the warning label's position, size, colour (`Theme.Colors.Amber`), font size, or alignment.
- Only the `Text` property changes — and only when the vote modal is being shown or updated with role-aware state.
- All other vote modal content unchanged.

---

## Acceptance Criteria

**RoundController — B1 reconnect toast:**
- [ ] Healthy Murderer reconnect: title `"Reconnected"` / `Warning` severity / body mentions "You are the Murderer"
- [ ] Healthy Spectator reconnect: title `"Reconnected"` / `"Observing"` body
- [ ] Healthy Camper reconnecting during Day: body about camp work and witnesses
- [ ] Healthy Camper reconnecting during Investigation: body about evidence posting
- [ ] Healthy Camper reconnecting during Campfire: body about voting
- [ ] Ghost / injured / incapacitated branches completely unchanged
- [ ] Fallback for unlisted phases: unchanged original format

**GameView — A1 vote modal:**
- [ ] Murderer sees: `"One vote. No take-backs. A tie breaks in your favor."`
- [ ] Living Camper sees: `"One vote. No take-backs. A tie favors the Murderer."` (unchanged)
- [ ] Warning label colour, position, size unchanged

**Cross-file:**
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|------|-------|---------|
| `src/client/Controllers/RoundController.lua` | B | Reconnect default branch → phase/role-aware copy |
| `src/client/UI/GameView.lua` | A | Vote modal warning label role-branched text |
