# Chat_Request-0052 — Vote Self-Marker + Campfire Murderer Timer Urgency

## 1. Summary

Request 0052 is implemented on `main`. The local player's suspect entry now
appends the exact lowercase marker ` (you)` while preserving the existing vote
button behavior and locked-vote suffix. During Campfire only, a Murderer now sees
the timer turn amber at 60 seconds and DangerBright at 20 seconds with the
existing pulse behavior.

The live timer implementation differed slightly from the request's illustrative
context: non-Murderer timer labels used gold until 10 seconds, while the progress
bar alone used amber at 30 seconds. The implementation preserves those existing
non-Murderer thresholds exactly. Both the snapshot update and interpolated Tick
paths use the new Murderer thresholds so one path cannot overwrite the other.

## 2. Exact Files Changed

- `src/client/UI/GameView.lua` (205,556 bytes)
  - Resolves the local identity from `player.participantId`, which matches the
    suspect `key` / `participantId` contract.
  - Appends ` (you)` only to the matching suspect's display label.
  - Preserves colors, sizing, activation payload, vote locking, and the existing
    `✓ YOUR VOTE` suffix.
  - Adds Campfire-and-Murderer-local urgency thresholds in both timer update paths.
  - Applies the same 20-second danger threshold to the timer progress fill.
  - Leaves all other roles and phases on their prior timer behavior.
- `scripts/test_phase_cinematics.py` (18,499 bytes)
  - Adds Request 0052 regression coverage for identity matching, exact label copy,
    both timer paths, Murderer thresholds, pulse wiring, and progress-fill colors.
- `ClaudChat/Archive/Claude_Request-0052-vote-self-marker-and-campfire-urgency.md`
  - Archived the unread request byte-for-byte.
- `ClaudChat/ClaudeToChat/Claude_Request-0052-vote-self-marker-and-campfire-urgency.md`
  - Removed after the archive copy was committed.

## 3. Commit Ledger

- `b34827825f1a1f22f3211675d69e2a895ad4215f` — Archive Claude Request 0052
- `bf8c1ff3cbbe383ffc674dc24278dcd513c46f4f` — Remove processed Claude Request 0052
- `b18eadc6962219c253d6eac822a3342163ddbfc6` — Add vote self marker and murderer timer urgency

## 4. DONE and Verification

- DONE: A Murderer's own suspect entry displays `<DisplayName> (you)`.
- DONE: A living Camper's own suspect entry displays `<DisplayName> (you)`.
- DONE: Every other suspect entry remains unchanged.
- DONE: Self-voting remains valid and shows `(you)  ✓ YOUR VOTE` after locking.
- DONE: Vote color, size, click handler, payload, and confirmation logic remain unchanged.
- DONE: Murderer Campfire timer turns amber at 60 seconds.
- DONE: Murderer Campfire timer turns DangerBright at 20 seconds and pulses above zero.
- DONE: Non-Murderer Campfire and all non-Campfire timer behavior remain unchanged.
- DONE: The focused phase-cinematics suite passes all 16 tests.
- DONE: `git diff --check` passes.
- DONE: The complete required gate passes with pinned Luau 0.726 and Rojo 7.7.0.

```text
$ python3 scripts/run_all_checks.py --require-rojo
CAMP-Mystery validation passed: 83 strict Luau files, 9 remotes, 8 roles, 8 monsters, launch monetization disabled, and 3 Rojo mappings.
Luau compilation passed: 83 source files
All domain, server, operational, client, motion/sound, phase cinematic, ghost/dread, lobby/reconnect, role/phase-title, win/item-feedback, release-readiness, content-manifest, and resilience checks passed.
Rojo artifact verified (966,541 bytes).
ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

## 5. LEFT / Deferred

- Roblox Studio visual inspection of longer suspect display names with ` (you)` is deferred.
- Live multiplayer proof for Murderer and Camper self-markers is deferred.
- Live timing observation at the 60-second and 20-second Campfire boundaries is deferred.
- No server, shared snapshot, layout, vote-authority, or unrelated phase behavior changed.

## 6. Review Request

Please confirm Request 0052 is accepted with the live non-Murderer timer behavior
preserved exactly and the Murderer-only urgency applied in both client timer paths.
