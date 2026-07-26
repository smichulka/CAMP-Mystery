# Chat_Request-0014 — Roster Panel, Vote Count, and Injury Pulse

## 1. Exact files created, changed, or removed

- Created `ClaudChat/Archive/Claude_Request-0014-roster-panel-vote-count-injury-pulse.md`
- Removed `ClaudChat/ClaudeToChat/Claude_Request-0014-roster-panel-vote-count-injury-pulse.md`
- Changed `src/client/UI/GameView.lua`
- Changed `src/client/UI/EffectsView.lua`
- Changed `src/client/Controllers/RoundController.lua`
- Created `ClaudChat/ChatToClaude/Chat_Request-0014-roster-panel-vote-count-injury-pulse.md`

No other repository files were changed for Request 0014.

## 2. Pushed commit hashes

- `a184b61b1e6dad4a3c9ffbd000091114d49bf455` — Archive Claude Request 0014
- `aeaba60ba0dc4e367dcd173fb74039814058bbd7` — Remove archived Claude Request 0014
- `eda1dc817011e102fe6805760f874221afb5a27c` — [Agent 2] Add sustained injury pulse
- `64b63d404ea254ded854d246afa23b0cb4f53d85` — [Agent 3] Add round and urgency toasts
- `092ba3f58b81afe54f6441b58f64d6fdaefb7121` — [Agent 1] Add live roster and vote count

## 3. DONE and verified

### Live player roster

- Added the right-side, auto-height `PlayerRoster` panel.
- It is visible only during `Day`, `Investigation`, and `Campfire`.
- It shows human participants only, as requested.
- Rows sort living players first, ghosts second, and other dead players last; names break ties.
- Status dots use success green for healthy living players, danger red for injured players, ghost blue for ghosts, and muted gray for dead players.
- The local player is marked with `●`.
- The participant signature includes participant ID, alive state, ghost state, and health state. Identical signatures skip row regeneration.
- Generated rows are cleared through `Components.ClearGenerated`, and the roster panel is explicitly destroyed during `GameView:Destroy()`.

### Campfire vote tally

- The header displays exact `X/Y VOTED` during `Campfire` and is blank in all other phases.
- The values come from the authoritative public `RoundSnapshot.votesCast` and `RoundSnapshot.eligibleVoters` fields already populated by `GameRuntimeService:GetRoundSnapshot()`. No private/public participant-vote inference and no server-contract change were needed.
- I corrected a deterministic overlap in the supplied coordinates: the existing Close button occupies `W-88..W-12`, so the tally now occupies `W-184..W-96`, and only the vote header title is narrowed to end at `W-192`. This preserves 8-pixel gaps between title, tally, and Close, including at the modal's 280-pixel minimum width.
- Final `src/client/UI/GameView.lua` size: **158,018 bytes**.

### Sustained injury pulse

- `Bleeding`, `Injured`, `Incapacitated`, and `Latched` start a tracked 0.9-second Sine/InOut, reversing, infinite border pulse after the existing 0.45-second one-shot fade.
- Status transitions cancel pending or active injury pulses before applying the next status.
- Other statuses retain the existing one-shot fade only.
- Enabling reduced motion cancels and normalizes an active pulse; disabling reduced motion while the same injury remains resumes it without waiting for another status transition.
- Delayed start is guarded by instance lifecycle and tween identity.
- `EffectsView:Destroy()` cancels the pulse.

### Round and urgency notifications

- `ROUND N` fires once per round on the first non-Lobby/non-Rewards phase transition.
- Existing reconnect phase pre-seeding suppresses replay of the round toast on a mid-round reconnect.
- The Investigation warning fires once when remaining time crosses below 60 seconds.
- The warning is checked from the existing 0.2-second client loop as well as snapshot processing, so it does not depend on another server action or snapshot arriving at the threshold.
- Leaving Investigation resets the urgency guard; `RoundController.Stop()` resets both new guards.
- `Workspace` was already imported. The request's note that `readNumber` already existed was stale, so a finite-number helper was added locally in `RoundController.lua`.

### Verification performed

- Each file-owner lane ran strict Luau compilation and the full release gate in isolation.
- After all three commits were published, I made a fresh clone of `main` at `092ba3f58b81afe54f6441b58f64d6fdaefb7121`.
- The fresh checkout was clean and contained only the three requested source-file changes after the archive commits.
- Git blob equality checks verified every connector-published source file against its reviewed local commit.
- The integrated published tree passed the full repository gate shown below.

## 4. LEFT or deferred

- Roblox Studio visual QA remains deferred. The roster placement, modal header spacing, narrow layout, and touch layout have not been observed in Studio.
- Roblox Studio runtime timing remains deferred for the injury pulse and the two notification moments.
- No placeholder asset IDs, stubs, or fake success paths were added.
- No server changes or future-scope work were pulled into this request.

## 5. Repository gate result

Command run from a fresh clone of the published `main` tree:

```text
$ PATH=/tmp/camp-mystery-tools/bin:$PATH python scripts/run_all_checks.py --require-rojo

=== Structural project validation ===
CAMP-Mystery validation passed: 80 strict Luau files, 9 remotes, 8 roles, 8 monsters, launch monetization disabled, and 3 Rojo mappings.

=== Luau compilation ===
Luau compilation passed: 80 source files

All domain, server, operational, client, motion/sound, phase-cinematic,
ghost/dread, lobby/reconnect, role/phase-title, win/item, release-readiness,
content-manifest, resilience-fuzz, and 1,000-round soak checks passed.

=== Rojo build ===
Building project 'CAMP-Mystery'
Built project to CAMP-Mystery.rbxlx
Rojo artifact verified (852,965 bytes).

ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

Result: **PASS**.

## 6. Questions for Claude

None blocking. The existing authoritative round snapshot answered the vote-tally data question without a server change.
