# Claude_Request-0046 — Keybind Hints Role-Gating + Result Modal Role Copy

**Base commit:** (updated after 0045 lands)
**Wave:** 2 (Agent A: GameView.lua; Agent B: KeybindHints.lua or GameView keybind path — investigate)

---

## Preamble — 0045 Review

Request 0045 is accepted. readBoolean defined; Campfire/Day toast guards added; stamina nil fix applied; Investigation closing role-differentiated; NightTransform and Lobby panels role-branched. All 83 checks passed.

---

## Mission

Two UX gaps remain:

1. **Keybind hints** — the `ShowKeybindHint` system fires for every player with the same hint on phase entry, ignoring role and alive state. Ghost players entering Campfire see "E Vote" (they can't vote). Spectators and ghosts entering Investigation see "Q Role ability" (they have no ability). The Murderer entering MurderPlanning and NightTransform gets no hint at all, despite those phases having interactive elements.

2. **Result modal** — shows identical title/body copy (`round.resultMessage`, winner string) to Murderer, Camper, ghost, and Spectator. The mission panel already branches by role during Rewards; the modal should too.

---

## Pre-implementation investigation required

Before implementing keybind hints, Agent A must:
1. Read `src/client/UI/GameView.lua` and find `ShowKeybindHint` — how it works, what data it takes, where it's called in the Update flow.
2. Read whatever file provides the hint content (`KeybindHints.lua` or similar) — find its structure.
3. Determine whether role-gating can be added at the call site (`RoundController`) or requires changes to hint definitions.

Report the findings before touching any file, then implement the minimal correct fix.

---

## Agent A — Keybind hint role-gating

### Target behavior

| Phase | Current | Target |
|-------|---------|--------|
| Day | All roles: generic Day hints | All roles: same (Day is social, all roles can interact) |
| Investigation | All roles: investigate hints incl "Q Role ability" | Ghost + Spectator: suppress hint entirely; Murderer: hint includes ability; Camper: unchanged |
| Campfire | All roles: "E Vote" hint | Ghost + Spectator: suppress hint entirely; Murderer + living Camper: unchanged |
| MurderPlanning | No hint | Murderer: add hint for ability/planning; others: no hint (correct) |
| NightTransform | No hint | Murderer: add hint for ability; others: no hint (correct) |

### Implementation approach

At the RoundController call site (inside `HINT_PHASES` check or wherever `ShowKeybindHint` is called):
- Pass role/ghost state as a parameter, OR
- Add conditional logic around the call so ghost/Spectator skip it for phases where their hints are wrong
- Add new hint calls for Murderer during MurderPlanning and NightTransform if the hint system supports per-role hints

Implement whatever approach is cleanest given the actual system discovered. Minimise changes.

**Constraints:** Do not add a hint for a role that has no meaningful action in that phase. Do not suppress hints for roles that can take action. The `reducedMotion` bypass is unchanged.

---

## Agent B — Result modal role copy

### Context

In `GameView:Update`, when `phase == "Resolution" or phase == "Rewards"` and the result modal is not yet visible (approximately line 4341), the modal is shown and its title/body are set from `round.resultMessage` and `winner`. There is currently no role check.

### Target behavior

Add role-aware copy to `resultTitle` and `resultBody` inside the modal. Mirror the structure of the Rewards mission panel (which already branches by Murderer / non-Spectator camper / Spectator).

```
campersWon = round.winner == "Campers"
```

Branch:

| Role | campersWon = true | campersWon = false |
|------|------------------|--------------------|
| Murderer | "CAUGHT" / "The camp unmasked you. The hunt is over." | "ESCAPED" / "The camp never identified you. A flawless hunt." |
| Ghost | "JUSTICE" / "The murderer was caught. Your death was not in vain." | "UNSOLVED" / "The murderer escaped. The mystery remains." |
| Spectator | "CAMPERS WIN" / round.resultMessage | "MURDERER WINS" / round.resultMessage |
| Living camper (default) | "VICTORY" / "Justice was served. The camp is safe." | "DEFEAT" / "The murderer escaped. The mystery went unsolved." |

**Constraints:**
- `readString`, `readBoolean`, `readNumber` are in scope.
- Keep `voteRevealOwnsResults` guard — if that flag is true, do not override title/body (existing behavior). The role-branched copy applies only when `not voteRevealOwnsResults`.
- The `_animateRewards` call and XP/token display are unchanged.
- No other phases touched.

---

## Acceptance Criteria

**Keybind hints:**
- [ ] Ghost entering Campfire: no keybind hint
- [ ] Spectator entering Campfire: no keybind hint
- [ ] Ghost entering Investigation: no keybind hint
- [ ] Spectator entering Investigation: no keybind hint
- [ ] Murderer entering MurderPlanning: receives a keybind hint
- [ ] Murderer entering NightTransform: receives a keybind hint
- [ ] Living Camper hints unchanged for Day, Investigation, Campfire

**Result modal:**
- [ ] Murderer (caught): modal title "CAUGHT", body about unmasking
- [ ] Murderer (escaped): modal title "ESCAPED", body about flawless hunt
- [ ] Living camper (won): modal title "VICTORY"
- [ ] Living camper (lost): modal title "DEFEAT"
- [ ] Ghost (won): modal title "JUSTICE"
- [ ] Ghost (lost): modal title "UNSOLVED"
- [ ] `voteRevealOwnsResults` guard unchanged
- [ ] `scripts/run_all_checks.py --require-rojo` passes (83 strict Luau files, same count)

---

## File Summary

| File | Agent | Changes |
|------|-------|---------|
| `src/client/Controllers/RoundController.lua` and/or keybind source | A | Role-gate keybind hints; add Murderer hints for MurderPlanning/NightTransform |
| `src/client/UI/GameView.lua` | B | Result modal role-branched title/body copy |
