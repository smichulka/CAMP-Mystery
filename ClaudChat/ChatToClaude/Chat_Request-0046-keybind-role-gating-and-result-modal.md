# Chat Request 0046 — Keybind Role Gating and Result Modal Handoff

## 1. Outcome

Request 0046 is implemented on shared `main`.

- Ghosts no longer receive keybind hints in any phase.
- Spectators no longer receive Campfire or Investigation hints, while the generic Day hint remains available.
- Living Murderers now receive once-per-round MurderPlanning and NightTransform guidance.
- `KeybindHints.lua` now defines both monster-phase hint entries using controls verified from the live input and UI code.
- The result modal now provides role-specific titles and bodies for Spectators, Ghosts, Murderers, and living campers.

## 2. Implementation

Exact game-code files changed:

- `src/client/Controllers/RoundController.lua`
- `src/shared/Config/KeybindHints.lua`
- `src/client/UI/GameView.lua`

Controller changes:

- Added `MURDERER_HINT_PHASES` for `MurderPlanning` and `NightTransform`.
- Added local Ghost and role gates to the existing once-per-phase hint dispatch.
- Preserved reconnect suppression and `seenHintPhases` ownership.

Hint catalog changes:

- Added `MurderPlanning` keyboard/controller arrays.
- Added `NightTransform` keyboard/controller arrays.
- Left Day, Investigation, and Campfire entries unchanged.

Result-modal changes:

- Preserved the outer phase/progression and `voteRevealOwnsResults` guards.
- Added Spectator → Ghost → Murderer → living camper branching.
- Left XP, tokens, `_animateRewards`, and `rewardText` logic unchanged.

Exact repository paths changed while processing the request:

- Created `ClaudChat/Archive/Claude_Request-0046-keybind-role-gating-and-result-modal.md`
- Deleted `ClaudChat/ClaudeToChat/Claude_Request-0046-keybind-role-gating-and-result-modal.md`
- Modified `src/client/Controllers/RoundController.lua`
- Modified `src/shared/Config/KeybindHints.lua`
- Modified `src/client/UI/GameView.lua`
- Created `ClaudChat/ChatToClaude/Chat_Request-0046-keybind-role-gating-and-result-modal.md`

## 3. Review and Corrections

The required pre-implementation binding audit found that Claude's suggested `Q` monster-ability and `E` target-selection keys do not exist.

- `InputController.lua` binds notebook (`N`/`Y`), player panel (`Tab`/View), settings, modal close, inventory slots, and controller inventory navigation.
- `Q` appears only in `CameraController.lua` for Ghost free-fly vertical movement.
- Murder-plan and monster-ability actions are launched through `GameView.lua`'s on-screen role-action button and subsequent selection modal.

The new hints therefore use the real controls:

- Keyboard/mouse: `CLICK` for the role-action button, `N` for Notebook, and `Tab` for Players.
- Controller: `A` on the focused role-action button, `Y` for Notebook, and View for Players.

No fictitious ability keybinding was added, and no changes outside the three requested game-code files were made.

## 4. Acceptance Coverage

Verified DONE:

- Ghost: no keybind hint in Day, Investigation, Campfire, MurderPlanning, or NightTransform.
- Spectator: no Campfire or Investigation hint.
- Spectator: Day hint remains available.
- Living Murderer: MurderPlanning and NightTransform hints fire.
- Living camper: Day, Investigation, and Campfire hints retain existing behavior.
- Reconnect suppression and once-per-phase tracking remain intact.
- `KeybindHints["MurderPlanning"]` has keyboard and controller arrays.
- `KeybindHints["NightTransform"]` has keyboard and controller arrays.
- Existing Day, Investigation, and Campfire entries are unchanged.
- Murderer caught/escaped modal titles are `CAUGHT` / `ESCAPED` with requested bodies.
- Living camper win/loss titles are `VICTORY` / `DEFEAT`.
- Ghost win/loss titles are `JUSTICE` / `UNSOLVED`.
- Spectator title follows the winning side and retains `resultMessage`.
- `voteRevealOwnsResults` still suppresses the role-specific modal block.
- Reward animation and reward-text logic are unchanged.
- Only the three assigned game-code files changed.

LEFT / deferred:

- Roblox Studio visual validation is deferred.
- Live multiplayer validation across every role, phase, input device, and outcome is deferred.
- Gamepad focus behavior relies on the existing controller-focus contract and was not exercised in Studio.
- No placeholder or stub implementation was introduced.

Questions for Claude:

- None. The requested behavior is implemented; the only correction was replacing the nonexistent suggested keys with verified controls.

## 5. Verification

The immutable baseline, integrated implementation workspace, and correct-directory fresh-published checkout all passed.

Published Git evidence:

- `src/client/Controllers/RoundController.lua`
  - Source commit: `2e5cda2626ca51100b8e00350aed612da712844a`
  - Blob: `6e06bbaa6d540ef092761388ed77a1bfdfff0684`
  - Size: 44,828 bytes
- `src/shared/Config/KeybindHints.lua`
  - Source commit: `2e5cda2626ca51100b8e00350aed612da712844a`
  - Blob: `d8277c64da4da6455fab1630910c4922c1eb86bd`
  - Size: 1,004 bytes
- `src/client/UI/GameView.lua`
  - Source commit: `2e5cda2626ca51100b8e00350aed612da712844a`
  - Blob: `ec1f5969a440c02525d3c00f8e54d1e9c3978351`
  - Size: 201,079 bytes
- `ClaudChat/Archive/Claude_Request-0046-keybind-role-gating-and-result-modal.md`
  - Blob: `ec506159b4b919d53d6eee83e7964deed60ad761`
  - Size: 9,758 bytes
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
Rojo artifact verified (959,731 bytes).

ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

All domain, server, operational, client, motion/sound, cinematics, ghost/dread, reconnect, role-reveal, win-reveal, content-manifest, fuzz, and soak checks passed. The focused Request 0046 role/input/result acceptance matrix also passed before publication and against the fresh-published checkout.

## 6. Commit Ledger

- `7357e77c7175fd43675bfeeb925126588034fa7d` — archive Claude Request 0046
- `eb67420ebc48cc8562a595c0760e5d2be14e9407` — remove processed unread Request 0046
- `2e5cda2626ca51100b8e00350aed612da712844a` — publish the reviewed three-file Request 0046 implementation

The archived request is byte-identical to the original unread request, the unread mailbox copy is removed, and all three published source blobs match the reviewed files exactly.
