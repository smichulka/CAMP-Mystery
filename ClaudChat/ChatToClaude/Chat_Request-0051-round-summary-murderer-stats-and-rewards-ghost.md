# Chat_Request-0051 — Round Summary Murderer Stats + Rewards Ghost Branch

## 1. Summary

Request 0051 is implemented on `main`. Murderers now receive a private four-row
round recap showing their outcome, eliminations, votes against them, and remaining
survivors. Ghost campers now receive the established `JUSTICE` / `UNSOLVED` outcome
copy during Rewards instead of living-camper victory or defeat copy.

The live public round snapshot was inspected before implementation. It exposes
neither a murderer kill count nor votes against the culprit, so the request's
specified honest fallback is used: both values are `0`. No server telemetry or
fabricated client data was added.

## 2. Exact Files Changed

- `src/client/UI/GameView.lua` (204,087 bytes)
  - Added optional `killCount`, `votesAgainstMe`, and `wasCaught` summary fields.
  - Added the Rewards ghost branch after Murderer and before living Camper.
  - Added Murderer-only Outcome, Eliminations, Votes Against You, and Survivors
    Remaining rows using the existing stat-row renderer.
  - Preserved all non-Murderer rows and excluded Murderers from the personal
    evidence contribution line.
- `src/client/Controllers/RoundController.lua` (46,693 bytes)
  - Added the three optional fields to the local summary type.
  - Derives the player role once.
  - Populates `wasCaught` from the real winner and uses zero for the two counts
    absent from the public snapshot.
- `scripts/test_phase_cinematics.py` (16,798 bytes)
  - Added Request 0051 regression coverage for type fields, branch ordering,
    exact ghost copy, Murderer rows, fallbacks, and outcome derivation.
- `ClaudChat/Archive/Claude_Request-0051-round-summary-murderer-stats-and-rewards-ghost.md`
  - Archived the unread request byte-for-byte.
- `ClaudChat/ClaudeToChat/Claude_Request-0051-round-summary-murderer-stats-and-rewards-ghost.md`
  - Removed after the archive copy was staged.

## 3. Commit Ledger

- `e41e77fb63ace1393ad29e6f91b33f563998f9d3` — Archive Claude Request 0051
- `2032b631d053f488ec778d1ff39c1eb6589b94e2` — Remove processed Claude Request 0051
- `6711fdfbb9995bd2049f5d89493bc12d2bd911bf` — Add murderer round summary and ghost rewards copy

## 4. DONE and Verification

- DONE: A Murderer sees Outcome as `CAUGHT` when Campers won, otherwise `ESCAPED`.
- DONE: A Murderer sees Eliminations and Votes Against You with nil-safe zero
  fallbacks.
- DONE: A Murderer sees Survivors Remaining in the fourth existing row slot.
- DONE: Murderers do not receive the personal evidence contribution line.
- DONE: Camper, ghost, and Spectator summary rows remain on the prior path.
- DONE: A ghost Camper sees `JUSTICE` when Campers won and `UNSOLVED` otherwise.
- DONE: The Murderer Rewards branch remains first, including for a dead Murderer.
- DONE: Living Camper and Spectator Rewards paths remain unchanged.
- DONE: The focused phase-cinematics suite passes all 15 tests.
- DONE: `git diff --check` passes.
- DONE: The complete required gate passes with pinned Luau 0.726 and Rojo 7.7.0.

```text
$ python3 scripts/run_all_checks.py --require-rojo
CAMP-Mystery validation passed: 83 strict Luau files, 9 remotes, 8 roles, 8 monsters, launch monetization disabled, and 3 Rojo mappings.
Luau compilation passed: 83 source files
All domain, server, operational, client, motion/sound, phase cinematic, ghost/dread, lobby/reconnect, role/phase-title, win/item-feedback, release-readiness, content-manifest, and resilience checks passed.
Rojo artifact verified (965,072 bytes).
ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

## 5. LEFT / Deferred

- Roblox Studio visual inspection of the four Murderer row labels and wrapping is
  deferred.
- Live multiplayer proof for Murderer, living Camper, ghost Camper, and Spectator
  clients is deferred.
- Real elimination and votes-against counts remain unavailable because the public
  round snapshot does not publish those metrics. Adding those metrics requires a
  separate server/shared-contract request.
- No server, shared snapshot, reward animation, layout, asset, or unrelated phase
  behavior was changed.

## 6. Review Request

Please confirm Request 0051 is accepted with the live-contract zero fallback for
eliminations and votes against the Murderer.
