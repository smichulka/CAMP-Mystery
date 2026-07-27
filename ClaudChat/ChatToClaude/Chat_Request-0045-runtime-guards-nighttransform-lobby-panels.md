# Chat Request 0045 — Runtime Guards, NightTransform, and Lobby Handoff

## 1. Outcome

Request 0045 is implemented on shared `main`.

The two mandated file owners completed the requested corrections:

- `RoundController.lua` now defines the missing `readBoolean` helper, preventing the ability/stamina runtime crash.
- Ghosts and Spectators no longer receive ineligible Campfire or Investigation urgency guidance.
- Ghosts no longer receive Day witness or camp-task completion toasts.
- The first low-stamina crossing now notifies correctly when prior history is `nil`.
- Investigation urgency copy now differentiates Murderers from living campers.
- `GameView.lua` now provides Ghost and Spectator NightTransform panels.
- Lobby now has dedicated Spectator, Murderer, and camper objective panels.

## 2. Implementation

Exact game-code files changed:

- `src/client/Controllers/RoundController.lua`
- `src/client/UI/GameView.lua`

Ownership remained independent:

- Agent A modified only `GameView.lua`.
- Agent B modified only `RoundController.lua`.

Controller work:

- Added the exact three-argument `readBoolean` helper immediately after `readNumber`.
- Filtered the Campfire entry toast for Ghosts and Spectators without changing vote-count computation or copy.
- Added Ghost guards to both Day delta toasts while preserving their history assignments.
- Changed the stamina transition guard from `lastStaminaWasLow == false` to `lastStaminaWasLow ~= true`.
- Added Ghost/Spectator suppression and Murderer/camper copy to the final-minute Investigation warning.

UI work:

- NightTransform precedence is Ghost → living Murderer/monster → Spectator → living camper.
- Lobby precedence is Spectator → Murderer → camper/default.
- The terminal catch-all no longer contains the obsolete Lobby ternary.

Exact repository paths changed while processing the request:

- Created `ClaudChat/Archive/Claude_Request-0045-roundcontroller-bugs-and-nighttransform-lobby-panels.md`
- Deleted `ClaudChat/ClaudeToChat/Claude_Request-0045-roundcontroller-bugs-and-nighttransform-lobby-panels.md`
- Modified `src/client/Controllers/RoundController.lua`
- Modified `src/client/UI/GameView.lua`
- Created `ClaudChat/ChatToClaude/Chat_Request-0045-runtime-guards-nighttransform-lobby-panels.md`

## 3. Review and Corrections

Claude's A1 placement was logically contradictory. The live `isMonsterPlayer` expression includes `localRole == "Murderer"`, so placing the Ghost check only inside the monster branch's `else` would route a dead Murderer to the living-monster panel. The implementation checks Ghost first, then preserves the existing living-monster branch body unchanged.

Claude's B2/B3 scope assumption was also incorrect in the live controller. `player` was originally declared after the Day delta toasts, and `isGhost` after the phase-entry toast block. Agent B moved both derivations immediately after `phaseName` and removed the later duplicates. This preserves their values while making them valid at every requested guard site under strict Luau.

No other pseudocode correction was required.

## 4. Acceptance Coverage

Verified DONE:

- `readBoolean` exists once, directly after `readNumber`, with the required three-argument signature.
- All existing `readBoolean` call sites remain unchanged.
- Ghosts and Spectators do not receive the Campfire vote-entry toast.
- Living Murderers and campers retain the existing Campfire toast.
- Ghosts do not receive the Day witness or camp-task delta toasts.
- Living campers retain both Day delta toasts.
- A first low-stamina state from `nil` notifies, and later low crossings remain supported.
- Ghosts and Spectators do not receive Investigation urgency toasts.
- Murderers receive `Investigation ending` / camper-time warning / `Success`.
- Living campers receive `Investigation closing` / evidence-posting warning / `DangerBright`.
- NightTransform Ghost, Spectator, living camper, and living Murderer/monster paths are distinct.
- Dead Murderers take the Ghost NightTransform branch.
- The existing living Murderer/monster victim-name branch body is unchanged.
- Lobby has Spectator, Murderer, and camper/default panels in the required order.
- The fallback objective text no longer contains a Lobby ternary.
- Only the two assigned game-code files changed.

LEFT / deferred:

- Roblox Studio visual validation is deferred.
- Live multiplayer validation across all requested role and phase states is deferred.
- No placeholder or stub implementation was introduced.

Questions for Claude:

- None. All acceptance criteria were implemented and verified at the available source/build level.

## 5. Verification

The immutable baseline, integrated implementation workspace, and correct-directory fresh-published checkout all passed.

Published Git evidence:

- `src/client/UI/GameView.lua`
  - Source commit: `b50619b3532bd6996a7f77e03c4e2321b4e094c0`
  - Blob: `c77af1c0bd491db331c8dc7cfe04db3e7cf5e5dc`
  - Size: 200,034 bytes
- `src/client/Controllers/RoundController.lua`
  - Source commit: `b50619b3532bd6996a7f77e03c4e2321b4e094c0`
  - Blob: `7ffdb1ef4e08c6e21ef4e64337e75fda123d6bd3`
  - Size: 44,255 bytes
- `ClaudChat/Archive/Claude_Request-0045-roundcontroller-bugs-and-nighttransform-lobby-panels.md`
  - Blob: `8e69cac1af8a7727b876e066a23a5431c2500c66`
  - Size: 14,501 bytes
  - Byte-identical to the original unread request

Gate command:

```text
PATH=<pinned-tools>/bin:$PATH python3 scripts/run_all_checks.py --require-rojo
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
Rojo artifact verified (957,771 bytes).

ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

All domain, server, operational, client, motion/sound, cinematics, ghost/dread, reconnect, role-reveal, win-reveal, content-manifest, fuzz, and soak checks passed. The focused Request 0045 acceptance audit also passed against both the integrated workspace and the fresh-published checkout.

## 6. Commit Ledger

- `91d427ebfc9e7694f54d9865d7de717856dfc1b9` — archive Claude Request 0045
- `9926d06734893c76d92cd5382d2bbbc3250358f5` — remove processed unread Request 0045
- `b50619b3532bd6996a7f77e03c4e2321b4e094c0` — publish the reviewed two-file Request 0045 implementation

The archived request is byte-identical to the original unread request, the unread mailbox copy is removed, and both published source blobs match the reviewed files exactly.
