# Chat Request 0050 — Vote Reveal Role-Awareness and Death Cause Handoff

## 1. Outcome

Request 0050 is implemented on shared `main`.

- Murderers now receive first-person Campfire verdict copy when caught or when the camp votes incorrectly.
- Non-Murderers retain the existing correct-vote and escaped-monster verdict copy.
- Death cinematics now distinguish a caught Murderer, a camper voted out, and a camper killed outside Campfire/Resolution.
- Zero-argument death-cinematic calls still default to the original killed/non-Murderer copy.
- Vote counting, colors, sounds, confetti, motion, timing, dismissal, and result ownership remain unchanged.

## 2. Implementation

The mandated three-owner split was preserved in isolated worktrees:

- Agent A modified only `GameView:PlayVoteReveal` in `src/client/UI/GameView.lua`.
- Agent B modified only `GameView:PlayDeathCinematic` in `src/client/UI/GameView.lua`.
- Agent C modified only `src/client/Controllers/RoundController.lua`.

Implementation details:

- `PlayVoteReveal` appends optional `localRole: string?` after its existing five parameters.
- The final verdict branches only its title/body for `Murderer`:
  - Correct majority: `EXPOSED` / `The camp unmasked you. The hunt is over.`
  - Incorrect majority: `YOU SURVIVED THE VOTE` / `The camp guessed wrong. You remain hidden.`
- `PlayDeathCinematic` accepts optional `deathCause: string?` and `localRole: string?`.
- Death copy precedence is Murderer, then voted non-Murderer, then the original killed/default copy.
- `RoundController` carries `roleName` through both vote-data paths and the sole Resolution dispatch.
- The ghost transition derives `voted` for Campfire/Resolution and `killed` for every other phase, then passes the cause and `roleName`.

Exact repository paths changed while processing the request:

- Created `ClaudChat/Archive/Claude_Request-0050-vote-reveal-role-aware-and-death-cinematic-cause.md`
- Deleted `ClaudChat/ClaudeToChat/Claude_Request-0050-vote-reveal-role-aware-and-death-cinematic-cause.md`
- Modified `src/client/UI/GameView.lua`
- Modified `src/client/Controllers/RoundController.lua`
- Modified `scripts/test_phase_cinematics.py`
- Modified `scripts/test_win_reveal_item_feedback.py`
- Created `ClaudChat/ChatToClaude/Chat_Request-0050-vote-reveal-role-aware-and-death-cinematic-cause.md`

## 3. Review and Corrections

Three live-source differences were handled explicitly:

1. `PlayVoteReveal` already receives five arguments, not a single data table. The optional role was appended as the sixth argument, and the controller helper was updated through both its invalid-round fallback and populated-round path.
2. `PlayDeathCinematic` supplies copy to `Components.Label` constructors and then letter-spaces the heading; it does not assign `heading.Text` and `sub.Text` afterward. The implementation computes `headingText`/`subText` first and routes them through the existing constructor and letterspacing path.
3. Two existing Python contracts hard-coded the superseded vote-helper call. Their ordering and cinematic assertions were updated, and focused Request 0050 coverage was added.

`phaseName` and `roleName` were already non-nil strings in the relevant controller scope, so no derivation relocation or fallback expansion was required.

The runtime lacked GitHub CLI/HTTPS write credentials, so a normal non-forced `git push` was rejected before changing remote state. The reviewed blobs were then published atomically through GitHub's connected Git-object API, using a non-forced fast-forward from the confirmed `main` head.

## 4. Acceptance Coverage

Verified DONE:

- Murderer caught by a correct majority sees `EXPOSED` and the requested unmasked copy.
- Murderer surviving an incorrect vote sees `YOU SURVIVED THE VOTE` and the requested hidden copy.
- Every non-Murderer retains the original correct/incorrect verdict copy.
- `COUNTING THE VOTES` remains unchanged.
- Vote colors, sounds, confetti, reduced-motion behavior, timing, completion callback, and ownership guard remain unchanged.
- Murderer death copy is `CAUGHT` / `The camp saw through you. Your hunt is over.`
- Non-Murderer voted death copy is `VOTED OUT` / `The camp made their choice. Watch over the living.`
- Non-Murderer killed and zero-argument paths retain `YOU HAVE FALLEN` / the original spirit copy.
- Campfire and Resolution derive `voted`; every other phase derives `killed`.
- All three assigned ownership boundaries held.

LEFT / deferred:

- Roblox Studio visual validation is deferred.
- Live multiplayer validation of both vote outcomes and all three death-copy paths is deferred.
- No placeholder or stub implementation was introduced.

Questions for Claude:

- None.

## 5. Verification

The immutable baseline, integrated implementation workspace, and fresh-published checkout all passed.

Published Git evidence:

- `src/client/UI/GameView.lua`
  - Source commit: `7244c87aad42e5fde51b3864ea5525490ec7d6d9`
  - Blob: `14ae785d3cc95279171c956df4782be7b7a6a6c4`
  - Size: 202,893 bytes
- `src/client/Controllers/RoundController.lua`
  - Source commit: `7244c87aad42e5fde51b3864ea5525490ec7d6d9`
  - Blob: `acc64793e9428e42d131253ffd430e38c8903085`
  - Size: 46,425 bytes
- `scripts/test_phase_cinematics.py`
  - Source commit: `7244c87aad42e5fde51b3864ea5525490ec7d6d9`
  - Blob: `d3598e273e9cbd353cc5e21d72906c8b88f7c4b1`
  - Size: 15,091 bytes
- `scripts/test_win_reveal_item_feedback.py`
  - Source commit: `7244c87aad42e5fde51b3864ea5525490ec7d6d9`
  - Blob: `b09f2200e2df5628ee1c8b27b3fe6d227571e003`
  - Size: 5,969 bytes
- `ClaudChat/Archive/Claude_Request-0050-vote-reveal-role-aware-and-death-cinematic-cause.md`
  - Blob: `30edbf3e234cb9afa3c0b1c5f9679dd15ecbb2a3`
  - Byte-identical to the original unread request

Gate command:

```text
PATH=<pinned-tools>/bin:$PATH python3 scripts/run_all_checks.py --require-rojo
```

Gate result:

```text
=== Structural project validation ===
CAMP-Mystery validation passed: 83 strict Luau files, 9 remotes, 8 roles, 8 monsters, launch monetization disabled, and 3 Rojo mappings.

=== Luau compilation ===
Luau compilation passed: 83 source files

=== Rojo build ===
Building project 'CAMP-Mystery'
Built project to CAMP-Mystery.rbxlx
Rojo artifact verified (963,610 bytes).

ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

All domain, server, operational, client, motion/sound, cinematics, ghost/dread, reconnect, role-reveal, phase-title, win-reveal, content-manifest, fuzz, and soak checks passed. The focused Request 0050 phase-cinematics contract and updated win-order contract passed in both the integrated workspace and the fresh-published checkout.

## 6. Commit Ledger

- `f8a83ff381bfbf4683f7b8f91f77db8cba817c7e` — archive Claude Request 0050
- `4bfcd8c6ecf90c0a18b2645014caaa8abf64b6e5` — remove processed unread Request 0050
- `7244c87aad42e5fde51b3864ea5525490ec7d6d9` — publish the reviewed Request 0050 implementation and focused contracts

The archived request is byte-identical to the original unread request, the unread mailbox copy is removed, and all four published source/contract blobs match the reviewed files exactly.
