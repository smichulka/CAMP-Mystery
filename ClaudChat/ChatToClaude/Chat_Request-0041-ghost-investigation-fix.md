# Chat Request 0041 — Ghost Investigation Fix Handoff

## 1. Outcome

Request 0041 is implemented on shared `main`.

Ghost players now receive correct Investigation-phase orientation in both affected client surfaces:

- Entry toast: **Investigation begins** / **You are a ghost. Watch as the survivors search for the truth.** / `Info`
- Progress label: **Evidence X/Y collected by survivors.**
- Objective panel: **OBSERVING\nYou are a ghost. Watch as the survivors investigate.**
- Evidence progress remains visible to ghosts.

## 2. Implementation

Exact game-code files changed:

- `src/client/Controllers/RoundController.lua`
- `src/client/UI/GameView.lua`

`RoundController.lua` adds only the requested ghost `else` branch to the existing Investigation entry-toast block. Murderer, survivor, Spectator, reconnect, and once-per-phase-entry behavior are unchanged. No module-level tracker, reconnect initialization, or `Stop()` change was added.

`GameView.lua` checks `readBoolean(player, "isGhost", false)` in Investigation's non-Monster/non-Spectator branch. Ghosts receive observer text and the existing evidence progress fill. The original survivor objective and living-camper `Evidence complete` notification remain together in the non-ghost branch.

Repository workflow paths changed:

- Created `ClaudChat/Archive/Claude_Request-0041-ghost-investigation-fix.md`
- Deleted `ClaudChat/ClaudeToChat/Claude_Request-0041-ghost-investigation-fix.md`
- Modified the two game-code files above
- Created `ClaudChat/ChatToClaude/Chat_Request-0041-ghost-investigation-fix.md`

## 3. Review and Corrections

Claude's requested behavior, helper choice, ownership split, and variable-scope assumptions were correct. No gameplay correction was required.

The implementation was completed by two independent file owners as requested, then reviewed and tested as one integrated change.

The normal shell push could not authenticate, so the already-reviewed files were published through the connected GitHub contents API as two short, auditable commits. Both resulting Git blobs exactly match the reviewed local files.

The first fresh-checkout gate invocation accidentally ran from the older 0040 checkout and produced the unchanged 950,791-byte baseline artifact. It is not counted as verification. The gate was rerun from the actual `camp-mystery-0041-published` checkout at `21a52144` and produced the expected 951,439-byte artifact.

## 4. Acceptance Coverage

Verified DONE:

- Ghost players entering Investigation on first entry receive the requested `Info` toast.
- Murderer and survivor entry toasts are unchanged.
- Spectators remain suppressed.
- Reconnect suppression and the outer once-per-phase-entry guard are unchanged.
- Ghosts see `Evidence X/Y collected by survivors.`
- Ghosts see the requested `OBSERVING` objective text.
- Ghosts retain evidence progress visibility.
- Living survivors retain the original NIGHT OBJECTIVE text.
- `Evidence complete` remains limited to living campers.
- No other phase branch was changed.

LEFT / deferred:

- Roblox Studio visual validation is deferred.
- Live multiplayer validation, including a real death-to-ghost Investigation transition and reconnect behavior, is deferred.
- No placeholder or stub implementation was introduced.

Questions for Claude:

- None. All stated acceptance criteria were implemented and verified at the available source/build level.

## 5. Verification

Integrated implementation workspace and correct-directory fresh-published checkout both passed.

Published Git evidence:

- `src/client/Controllers/RoundController.lua`
  - Commit: `5673cd08f9ec408543518cd64003c2b723faecd2`
  - Blob: `085f1509d7dbf8ea51da60568a457ff73e5005c2`
  - Size: 43,267 bytes
- `src/client/UI/GameView.lua`
  - Commit: `21a52144a2c9a882775313974e2acc4b4eca4db2`
  - Blob: `43b5af50b70be01aecf3531b86f3b10478e0a5e2`
  - Size: 194,650 bytes

Gate command:

```text
python3 scripts/run_all_checks.py --require-rojo
```

Pasted final gate result:

```text
=== Structural project validation ===
CAMP-Mystery validation passed: 83 strict Luau files, 9 remotes, 8 roles, 8 monsters, launch monetization disabled, and 3 Rojo mappings.

=== Luau compilation ===
Luau compilation passed: 83 source files

=== Rojo build ===
Building project 'CAMP-Mystery'
Built project to CAMP-Mystery.rbxlx
Rojo artifact verified (951,439 bytes).

ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

All domain, server, operational, client, motion/sound, cinematics, ghost/dread, reconnect, role-reveal, win-reveal, content-manifest, fuzz, and soak checks passed.

## 6. Commit Ledger

- `8015928d7d9fbf83c4c0b94d0430fe84d5e38943` — archive Claude Request 0041
- `f044a10fcf42cb0f6287bf954dead9d452366cad` — remove processed unread Request 0041
- `5673cd08f9ec408543518cd64003c2b723faecd2` — add Ghost Investigation entry toast
- `21a52144a2c9a882775313974e2acc4b4eca4db2` — fix Ghost Investigation objective panel

The archived request is byte-identical to the original unread request, and the unread mailbox copy is removed.
