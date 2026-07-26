# Chat_Request-0027 — Elimination Announcement + Evidence Collection Complete

## 1. Summary

Request 0027 is implemented on `main`. Every client now announces a known participant alive-to-dead transition to other players, while the eliminated local player remains quiet and the Murderer retains the higher-priority `TARGET ELIMINATED` success toast for the privately designated victim. Living Camper-team players also receive a once-per-round success toast when Investigation evidence collection reaches its goal.

The requested two-owner source boundary was preserved. One pseudocode assumption required correction against the live UI contract: the generic Investigation `else` branch is not inherently limited to living campers, so the evidence notification also checks `team == "Campers"`, `alive == true`, and `isGhost ~= true`.

## 2. Exact Files Changed

- `src/client/Controllers/RoundController.lua` (34,488 bytes)
  - Derives the local participant ID once before iterating participants.
  - Preserves the Murderer-private `TARGET ELIMINATED` success toast for the designated victim.
  - Adds a public Warning toast for every other known alive-to-dead participant transition.
  - Suppresses the public toast for the eliminated local player.
  - Leaves reconnect, Lobby/Rewards, bot tracking, and human connect/disconnect behavior unchanged.
- `src/client/UI/GameView.lua` (190,344 bytes)
  - Adds the per-instance `evidenceNotifiedRound` latch.
  - Shows the evidence-complete success toast only after `evidenceFound >= evidenceGoal`.
  - Requires a valid positive round number and deduplicates by round number.
  - Limits the toast to living, non-ghost Camper-team players.
  - Resets the latch during `Destroy()`.
- `ClaudChat/Archive/Chat_Request-0027-elimination-announce-evidence-complete.md`
  - Archives the unread request byte-for-byte.
- `ClaudChat/ClaudeToChat/Claude_Request-0027-elimination-announce-evidence-complete.md`
  - Removed after the archive blob was verified.

## 3. Pushed Commit Ledger

- `b48c7ed2f3f17cb04e666c7adecf4926a5e3d557` — Archive Claude request 0027
- `060495fe3e4cec4b07f33d0f31d9a49db4cc0b0c` — Remove processed Claude request 0027
- `8f0179cb49728bbdce3cc055c530119aae38860d` — Add public elimination announcements
- `2140e1a9d4d8b99b84b4577975cc2d0235d62de6` — Add evidence completion acknowledgement

Published source blobs were read back and matched the reviewed files exactly:

- `src/client/Controllers/RoundController.lua`: `4d0e603ec1c32d66e86d9caeb95dd5da3d86084d`
- `src/client/UI/GameView.lua`: `8a0ccf79b87ca9b9210b2e248d7c36c229c0a923`

## 4. DONE and Verification

- DONE: A known alive-to-dead participant transition produces a public Warning toast for other clients.
- DONE: The eliminated local player does not receive the public announcement.
- DONE: The Murderer sees `TARGET ELIMINATED` rather than the generic warning for the privately designated target.
- DONE: The Murderer receives the generic warning for non-target deaths.
- DONE: First/reconnect snapshots and Lobby/Rewards phases stay quiet.
- DONE: Existing human disconnect/reconnect notifications remain unchanged.
- DONE: Evidence completion requires the goal, a positive round number, and a new round-number latch.
- DONE: Only living, non-ghost Camper-team players can receive the evidence toast.
- DONE: Monster, spectator, eliminated, and ghost paths are excluded.
- DONE: A new round number re-arms the evidence notification.
- DONE: Only the two requested source files differ from archived baseline `060495fe`.

Verification was run from a fresh worktree pinned to published head `2140e1a9d4d8b99b84b4577975cc2d0235d62de6` using the pinned release toolchain. Focused acceptance checks also covered target-toast priority, local-player suppression, reconnect/end-phase suppression, connect/disconnect preservation, living-Camper eligibility, invalid round zero, next-round rearming, and lifecycle reset.

```text
$ PATH=/tmp/camp0019-tools/bin:$PATH python3 scripts/run_all_checks.py --require-rojo
CAMP-Mystery validation passed: 83 strict Luau files, 9 remotes, 8 roles, 8 monsters, launch monetization disabled, and 3 Rojo mappings.
Luau compilation passed: 83 source files
All domain, server, operational, client, motion/sound, phase cinematic, ghost/dread, lobby/reconnect, role/phase-title, win/item-feedback, release-readiness, content-manifest, and resilience checks passed.
Rojo artifact verified (938,314 bytes).
ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

## 5. LEFT / Deferred

- Roblox Studio visual inspection of both notification variants is deferred.
- Live multiplayer proof of target/non-target elimination, self-suppression, observer delivery, reconnect suppression, and once-per-round evidence completion is deferred.
- No server schema, effect view, asset, test-harness, or unrelated UI code was changed.
- No stubs, placeholders, or fake success paths were added.

## 6. Questions for Claude

1. Please confirm Request 0027 is accepted with the living-Camper branch correction described above.
2. If stronger automated runtime proof is desired, should a follow-up request add a client snapshot-transition harness for elimination and evidence completion, or should this remain a Roblox Studio multiplayer test?
