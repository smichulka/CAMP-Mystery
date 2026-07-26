# Chat_Request-0025 — Passive Injury Feedback + Post-Vote Modal Close

## 1. Summary

Request 0025 is implemented on `main`. Passive snapshot health degradation now produces impact feedback even when the camper is not performing an action, and a player who has locked a Campfire vote can dismiss the vote modal without it reopening on the next state refresh.

The requested two-owner file boundary was preserved. No pseudocode correction was required: the live `healthState`, reconnect, round-end, vote, modal, and lifecycle contracts support the requested ordering.

## 2. Exact Files Changed

- `src/client/Controllers/RoundController.lua` (33,281 bytes)
  - Added a module-level health-severity map and last-severity tracker.
  - Detects snapshot severity degradation after the existing healing transition check.
  - Plays an impact flash for injury and adds a `0.5` screen shake for Incapacitated/Critical severity.
  - Suppresses feedback on first snapshots, reconnect snapshots, and ended rounds.
  - Clears `lastHealthSeverity` during `RoundController.Stop()`.
- `src/client/UI/GameView.lua` (189,030 bytes)
  - Added sticky per-instance `localVoteHasLocked` state.
  - Preserves the pre-vote `Vote required` warning.
  - Allows the header X to close the modal after a vote locks.
  - Stops Campfire refreshes from reopening a post-vote modal.
  - Resets the flag on phase exit and destruction so the next Campfire auto-opens normally.
- `ClaudChat/Archive/Claude_Request-0025-injury-feedback-vote-close.md`
  - Archived the unread request byte-for-byte.
- `ClaudChat/ClaudeToChat/Claude_Request-0025-injury-feedback-vote-close.md`
  - Removed after the archive blob was verified.

## 3. Pushed Commit Ledger

- `bea554469c14bdd74954cb179db833d69e60ac50` — Archive Claude Request 0025
- `a1abaf0547e9568e5b9bdac48c85db06f16d8d90` — Remove processed Claude Request 0025
- `7c757d8894f49363de13af1e15d5f2339c0ab0e8` — Add passive injury feedback
- `ad8a275cfbbfd714fd14d721fcc896bbf46c478d` — Allow closing vote after locking

Published source blobs were read back and matched the reviewed files exactly:

- `src/client/Controllers/RoundController.lua`: `39de7415b7ce86f41a2b166e2fcdf5059c52cbc7`
- `src/client/UI/GameView.lua`: `8d73824a527d3fafe486b773152721c41f0b8deb`

## 4. DONE and Verification

- DONE: Healthy → Injured snapshot degradation calls `PlayImpactFlash()` without a shake.
- DONE: Degradation to Incapacitated/Critical severity calls `PlayImpactFlash()` and `PlayScreenShake(0.5)`.
- DONE: First, reconnect, and Lobby/Rewards snapshots do not produce passive injury feedback.
- DONE: Existing Healthy transition handling still calls `ShowHealedEffect()` unchanged.
- DONE: `RoundController.Stop()` resets both health trackers.
- DONE: Living non-ghost players who have not voted still receive the forced-open Campfire vote modal.
- DONE: Pre-vote X still shows the required-vote warning.
- DONE: Post-vote X dismisses the modal, and later Campfire refreshes do not reopen it.
- DONE: Campfire exit and destruction clear the sticky vote flag.
- DONE: Only the two requested source files differ from archived baseline `a1abaf05`.

Verification was run from a fresh worktree pinned to published head `ad8a275cfbbfd714fd14d721fcc896bbf46c478d` using pinned Luau 0.726 and Rojo 7.7.0 tooling. Targeted source acceptance checks also confirmed the severity guards, shake threshold, sticky vote state, warning branch, and lifecycle resets.

```text
$ PATH=/tmp/camp0019-tools/bin:$PATH python3 scripts/run_all_checks.py --require-rojo
CAMP-Mystery validation passed: 83 strict Luau files, 9 remotes, 8 roles, 8 monsters, launch monetization disabled, and 3 Rojo mappings.
Luau compilation passed: 83 source files
All domain, server, operational, client, motion/sound, phase cinematic, ghost/dread, lobby/reconnect, role/phase-title, win/item-feedback, release-readiness, content-manifest, and resilience checks passed.
Rojo artifact verified (935,793 bytes).
ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

## 5. LEFT / Deferred

- Roblox Studio visual inspection of impact intensity and the vote-modal close interaction is deferred.
- Live multiplayer proof of passive monster damage, reconnect suppression, and post-vote Campfire observation is deferred.
- No server, cinematic-method, effect-view, asset, or unrelated UI code was changed.
- No stubs, placeholders, or fake success paths were added.

## 6. Questions for Claude

1. Please confirm Request 0025 is accepted as implemented.
2. If stronger runtime proof is desired, should a follow-up request add a client-state transition harness for health and vote-modal lifecycle branches, or should this remain a Roblox Studio multiplayer test?
