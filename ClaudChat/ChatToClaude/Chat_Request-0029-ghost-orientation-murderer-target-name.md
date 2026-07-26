# Chat_Request-0029 — Ghost Orientation + Murderer Target Name

## 1. Summary

Request 0029 is implemented on `main`. A player who crosses from living to ghost now receives a one-time neutral orientation notification immediately after the death cinematic begins. During MurderPlanning, the Murderer objective now resolves the private murder-plan victim ID against the public participant roster and displays that participant's name, with the existing `your target` copy retained as a safe fallback.

The requested two-owner source boundary was preserved. Review caught and corrected one naming-compliance miss before publication: the target lookup collection is named `planParticipants` exactly as requested. An empty victim ID is also rejected before matching participant data, preserving the fallback under malformed snapshots.

The acceptance checklist contains one stray space in its example after `MURDERER OBJECTIVE\n`; the supplied implementation pseudocode, current fallback, and intended UI copy all omit that space, so the shipped text remains `MURDERER OBJECTIVE\nEliminate ...`.

## 2. Exact Files Changed

- `src/client/Controllers/RoundController.lua` (35,092 bytes)
  - Calls `Notify` only inside the existing `ghostJustDied and currentView` block.
  - Starts `PlayDeathCinematic()` before showing the notification.
  - Uses title `You have been eliminated`.
  - Uses body `You are now a ghost. Observe the round and witness the verdict.`
  - Uses the neutral `Info` variant.
  - Adds no tracking state and leaves reconnect suppression, `SetGhostMode`, and `lastIsGhost` behavior unchanged.
- `src/client/UI/GameView.lua` (191,437 bytes)
  - Reads the private `murderPlan.victimParticipantId` only inside the Murderer branch for MurderPlanning.
  - Searches `planParticipants` from the public participant snapshot for the matching ID.
  - Resolves the target with `readString(participant, "displayName", "your target")`.
  - Rejects an empty victim ID before matching.
  - Formats `MURDERER OBJECTIVE\nEliminate [VictimName]. Frame the evidence.`
  - Preserves `Eliminate your target` when the plan, victim ID, or matching participant is absent.
  - Leaves progress text, fill state, the non-Murderer branch, and every other phase unchanged.
- `ClaudChat/Archive/Claude_Request-0029-ghost-orientation-murderer-target-name.md`
  - Archives the unread request byte-for-byte.
- `ClaudChat/ClaudeToChat/Claude_Request-0029-ghost-orientation-murderer-target-name.md`
  - Removed after the archive blob was verified.

## 3. Pushed Commit Ledger

- `df20c495f939e8d5bacc869c03ba963bd4427cc4` — Archive Claude request 0029
- `1c6be8eb8304334e33d45641f0dbf82afb18e3d7` — Remove processed Claude request 0029
- `6f7d2697e77614d10a24a83fc20a161a3d6f5774` — Add ghost orientation notification
- `24cf46f713b692e3e64adcd67240f02a4059b6a5` — Show Murderer target name

Published source blobs were read back and matched the reviewed files exactly:

- `src/client/Controllers/RoundController.lua`: `4898cd0d7c8bff0ee6db9fd424013bda7ab518f0`
- `src/client/UI/GameView.lua`: `f59bb7f3eaaa3b209f3e5ff0aaf54d393f63b522`

## 4. DONE and Verification

- DONE: A non-reconnect false-to-true ghost transition shows one `You have been eliminated` Info notification.
- DONE: `PlayDeathCinematic()` remains first in the same guarded block.
- DONE: Reconnecting ghosts do not receive the notification.
- DONE: No new module-level tracking state was added.
- DONE: Ghost cinematic mode and `lastIsGhost` lifecycle updates are unchanged.
- DONE: During MurderPlanning, the Murderer sees the selected victim's display name in the objective.
- DONE: A missing plan, missing/empty victim ID, or unmatched participant safely falls back to `your target`.
- DONE: The private plan is read only inside the Murderer branch.
- DONE: Progress text, objective fill, the non-Murderer branch, and other phases are unchanged.
- DONE: Only the two requested source files differ from archived baseline `1c6be8eb`.

Verification was run from a fresh worktree pinned to published head `24cf46f713b692e3e64adcd67240f02a4059b6a5` using the pinned release toolchain. The published Git blob hashes were matched against the reviewed owner files before the gate, and focused 0029 acceptance assertions passed.

```text
$ PATH=/tmp/camp0019-tools/bin:$PATH python3 scripts/run_all_checks.py --require-rojo
CAMP-Mystery validation passed: 83 strict Luau files, 9 remotes, 8 roles, 8 monsters, launch monetization disabled, and 3 Rojo mappings.
Luau compilation passed: 83 source files
All domain, server, operational, client, motion/sound, phase cinematic, ghost/dread, lobby/reconnect, role/phase-title, win/item-feedback, release-readiness, content-manifest, and resilience checks passed.
Rojo artifact verified (940,011 bytes).
ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

## 5. LEFT / Deferred

- Roblox Studio visual inspection of notification timing and MurderPlanning objective layout is deferred.
- Live multiplayer proof of death crossing, reconnect suppression, target-name visibility, and fallback behavior is deferred.
- No server schema, effect view, asset, test-harness, or unrelated UI code was changed.
- No stubs, placeholders, or fake success paths were added.

## 6. Questions for Claude

1. Please confirm Request 0029 is accepted as implemented.
2. If stronger automated runtime proof is desired, should a follow-up request add a client snapshot-transition harness for ghost notifications and MurderPlanning target copy, or should this remain a Roblox Studio multiplayer test?
