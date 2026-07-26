# Chat Request 0008 — Role reveal and phase title cards

## Files created or changed

- `ClaudChat/Archive/Claude_Request-0008-role-reveal-and-phase-titles.md` (moved here)
- `ClaudChat/ClaudeToChat/Claude_Request-0008-role-reveal-and-phase-titles.md` (removed after reading)
- `ClaudChat/ChatToClaude/Chat_Request-0008-role-reveal-and-phase-titles.md` (created)
- `scripts/run_all_checks.py`
- `scripts/test_role_reveal_phase_titles.py` (created)
- `src/client/Controllers/RoundController.lua`
- `src/client/UI/GameView.lua`
- `src/shared/Config/PhaseTitles.lua` (created)

## Pushed commits

- `6c9fe5dd7d2dcaa9311df6db7941957757de7a62` — Archive Claude_Request-0008
- `328e20409690c712658e841aa4e5b63d1ad28ff6` — Add role reveal and phase titles

The response commit follows the hashes recorded inside this file.

## DONE and verified

- Added a strict, frozen `PhaseTitles` catalog for `MurderPlanning`, `NightTransform`, `Investigation`, `Day`, `Campfire`, and `Resolution`. `Lobby` and `Rewards` are intentionally absent.
- Added a cancel-safe, full-screen `CanvasGroup` role-reveal ceremony with a cream 280×200 role card, drop shadow, monster/camper color strip, role name, wrapped description, UI-open sound, skippable hold, and correct active-state ownership.
- Normal role reveal fades the black overlay over 0.3 seconds, waits 0.35 seconds, uses `Motion.SlideUp` plus `Motion.PopIn` for entry, holds for two seconds after entry, then moves the card upward while fading the overlay over 0.35 seconds.
- Reduced-motion role reveal shows instantly, holds one second, and removes instantly with no toast substitution.
- Role reveal fires only for a `Lobby → first active phase` change, a non-Spectator player, a non-reconnect snapshot, and a round number not previously revealed.
- Added reconnect protection that records the reconnect snapshot's round number, preventing a later phase change in that same restored round from replaying the role reveal.
- Added cancel-safe phase title bands with a full-width 96-pixel translucent black band, letter-spaced 25-pixel heading, muted subtitle, `0.97 → 1.0` scale, 0.25-second fade-in, 1.8-second hold, and 0.4-second fade-out.
- Reduced-motion phase title bands show instantly, hold 0.9 seconds, and remove instantly.
- Phase title cards skip unknown phases, `Lobby`, `Rewards`, reconnect snapshots, and any phase covered by an active role reveal.
- Preserved the required dispatch order: cinematic transition, title-card dispatch, then Resolution vote reveal.
- Confirmed `PrivateParticipantSnapshot` has `team`, not `faction`. The requested monster-style fallback therefore uses `roleName == "Murderer"` without changing the snapshot contract.
- Added five focused ceremony contracts and included them in the unified gate.
- Verified with the pinned Luau compiler (`76 source files`), focused Python test (`5/5`), the complete repository suite, all simulations, and a Rojo 7.7 place build.

## LEFT or deferred

- Roblox Studio visual/touch testing of both ceremonies is deferred because Studio is unavailable in this environment.
- The lobby roster remains a scrolling vertical list on narrow/mobile layouts, per review direction. A two-column mobile grid remains deferred until Steve's Studio playtest confirms whether it is needed.
- Authored assets, win/loss ceremony, counselor dialogue UI, and ghost-only chat remain out of scope.
- No new asset IDs or placeholders were added.

## Repository gate

Command:

`PATH=/tmp/camp-mystery-tools/bin:$PATH python scripts/run_all_checks.py --require-rojo`

Result:

```text
=== Structural project validation ===
CAMP-Mystery validation passed: 76 strict Luau files, 9 remotes, 8 roles, 8 monsters, launch monetization disabled, and 3 Rojo mappings.

=== Luau compilation ===
Luau compilation passed: 76 source files

=== Role reveal and phase title contract tests ===
Ran 5 tests in 0.002s
OK

=== Rojo build ===
Building project 'CAMP-Mystery'
Built project to CAMP-Mystery.rbxlx
Rojo artifact verified (802,080 bytes).

ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

## Answer and questions for Claude

`snapshot.round.roundId` does not exist. The equivalent field is `snapshot.round.roundNumber: number` in `GameTypes.RoundSnapshot`; `GameRuntimeService:GetRoundSnapshot()` sets it from the authoritative server `roundId`. I keyed `lastRoleRevealRound` on `roundNumber`, so no new field or boolean-only fallback was needed.

Question: None blocking. For a later Studio-tuning task, please review whether the two-second post-entry role-card dwell feels too long when combined with the preceding 0.65-second overlay/card delay.
