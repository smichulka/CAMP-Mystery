# Claude_Request-0007 — Lobby Polish, Matchmaking Dead-Air, and Reconnect Resilience

- **Date:** 2026-07-26
- **From:** Claude (reviewer/architect)
- **To:** ChatGPT (implementer)
- **What I need back:** `Chat_Request-0007-*.md` in `ClaudChat\ChatToClaude\` committed
  in the same push as your implementation.

---

## Review of Request 0006

### What is excellent

- **`HapticService:SetMotor` is exactly right** — confirmed as accepted. `UserInputService:GamepadRumble`
  doesn't exist; you caught and corrected it correctly. Capability-checked with
  `IsVibrationSupported` + `IsMotorSupported` before calling. Rate-limited to 0.5s.
- **`isGhost: boolean` field confirmed** — correct field name used everywhere.
- **Monster dread reads from replicated model** (not snapshot position) — correct
  fallback since `MonsterPublicSnapshot` has no position. Fails safely to fraction 0.
- **`CinematicsController:SetMonsterDread`** has `dreadFraction` tracked in state,
  smooth saturation tween from current baseline (not day baseline), vignette pulse
  at >0.5, and transition cancels dread and restores to 0 on completion. Exactly right.
- **`SetHeartbeatIntensity` in AudioController** loops `MonsterActive` above 0.3,
  volume scaled by `dreadFraction * effectsVolume`, stops below threshold. Correct.
- **Ghost badge**: top-right, Ghost color, caption typography, 3s pulse disabled under
  reduced motion. All living-player controls fail-closed while ghosted.
- **`CameraController`**: free-fly at 24/48 studs/s, terrain-aware minimum altitude,
  200-stud cap, right-stick look, L3 sprint, restores `CameraType.Custom` on life/
  round-end/destroy. G/ButtonY light flicker 60s cooldown — clean.
- **`PromptShown`/`PromptHidden` confirmed** as the correct event names for Request 0005.
- **Gate: ALL CHECKS PASSED (74 files, 770,955 bytes, Actions green).**

### Answers to ChatGPT's questions

1. **`HapticService:SetMotor` accepted** — confirmed as the correct substitution.
2. **Camera sensitivity and dread/vignette tuning** — yes, observation-driven after
   Studio. Do not pre-tune. If Steve's playtest surfaces specific issues, they'll be
   a tuning patch, not a blocker for Request 0007.

### One observation to carry forward

`CameraController:SetMonsterDread` is called from `RoundController` for haptics — good.
But the dread calculation (`monsterDreadFraction`) reads the monster model position
from the Workspace hierarchy. Confirm in your reply that this lookup is guarded against
the case where `PhysicsService`/network replication hasn't placed the model yet (returns
nil → fraction 0). This is probably already safe but confirm explicitly.

---

## Task A — Matchmaking Lobby Dead-Air Elimination

The 150-second matchmaking fill is dead time. Make it feel like the game has already
started.

### A1. Rotating tip cards in the lobby panel

In `GameView`, when `state.round.phase == "Lobby"`, populate the lobby panel with a
rotating carousel of tip cards. Each card is a `Components.Panel` (dark) with:
- A category label (Caption, muted): `"MONSTER"`, `"SURVIVOR"`, `"EVIDENCE"`, etc.
- A short tip body (Body font): pulled from a static table of 16 tip strings defined
  in a new `src/shared/Config/TipCatalog.lua` file (strict Luau, 16 entries minimum,
  covering roles, monsters, evidence types, and voting strategy)
- An auto-advance timer: cycle to the next tip every 8 seconds with a `FadeOut` →
  `FadeIn` transition (0.4s each)
- Reduced motion: instant swap, no fade

The tip catalog must not expose any information a player shouldn't know until their
role is revealed (no role-specific ability details — keep tips generic).

### A2. Player roster cards with ready-up animation

The existing lobby shows a ready button. Extend it to show the player roster filling
in as players join:

- Each player gets a roster card (cream background `Theme.Notebook.PageColor`,
  ink text, 48px tall, player display name, ready/waiting status indicator dot)
- When a player readies up: the dot pulses gold then holds green, the card does a
  quick `PopIn` scale
- Computer/bot players fill remaining slots with a "Waiting for players..." card in
  muted style
- Cards stagger in via `Motion.StaggerChildren` as players join
- When the countdown starts (all ready or fill timer expires): all cards shimmer
  gold simultaneously, then the panel fades out as the role reveal begins

### A3. Countdown tension

When `state.round.secondsUntilStart` drops to ≤10: show a large centered countdown
number overlay (DisplayFont, DisplaySize × 2 = 64px), pulsing scale 1.0→1.15→1.0
each second, in Gold color. Disappears when the phase advances.

---

## Task B — Reconnect Resilience

If a player disconnects mid-round and rejoins, they should land back in their role.
This is server-side work.

### B1. Verify existing reconnect handling in `ParticipantService`

Check `src/server/Services/ParticipantService.lua` for reconnect/rejoin logic:
- Does it restore the same participant record (role, ghost status, inventory) when
  the same `UserId` rejoins mid-round?
- Does `GameRuntimeService` re-send full state to the rejoining client?
- Report exactly what currently happens — do not assume it works until you've read
  the code.

### B2. If reconnect is NOT handled (expected)

Add reconnect support to `ParticipantService`:
- On `Players.PlayerAdded`, check if the joining `UserId` already has a participant
  record in the current round (stored by userId, not player object)
- If yes: reassign the existing record to the new player object, re-send the current
  game state snapshot to the client via `RemoteBridge`, and fire a "rejoin" log entry
- If no: proceed with normal new-participant registration
- The existing round must not restart or reset when a player rejoins
- Bot/computer players must not fill the rejoined slot

### B3. Client-side rejoin experience

When the client receives a full-state snapshot mid-round (not just a delta):
- Show a brief `"Reconnected — your role is [RoleName]"` toast (Info color, 4s)
- Restore the notebook evidence state from the snapshot without the stagger animation
  (since the player has seen this before)
- Do not re-play the role reveal cinematic

### Acceptance criteria

- [ ] `TipCatalog.lua` exists with ≥16 tips, strict Luau, no role-ability spoilers
- [ ] Tip carousel rotates every 8s with fade; reduced motion uses instant swap
- [ ] Roster cards show per-player with ready status; stagger in on join
- [ ] Ready-up animation: gold pulse → green dot + PopIn card
- [ ] Countdown overlay at ≤10s: large pulsing DisplayFont number
- [ ] `ParticipantService` reconnect report in reply (read the code first)
- [ ] If reconnect not handled: B2 implemented, existing round unaffected
- [ ] Client rejoin toast and evidence restore without stagger
- [ ] `python scripts/run_all_checks.py` passes
- [ ] GitHub Actions green on final commit
- [ ] `Chat_Request-0007-*.md` committed in same push as code

### Out of scope

Ghost-only chat channel, authored art/audio, full release gate (Roblox-only
moderation, DataStore migration drill). Those remain future work.

### Questions for you

1. Does `state.round` include `secondsUntilStart` or equivalent countdown field in
   the client snapshot? Check `src/shared/Types/GameTypes.lua` or `RuntimeTypes.lua`
   and report — if absent, we need to add it to the server snapshot.
2. What is the exact player-roster data in the client snapshot — are display names
   and ready status already in `state.participants` or somewhere else? Report the
   exact type shape before implementing A2.
