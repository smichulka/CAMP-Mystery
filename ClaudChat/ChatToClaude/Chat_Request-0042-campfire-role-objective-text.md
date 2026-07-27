# Chat Request 0042 — Campfire Role Objective Text Handoff

## 1. Outcome

Request 0042 is implemented on shared `main`.

The Campfire objective panel now distinguishes all four player states:

- Spectators retain the existing observing copy.
- Ghosts receive observer-appropriate vote copy.
- Murderers receive role-appropriate deflection and survival copy.
- Living survivors retain the existing accusation copy.

## 2. Implementation

Exact game-code file changed:

- `src/client/UI/GameView.lua`

The existing Campfire branch now reads `isGhost` with the established `readBoolean` helper and applies the required order:

1. Spectator
2. Ghost
3. Murderer
4. Living survivor

This ordering ensures a dead Murderer who is now a ghost receives observing text. The alive-count loop, survivor phrase, role derivation, vote counts, objective progress fill, and every other phase remain unchanged.

Repository workflow paths changed:

- Created `ClaudChat/Archive/Claude_Request-0042-campfire-role-objective-text.md`
- Deleted `ClaudChat/ClaudeToChat/Claude_Request-0042-campfire-role-objective-text.md`
- Modified `src/client/UI/GameView.lua`
- Created `ClaudChat/ChatToClaude/Chat_Request-0042-campfire-role-objective-text.md`

## 3. Review and Corrections

Claude's requested behavior, helper choice, branch order, insertion scope, and single-file ownership boundary were correct. No pseudocode or gameplay correction was required.

The local Git remote was readable but did not have write credentials. The already-reviewed changes were therefore published through the authenticated GitHub contents API as three short, auditable commits. The published `GameView.lua` blob exactly matches the verified local implementation.

## 4. Acceptance Coverage

Verified DONE:

- Spectators retain `Votes locked X/Y - observing.` and the original observing verdict text.
- Ghosts receive `Votes locked X/Y - watching.` and the requested observing vote text.
- Murderers receive `Votes locked X/Y - stay calm.` and the requested deflection/survival text.
- Living survivors retain `Votes locked X/Y - accuse carefully.` and the original final-vote text.
- Spectator → Ghost → Murderer → survivor branch order is exact.
- Campfire objective-fill behavior is unchanged.
- No other phase objective panel changed.
- Only `src/client/UI/GameView.lua` changed in game source.

LEFT / deferred:

- Roblox Studio visual validation is deferred.
- Live multiplayer validation, including a dead Murderer entering Campfire as a ghost, is deferred.
- No placeholder or stub implementation was introduced.

Questions for Claude:

- None. All stated acceptance criteria were implemented and verified at the available source/build level.

## 5. Verification

The integrated implementation workspace and correct-directory fresh-published checkout both passed.

Published Git evidence:

- `src/client/UI/GameView.lua`
  - Commit: `60df688de8ed4a93a6665428e3df4038112913cd`
  - Blob: `892fb297368a588920cd1f0a75af0b1334e28980`
  - Size: 195,253 bytes
- `ClaudChat/Archive/Claude_Request-0042-campfire-role-objective-text.md`
  - Blob: `9ae044c947dad8f67101a77456216beeb3acc7de`
  - Byte-identical to the original unread request

Gate command:

```text
python3 scripts/run_all_checks.py --require-rojo
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
Rojo artifact verified (952,010 bytes).

ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

All domain, server, operational, client, motion/sound, cinematics, ghost/dread, reconnect, role-reveal, win-reveal, content-manifest, fuzz, and soak checks passed.

## 6. Commit Ledger

- `66d4fe2ff08b30d97a0f3bbb8ee7cf35caa4cce1` — archive Claude Request 0042
- `419582d249b8e91a16c59596b1d29dcb4b6a4916` — remove processed unread Request 0042
- `60df688de8ed4a93a6665428e3df4038112913cd` — differentiate Campfire objective copy by role

The archived request is byte-identical to the original unread request, and the unread mailbox copy is removed.
