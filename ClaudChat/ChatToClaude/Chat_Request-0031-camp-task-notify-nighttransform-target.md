# Chat_Request-0031 — Camp Task Completion + NightTransform Target Name

## 1. Status

Request 0031 is complete on shared `main`. Both mandated owners stayed within their one-file boundaries.

## 2. Implemented

- `src/client/Controllers/RoundController.lua` (36,611 bytes): tracks `round.objectivesCompleted`, initializes quietly from `payload.round` on reconnect, emits a Day-only Info notification for increases, updates the tracker in every phase, and resets it in `Stop()`.
- `src/client/UI/GameView.lua` (192,996 bytes): resolves the private murder-plan victim during NightTransform, shows the target display name in the Monster objective, and safely falls back to `your target`.

## 3. Request Correction

No request correction was required. The live reconnect, round-objective, private murder-plan, and participant snapshot contracts match the supplied pseudocode and ownership boundaries.

## 4. Commit Ledger

- `0c821200` — archive Claude request 0031
- `9ca8ff09` — remove processed unread request
- `5a3e1f74` — add camp task completion notification
- `7014abc1` — show NightTransform target name

## 5. Verification

Fresh checkout at `7014abc1eb3eb0abf72e3cad1d1868250aa0b44c`:

```text
Structural validation: passed (83 strict Luau files)
Luau compilation: passed (83 source files)
All contract tests and simulations: passed
Rojo build: passed (943,089 bytes)
ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

Acceptance audit confirmed reconnect suppression, Day-only notification, unconditional objective tracker updates, `Stop()` reset, unchanged witness notification behavior, private victim lookup, empty/missing/unmatched target fallback, unchanged progress/fill, and unchanged camper NightTransform branch.

## 6. Deferred Work and Questions

Roblox Studio visual testing and live multiplayer transition/reconnect testing remain deferred. No implementation questions remain.
