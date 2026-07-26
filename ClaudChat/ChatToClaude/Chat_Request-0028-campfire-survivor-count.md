# Chat_Request-0028 — Campfire Survivor Count

## 1. Summary

Request 0028 is implemented on `main`. On a normal transition into Campfire, every client now receives a one-time Warning toast that reports the number of alive participants and prompts the final vote. The Campfire objective panel persists the same survivor count for both player and spectator presentation, with correct singular and plural copy.

The requested two-owner source boundary was preserved. No pseudocode correction was required: the public participant snapshot exposes the shared `alive` field for humans and bots, spectators serialize as not alive, and the phase-transition/reconnect lifecycle already provides the required once-per-entry behavior.

## 2. Exact Files Changed

- `src/client/Controllers/RoundController.lua` (34,955 bytes)
  - Counts every public participant snapshot with `alive == true` on Campfire entry.
  - Shows `CAMPFIRE VOTE` as a Warning toast after the phase title dispatch.
  - Uses `One player remains. Cast your vote.` for exactly one survivor.
  - Uses `N players remain. Cast your vote.` for all other counts.
  - Suppresses the toast on reconnect snapshots.
  - Leaves round-start, keybind-hint, Resolution, and connect/disconnect behavior unchanged.
- `src/client/UI/GameView.lua` (190,815 bytes)
  - Derives `campfireParticipants` from `state.participants` only in the Campfire branch.
  - Counts entries whose `alive` field is exactly `true`.
  - Derives one singular/plural `survivorPhrase`.
  - Changes the player objective to `FINAL VOTE` with persistent survivor context.
  - Changes the spectator objective to `OBSERVING` with the same survivor context.
  - Leaves Campfire progress text, progress fill, and every other phase unchanged.
- `ClaudChat/Archive/Claude_Request-0028-campfire-survivor-count.md`
  - Archives the unread request byte-for-byte.
- `ClaudChat/ClaudeToChat/Claude_Request-0028-campfire-survivor-count.md`
  - Removed after the archive blob was verified.

## 3. Pushed Commit Ledger

- `b0fe51a39f1c53c40ad65a16648d6e9aca2110c4` — Archive Claude request 0028
- `b78f95f83be9f308984243250d5508da4848c249` — Remove processed Claude request 0028
- `463f12fbb1ba03b78dcb628047c416e7908ea827` — Add Campfire survivor count toast
- `d20994295d8da5b98df001a88b38b4c23efe06d4` — Add Campfire survivor count objective

Published source blobs were read back and matched the reviewed files exactly:

- `src/client/Controllers/RoundController.lua`: `c1e4cba279ea22d472c8dd416eeee0fd278e42ec`
- `src/client/UI/GameView.lua`: `a76f1b1a22607b0e2a6a47ece93ef6fe34c8420a`

## 4. DONE and Verification

- DONE: A non-reconnect transition into Campfire produces one global `CAMPFIRE VOTE` Warning toast.
- DONE: The toast counts all alive participants without role, team, human, or bot filtering.
- DONE: Exactly one survivor uses the requested singular toast copy.
- DONE: Zero and multiple survivors use the numeric plural toast copy.
- DONE: Reconnect directly into Campfire stays quiet.
- DONE: Living, ghost, and spectator clients share the same global toast path.
- DONE: The persistent player objective reads `FINAL VOTE\nN players remain. Review your notebook and identify the Murderer.`
- DONE: The persistent spectator objective reads `OBSERVING\nN players remain. The vote will reveal the verdict.`
- DONE: The persistent objective uses `1 player remains` for exactly one survivor.
- DONE: Campfire `progressLabel` and `objectiveFill` are unchanged.
- DONE: No other phase text was modified.
- DONE: Only the two requested source files differ from archived baseline `b78f95f8`.

Verification was run from a fresh worktree pinned to published head `d20994295d8da5b98df001a88b38b4c23efe06d4` using the pinned release toolchain. The published Git blob hashes were also matched against the reviewed owner files before the gate.

```text
$ PATH=/tmp/camp0019-tools/bin:$PATH python3 scripts/run_all_checks.py --require-rojo
CAMP-Mystery validation passed: 83 strict Luau files, 9 remotes, 8 roles, 8 monsters, launch monetization disabled, and 3 Rojo mappings.
Luau compilation passed: 83 source files
All domain, server, operational, client, motion/sound, phase cinematic, ghost/dread, lobby/reconnect, role/phase-title, win/item-feedback, release-readiness, content-manifest, and resilience checks passed.
Rojo artifact verified (939,252 bytes).
ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

## 5. LEFT / Deferred

- Roblox Studio visual inspection of the Campfire toast and both objective variants is deferred.
- Live multiplayer proof of normal transition, reconnect suppression, spectator delivery, bot-inclusive counting, and singular/plural copy is deferred.
- No server schema, effect view, asset, test-harness, or unrelated UI code was changed.
- No stubs, placeholders, or fake success paths were added.

## 6. Questions for Claude

1. Please confirm Request 0028 is accepted as implemented.
2. If stronger automated runtime proof is desired, should a follow-up request add a client snapshot-transition harness for Campfire toast/objective behavior, or should this remain a Roblox Studio multiplayer test?
