# Chat_Request-0037 — All Votes Cast Notification

## 1. Status

Complete and published to shared `main`.

## 2. Implementation

Updated only `src/client/Controllers/RoundController.lua`, as assigned.

- Added `lastVoteCompleteRound` tracking.
- Added a Warning notification when a Campfire vote first reaches its eligible-voter total.
- Prevented repeats across later complete-vote snapshots in the same round.
- Prevented alerts for reconnect snapshots and zero eligible voters.
- Seeded completed-vote state silently during reconnect.
- Reset the tracker in `RoundController.Stop()`.

## 3. Corrections and Decisions

Two source-order assumptions in the request required narrow placement corrections:

- `roundNumber` is derived after `lastObjectivesCompleted`, so the notification block was placed immediately after the existing `roundNumber` derivation.
- `reconnectRound` is declared after `lastRoleRevealRound`, so reconnect vote seeding was placed immediately after `reconnectRound` is declared.

These changes preserve the requested behavior without expanding the one-file source boundary.

## 4. Commit Ledger

- `bef449fa9b91e6b63cf47e0c705e6b3153b22f59` — archived Request 0037.
- `6d74cf583c315d65d245222941ab12babb4a1da6` — removed the processed unread request.
- `0a3b66704e75f05fdc0fc3f7fde02c011190534e` — added the all-votes-cast Campfire notification.

Published `RoundController.lua` is 41,266 UTF-8 bytes with Git blob `087e2991d3c796ff8e6f6ef2a599c8656379ad87`.

## 5. Verification

`PATH=/tmp/camp0019-tools/bin:$PATH python3 scripts/run_all_checks.py --require-rojo`

Passed from a clean published worktree at `0a3b6670`:

- Structural validation: 83 strict Luau files.
- Luau compilation: 83 files passed.
- All domain, server, operational, client, motion/sound, cinematic, ghost/dread, reconnect, role/phase, win/item, release-readiness, and resilience checks passed.
- Focused Request 0037 acceptance checks passed in the reviewed implementation workspace.
- Deterministic Rojo build: 948,937 bytes.

An initial fresh-check command accidentally ran from the older 0036 checkout and produced its 947,943-byte artifact. It was rejected as evidence; the command was rerun from the actual `camp-mystery-0037-published` worktree with HEAD and blob checks shown above.

## 6. Deferred Validation

Roblox Studio visual QA and live multiplayer vote-completion testing remain deferred. Automated and correct-directory fresh-published verification are green.
