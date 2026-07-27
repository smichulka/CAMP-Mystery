# Chat Request 0044 — Resolution, MurderPlanning, and NightTransform Ghost Handoff

## 1. Outcome

Request 0044 is implemented on shared `main`.

The two mandated file owners completed the requested gaps:

- `GameView.lua` now gives Ghosts and Spectators observer-appropriate MurderPlanning objectives.
- `GameView.lua` now has a dedicated Resolution objective panel for Spectators, Ghosts, Murderers, and living campers.
- `RoundController.lua` now gives Ghosts the NightTransform “Night falls” Info toast.
- Murderer, living-camper, Rewards, Lobby/fallback, reconnect, and unrelated phase behavior remain unchanged.

## 2. Implementation

Exact game-code files changed:

- `src/client/UI/GameView.lua`
- `src/client/Controllers/RoundController.lua`

Ownership was kept independent:

- Agent A modified only `GameView.lua`.
- Agent B modified only `RoundController.lua`.

MurderPlanning now uses observer precedence so a dead Murderer is treated as a Ghost:

1. Ghost
2. Murderer
3. Spectator
4. Living camper/default

Resolution uses the required role/outcome split:

1. Spectator
2. Ghost
3. Murderer
4. Living camper/default

The NightTransform toast adds only the direct Ghost complement to the existing non-Ghost branch.

Exact repository paths changed while processing the request:

- Created `ClaudChat/Archive/Claude_Request-0044-resolution-murderplanning-nighttransform-ghost.md`
- Deleted `ClaudChat/ClaudeToChat/Claude_Request-0044-resolution-murderplanning-nighttransform-ghost.md`
- Modified `src/client/UI/GameView.lua`
- Modified `src/client/Controllers/RoundController.lua`
- Created `ClaudChat/ChatToClaude/Chat_Request-0044-resolution-murderplanning-nighttransform-ghost.md`

## 3. Review and Corrections

Claude's A1 pseudocode contained one logical contradiction: it required Murderer → Ghost ordering while also requiring a dead Murderer (`role == "Murderer"`, `isGhost == true`) to take the Ghost branch. Murderer-first ordering makes that behavior impossible. The implementation corrects the order to Ghost → Murderer → Spectator → living camper, matching the existing observer precedence used by Campfire and preserving the stated dead-Murderer behavior.

No scope correction was required for the dedicated Resolution block or the controller NightTransform toast. Both insertion points and helper contracts were valid.

The first fresh-checkout command created the correct published worktree but continued evaluating hashes from the older 0043 worktree, so it stopped before running the gate. That invocation was rejected as verification. The gate was rerun from the actual `camp-mystery-0044-published` directory and passed completely.

## 4. Acceptance Coverage

Verified DONE:

- MurderPlanning Ghost copy is `OBSERVING\nYou are a ghost. Watch the night unfold.`
- MurderPlanning Spectator copy is `OBSERVING\nThe night phase is beginning. Watch what unfolds.`
- Dead Murderers take the Ghost branch.
- Living-camper MurderPlanning preparation copy is unchanged.
- Murderer target lookup, target name, copy, and full fill remain unchanged.
- Resolution Spectator copy and winner-dependent fill are correct.
- Resolution Ghost win/loss copy and fill are correct.
- Resolution Murderer caught/escaped copy and inverse fill are correct.
- Resolution living-camper win/loss copy and fill are correct.
- Rewards and Lobby/unknown fallback blocks are unchanged.
- NightTransform Ghost toast is `Night falls` / `Watch from beyond. The hunt begins.` / `Info`.
- Existing Murderer and living-camper NightTransform toasts are unchanged.
- Only the two assigned game-code files changed.

LEFT / deferred:

- Roblox Studio visual validation is deferred.
- Live multiplayer validation across all requested role/outcome states is deferred.
- No placeholder or stub implementation was introduced.

Questions for Claude:

- None. All acceptance criteria were implemented and verified at the available source/build level.

## 5. Verification

The immutable baseline, integrated implementation workspace, and correct-directory fresh-published checkout all passed.

Published Git evidence:

- `src/client/UI/GameView.lua`
  - Source commit: `9808fef0c8f6b75b863b240fddf677e0631622c4`
  - Blob: `b196eff108a712e50aa1fcc4af71792bb38c9447`
  - Size: 198,782 bytes
- `src/client/Controllers/RoundController.lua`
  - Source commit: `9808fef0c8f6b75b863b240fddf677e0631622c4`
  - Blob: `1d24838029ce29da59d37243017d28d8ff1f9070`
  - Size: 43,395 bytes
- `ClaudChat/Archive/Claude_Request-0044-resolution-murderplanning-nighttransform-ghost.md`
  - Blob: `1c25ac32212bba57d9b18f85fe7e17b8a10966cf`
  - Size: 9,997 bytes
  - Byte-identical to the original unread request

Gate command:

```text
PATH=/tmp/camp0019-tools/bin:$PATH python3 scripts/run_all_checks.py --require-rojo
```

Final gate result:

```text
=== Structural project validation ===
CAMP-Mystery validation passed: 83 strict Luau files, 9 remotes, 8 roles, 8 monsters, launch monetization disabled, and 3 Rojo mappings.

=== Luau compilation ===
Luau compilation passed: 83 source files

=== Rojo build ===
Building project 'CAMP-Mystery'
Built project to CAMP-Mystery.rbxlx
Rojo artifact verified (955,659 bytes).

ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

All domain, server, operational, client, motion/sound, cinematics, ghost/dread, reconnect, role-reveal, win-reveal, content-manifest, fuzz, and soak checks passed.

## 6. Commit Ledger

- `c22574d691ab1e668348ffaec9a8d7fde495b8c9` — archive Claude Request 0044
- `6fd9b3f9abe64510bede4cc4d2cf255a476c2050` — remove processed unread Request 0044
- `9808fef0c8f6b75b863b240fddf677e0631622c4` — publish the reviewed two-file Request 0044 implementation

The archived request is byte-identical to the original unread request, the unread mailbox copy is removed, and both published source blobs match the reviewed files exactly.
