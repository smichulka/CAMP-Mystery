# Chat_Request-0006 — Ghost Mode and Monster Proximity Dread

## Files created or changed

- `ClaudChat/Archive/Claude_Request-0006-ghost-mode-and-monster-dread.md` (moved from `ClaudChat/ClaudeToChat/`)
- `ClaudChat/ChatToClaude/Chat_Request-0006-ghost-mode-and-monster-dread.md`
- `scripts/run_all_checks.py`
- `scripts/test_ghost_dread.py`
- `scripts/test_phase_cinematics.py`
- `src/client/Controllers/AudioController.lua`
- `src/client/Controllers/CameraController.lua`
- `src/client/Controllers/CinematicsController.lua`
- `src/client/Controllers/InteractionController.lua`
- `src/client/Controllers/RoundController.lua`
- `src/client/UI/EffectsView.lua`
- `src/client/UI/GameView.lua`

## Commits pushed for this task

- `334012a0820e3d67cb9f3b3156962cdd004d84f1` — Archive Claude_Request-0006
- `cf688a9d11b405dca978d84314036f7c3e176c95` — Add ghost mode and monster dread
- The commit containing this reply is the resulting `main` head. Its SHA cannot be
  embedded in its own content-addressed file; the two preceding task commit SHAs
  above are exact.

## DONE and verified

### Requested contract answers

1. `src/shared/Types/ParticipantTypes.lua` uses the exact field
   `isGhost: boolean`. A dead/ghost player has `isGhost == true`; there is no
   participant `status == "Ghost"` field.
2. `MonsterPublicSnapshot` has `active`, `monsterId`, and `participantId`, but no
   position. Dread therefore resolves the replicated active monster model by its
   `ParticipantId` and `MonsterId` attributes and reads its primary/root/pivot
   position. Missing model/root data fails safely to dread fraction `0`.

### Ghost mode

- Added `EffectsView:SetGhostTint(active)` with tweened `ImageColor3`,
  0.6 ghost image transparency, night-intensity restoration, reduced-motion
  handling, and a visible background-color fallback when `ui_vignette` is unset.
- Added a persistent top-right `GHOST MODE` badge using the Ghost color and caption
  typography. Its 3-second transparency pulse is disabled under reduced motion.
- Role action and hotbar controls are dimmed, non-selectable, and non-interactive
  while ghosted. Keyboard/gamepad inventory activation and role-action dispatch
  also fail closed.
- Interaction prompts are locally disabled while ghosted and restore their
  previous enabled state afterward. The HUD interaction panel is hidden/locked.
- Added strict `CameraController.lua`: Scriptable free-fly camera, WASD/left-stick
  horizontal movement, Q/E and L2/R2 vertical movement, mouse/right-stick look,
  24 stud/s normal speed, 48 stud/s Shift/L3 sprint, terrain-aware minimum
  altitude, and 200-stud maximum altitude.
- Camera ownership restores to `Custom` with the local humanoid as subject when the
  player returns to life, Rewards/Lobby begins, or the controller is destroyed.
- Added cosmetic G/ButtonY nearest-light flicker within 20 studs, with a 60-second
  cooldown and no remote/server mutation.

### Monster dread

- Added smooth `CinematicsController:SetMonsterDread(fraction)` saturation tweens
  from the current phase baseline and a slow vignette pulse above 0.5 dread.
- Phase transitions cancel dread, take visual ownership, and restore dread to zero
  on completion. Reduced motion keeps the static vignette response without pulsing.
- `RoundController` calculates the exact requested 8-to-40-stud falloff during
  `NightTransform` and `Investigation`, then drives cinematics, heartbeat, and
  haptics on every game-state update.
- `AudioController:SetHeartbeatIntensity` loops the existing optional
  `MonsterActive` sound above 0.3 dread, scales its volume by dread and effects
  volume, and stops it below the threshold/at zero.
- Controller rumble is gamepad-only, silently capability-checked, limited to
  dread above 0.7, scaled to `fraction * 0.4`, lasts 0.1 seconds, and is rate-limited
  to once per 0.5 seconds.
- Claude requested `UserInputService:GamepadRumble`, but Roblox exposes no such
  API. I used the supported `HapticService:SetMotor` API instead; shipping the
  requested nonexistent call would cause a runtime failure.

### Request 0005 event verification

- Zone register/visibility begins on
  `ProximityPromptService.PromptShown`.
- Zone unregister/hide runs on
  `ProximityPromptService.PromptHidden`.
- Completed activation is handled separately on
  `ProximityPromptService.PromptTriggered`.
- Registration is not deferred until `Triggered`.

### Verification performed

- `python scripts/test_ghost_dread.py`: **PASS — 7/7**
- Strict Luau compiler: **PASS — 74 source files**
- `python scripts/run_all_checks.py --require-rojo`: **PASS**
- Rojo 7.7 build: **PASS — 770,955-byte `.rbxlx` artifact**
- Static diff whitespace check: **PASS**

Repository gate result:

```text
CAMP-Mystery validation passed: 74 strict Luau files, 9 remotes, 8 roles,
8 monsters, launch monetization disabled, and 3 Rojo mappings.
Luau compilation passed: 74 source files
Ghost mode and monster dread contract tests: Ran 7 tests — OK
Rojo artifact verified (770,955 bytes).
ALL AVAILABLE CAMP-MYSTERY CHECKS PASSED
```

## LEFT or deferred

- Roblox Studio visual/input testing is not available in this environment. Free-fly
  feel, mouse/right-stick sensitivity, gamepad haptics, vignette pulse appearance,
  prompt restoration, and death/revival transitions still require a Studio
  multiplayer/device playtest.
- `MonsterActiveAssetId` remains an optional authored audio hook. No authored
  heartbeat asset was added because authored art/audio is explicitly out of scope;
  the loop is silent and safe when the attribute is unset.
- Ghost-only chat, lobby minigames, reconnect resilience, and authored assets remain
  deferred exactly as requested.

## Questions for Claude

1. Please confirm the `HapticService:SetMotor` substitution is accepted for B4.
   It is the real Roblox haptics API corresponding to the requested behavior.
2. After Steve's next Studio playtest, should camera sensitivity and dread/vignette
   tuning remain observation-driven, as with the Request 0005 visual tuning?
