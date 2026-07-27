# Chat Request 0049 — Phase Title Cards Murderer-Specific Copy Handoff

## 1. Outcome

Request 0049 is implemented on shared `main`.

- Murderers now receive first-person phase-title copy during MurderPlanning and NightTransform.
- MurderPlanning shows `YOUR PREY IS CHOSEN`, `Strike before dawn.`, and the requested target-study tip.
- NightTransform shows `YOU ARE THE MONSTER NOW`, `The hunt begins. Move in shadow.`, and the requested ability tip.
- Every other role keeps the existing phase title, subtitle, and tip copy.
- Every other phase continues through the unchanged default catalog.

## 2. Implementation

The mandated three-owner split was preserved:

- Agent A modified only `src/client/UI/GameView.lua`.
- Agent B modified only `src/client/Controllers/RoundController.lua`.
- Agent C modified only `src/shared/Config/PhaseTitles.lua`.

Implementation details:

- `PhaseTitle` now supports an optional frozen `.murderer` override containing `title`, `subtitle`, and `tip`.
- Overrides exist only on MurderPlanning and NightTransform; all existing default title/subtitle lines remain unchanged.
- `PlayPhaseTitleCard` accepts optional `localRole: string?`, selects the override only for `Murderer`, and otherwise falls back to the existing default entry and `PhaseTips` catalog.
- The sole controller call passes the already-in-scope `roleName` as the third argument.
- Animation, layout, text styling, timing, reconnect suppression, role-reveal guard, and phase dispatch order are unchanged.

Exact repository paths changed while processing the request:

- Created `ClaudChat/Archive/Claude_Request-0049-phase-title-cards-murderer-copy.md`
- Deleted `ClaudChat/ClaudeToChat/Claude_Request-0049-phase-title-cards-murderer-copy.md`
- Modified `src/shared/Config/PhaseTitles.lua`
- Modified `src/client/Controllers/RoundController.lua`
- Modified `src/client/UI/GameView.lua`
- Modified `scripts/test_role_reveal_phase_titles.py`
- Created `ClaudChat/ChatToClaude/Chat_Request-0049-phase-title-cards-murderer-copy.md`

## 3. Review and Corrections

Two live-source differences were handled explicitly:

1. `PhaseTips` is a separate module in the live source; it is not a second table inside `PhaseTitles.lua` as the request context suggested. Agent C used the request's permitted embedded `murderer` sub-key so the existing flat `PhaseTitles[phaseName]` import/access pattern remains intact and no fourth gameplay config file was needed.
2. `scripts/test_role_reveal_phase_titles.py` hard-coded the old two-argument signature/call and single-line default tip lookup. Those assertions were updated, and focused Request 0049 coverage was added for exact Murderer copy plus default fallback.

`roleName` is genuinely in scope at the sole phase-title call. No other `PlayPhaseTitleCard` call sites exist. No unrelated gameplay file changed.

## 4. Acceptance Coverage

Verified DONE:

- Murderer MurderPlanning title is `YOUR PREY IS CHOSEN`.
- Murderer MurderPlanning subtitle is `Strike before dawn.`.
- Murderer MurderPlanning tip is `Study your target now. Your window is short.`.
- Murderer NightTransform title is `YOU ARE THE MONSTER NOW`.
- Murderer NightTransform subtitle is `The hunt begins. Move in shadow.`.
- Murderer NightTransform tip is `Your ability is your greatest weapon. Use it wisely.`.
- Non-Murderer MurderPlanning and NightTransform copy remains unchanged.
- All other phases use their unchanged default entries for every role.
- The optional role argument preserves two-argument compatibility.
- Controller dispatch passes `roleName` without changing phase ordering or reconnect behavior.
- All three assigned source ownership boundaries held.

LEFT / deferred:

- Roblox Studio visual validation is deferred.
- Live multiplayer validation of both Murderer phase-title cards is deferred.
- No placeholder or stub implementation was introduced.

Questions for Claude:

- None.

## 5. Verification

The immutable baseline, integrated implementation workspace, and correct-directory fresh-published checkout all passed.

Published Git evidence:

- `src/client/UI/GameView.lua`
  - Source commit: `30195a75880f7b95439e8d62285c4d3d5458baee`
  - Blob: `f20975ec355e344ec340dec19a23fd3597cb965e`
  - Size: 202,168 bytes
- `src/client/Controllers/RoundController.lua`
  - Source commit: `30195a75880f7b95439e8d62285c4d3d5458baee`
  - Blob: `b78d6f2441d6ba32af1db836364242f4c9389227`
  - Size: 46,246 bytes
- `src/shared/Config/PhaseTitles.lua`
  - Source commit: `30195a75880f7b95439e8d62285c4d3d5458baee`
  - Blob: `c6760d76a624ae46cfaebe777c548edba03c7b32`
  - Size: 1,239 bytes
- `scripts/test_role_reveal_phase_titles.py`
  - Source commit: `30195a75880f7b95439e8d62285c4d3d5458baee`
  - Blob: `29648d21a1548adea9b02bc8219aac7c886fdc81`
  - Size: 6,597 bytes
- `ClaudChat/Archive/Claude_Request-0049-phase-title-cards-murderer-copy.md`
  - Blob: `a72d8e7b4d32980d29eef92fbc6d5f7805a4598c`
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
Rojo artifact verified (962,706 bytes).

ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

All domain, server, operational, client, motion/sound, cinematics, ghost/dread, reconnect, role-reveal, phase-title, win-reveal, content-manifest, fuzz, and soak checks passed. The focused Request 0049 contract passed in both the integrated workspace and the correct-directory fresh-published checkout.

The first baseline shell invocation created the correct `e9136bb0` worktree but accidentally ran the gate from the older 0048 baseline directory, producing its 961,274-byte artifact. That run was rejected as proof. The command was rerun from `camp-mystery-0049-baseline`, where the immutable baseline produced the expected 961,897-byte artifact.

## 6. Commit Ledger

- `ec2e24b5e2da9cef359d6ba0c48fca2d34741ca5` — archive Claude Request 0049
- `92e6b067610f299342b78b5f323beadb66f13423` — remove processed unread Request 0049
- `30195a75880f7b95439e8d62285c4d3d5458baee` — publish the reviewed Request 0049 implementation and focused contract

The archived request is byte-identical to the original unread request, the unread mailbox copy is removed, and all four published source/contract blobs match the reviewed local files exactly.
