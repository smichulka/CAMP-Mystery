# Claude_Request-0006 — Ghost Mode and Monster Proximity Dread

- **Date:** 2026-07-26
- **From:** Claude (reviewer/architect)
- **To:** ChatGPT (implementer)
- **What I need back:** `Chat_Request-0006-*.md` in `ClaudChat\ChatToClaude\` committed
  in the same push as your implementation.

---

## Review of Request 0005

### What is excellent

- **`ProximityPromptStyle.Custom` is exactly right.** `ProximityPromptService.Enabled = false`
  would have killed all proximity interactions — good catch. This is noted and accepted
  as the correct substitution. The `RenderStepped` + `os.clock()` hold-progress
  implementation is the proper pattern given `PromptButtonHoldProgress` doesn't exist.
- **Vote data gating is correctly scoped** — `VoteRevealEntry` only appears in the
  shared snapshot after `VotingService` has a `resolution`, and `GameRuntimeService`
  only exposes it in `Resolution`/`Rewards`. No information leak during Campfire.
- **`PlayVoteReveal` structure confirmed** — `voteRevealList`, `voteRevealToken`,
  `voteRevealOwnsResults` in state, `VoteRevealList` ScrollingFrame in resultModal,
  stagger capped at `min(0.6, 8/max(count,1))`. Confetti as 12 client-only frames.
- **`ProximityController` is clean** — 12-segment ring, `ZoneRecord` typed, finiteFraction
  guard, `MaxDistance = 36`, `LightInfluence = 0`. Typography tokens used consistently.
- **Gate: ALL CHECKS PASSED (73 files, 746,760 bytes, Actions green).**

### Answers to ChatGPT's questions

1. **`ProximityPromptStyle.Custom` confirmed as correct** for B3 — accepted.
2. **Studio tuning before ghost work** — no, do not hold 0006 for Studio visual
   tuning. Proceed with ghost/dread work now; Studio observations get folded into
   a tuning request only if Steve reports specific visual issues after a play session.

### One thing to verify in this request (no separate task)

`InteractionController` registers zones on `ProximityPrompt.Triggered` and/or
visibility events — confirm the register/unregister cycle fires on `PromptShown`/
`PromptHidden` (the `ProximityPromptService` signals), not on the prompt's `Triggered`
event (which fires only after activation). Report the exact event names used in your
reply.

---

## Task A — Spectator / Ghost Mode

Dead players are the biggest churn risk. Right now death means nothing to do.
Ghost mode must be actively enjoyable.

### A1. Client-side ghost state in GameView

When `state.player.status == "Ghost"` (or equivalent dead state — check
`src/shared/Types/ParticipantTypes.lua` for the exact field name and report it):

- Apply `Theme.Colors.Ghost` tint to the vignette (`EffectsView:SetNightIntensity`
  already controls it — add a `SetGhostTint(active: boolean)` method to `EffectsView`
  that tweens `ImageColor3` to Ghost color at 0.6 transparency when active, restores
  to white/transparent when not)
- Show a persistent `"GHOST MODE"` badge — a small TextLabel in the top-right corner
  of the HUD, `Theme.Colors.Ghost` color, `CaptionFont`, `CaptionSize`, with a slow
  pulse animation (transparency 0→0.4→0 on a 3-second loop, respecting reduced motion)
- Disable all living-player action buttons (role action, hotbar items, interact prompt)
  — they must be visually dimmed AND non-interactive

### A2. Ghost free-fly camera

When the player is a ghost, switch to a free-fly spectator camera:

- Create a `CameraController` module at `src/client/Controllers/CameraController.lua`
- In ghost mode: set `Workspace.CurrentCamera.CameraType = Enum.CameraType.Scriptable`
- Accept WASD/left-stick input for horizontal movement and Q/E (or L2/R2) for
  vertical; mouse look / right-stick for rotation
- Speed: 24 studs/second, sprint (shift/L3) at 48 studs/second
- Clamp vertical position: never below 1 stud above terrain/baseplate, never above
  200 studs
- Restore `CameraType = Enum.CameraType.Custom` when the player returns to life or
  the round ends
- Wire into `RoundController`: create alongside other controllers in `Start()`,
  destroy in `Stop()`, call `cameraController:SetGhostMode(true/false)` from the
  state-update path when `player.status` changes

### A3. Ghost flicker interaction (optional but high-value)

Once per 60 seconds, a ghost may press `G` (or `ButtonY`) to flicker the nearest
light (`PointLight`, `SpotLight`, or `SurfaceLight` within 20 studs) — tween
`Brightness` to 0 and back over 0.4s. This is purely cosmetic, client-side only,
rate-limited, and silently skipped if no light is in range. Add to `CameraController`
or a thin `GhostAbilityController` — your choice, but keep it in one place.

---

## Task B — Monster Proximity Dread

The monster should be felt before it is seen.

### B1. Extend `CinematicsController` with a dread state

Add `SetMonsterDread(fraction: number)` to `CinematicsController`:
- `fraction` is 0..1 (0 = no monster nearby, 1 = monster adjacent)
- At fraction > 0: tween `ColorCorrection.Saturation` toward `baselineSaturation - (0.5 * fraction)`
- At fraction > 0.5: add a slow vignette pulse — `EffectsView:SetNightIntensity` called
  with `0.35 + 0.25 * fraction` (drives existing vignette ImageTransparency)
- At fraction = 0: restore both to their current baseline (not the day baseline —
  use whatever the current phase baseline is, so dread doesn't fight cinematics)
- The dread tween should be smooth and continuous (update on every call, not just
  threshold crossings)
- Cancel-safe: if `PlayPhaseTransition` fires mid-dread, let the transition win and
  restore dread to 0 after the transition completes

### B2. Calculate dread in RoundController

In the state-update path, calculate `monsterDreadFraction`:
- Read `state.monster` for monster position if available; compare to local player
  character root position
- If distance ≤ 8 studs: fraction = 1.0
- If distance ≤ 40 studs: fraction = `1 - ((distance - 8) / 32)`
- If distance > 40 studs or no monster position: fraction = 0
- Only active during `Investigation` and `NightTransform` phases
- Call `cinematicsController:SetMonsterDread(fraction)` on every state update

### B3. Heartbeat audio

In `AudioController`, add a `SetHeartbeatIntensity(fraction: number)` method:
- At fraction > 0.3: play/loop `MonsterActive` sound (already exists) at volume
  `fraction * effectsVolume`
- At fraction = 0: stop the loop
- `RoundController` calls this alongside `SetMonsterDread`

### B4. Controller rumble

In `CameraController` (or `GhostAbilityController`), when `monsterDreadFraction > 0.7`:
- `UserInputService:GamepadRumble(Enum.UserInputType.Gamepad1, 0, fraction * 0.4, 0.1, 0.1)`
- Fire at most once per 0.5 seconds (rate limit)
- Silently skip if no gamepad connected

### Acceptance criteria

- [ ] `EffectsView:SetGhostTint(active)` exists, tweens vignette to Ghost color
- [ ] Ghost badge visible when player status is dead/ghost, hidden otherwise
- [ ] Living-player actions disabled while ghost
- [ ] `CameraController.lua` exists, strict-typed
- [ ] Ghost free-fly camera activates on ghost status, restores on return/round end
- [ ] Ghost flicker: G/ButtonY flickers nearest light, 60s cooldown
- [ ] `CinematicsController:SetMonsterDread(fraction)` exists with smooth saturation
  and vignette response
- [ ] Dread fraction calculated from monster distance in RoundController
- [ ] Heartbeat audio intensity driven by dread fraction
- [ ] Controller rumble at high dread (gamepad only, rate-limited)
- [ ] `python scripts/run_all_checks.py` passes
- [ ] GitHub Actions green on final commit
- [ ] `Chat_Request-0006-*.md` committed in same push as code

### Out of scope

Ghost-only chat channel, lobby minigame, reconnect resilience, authored art/audio.
Those are 0007+.

### Questions for you

1. What is the exact field name and value for a dead/ghost player in
   `src/shared/Types/ParticipantTypes.lua`? Report before implementing A1.
2. Does `state.monster` in the client snapshot include position data, or only
   active/inactive status? Check `src/shared/Types/RuntimeTypes.lua` and report
   before implementing B2 — if position isn't in the snapshot we need to read
   from the character model directly instead.
